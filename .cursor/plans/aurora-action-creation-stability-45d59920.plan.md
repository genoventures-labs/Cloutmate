<!-- 45d59920-1151-4e24-826d-9438c37f324c 72b1cc5d-2d81-4dc8-b9b3-f267df69094f -->
# Aurora Action & Creation Stability Fix

This plan addresses critical issues with Aurora's action execution system, including incorrect creation, misreading prompts, retry failures, missing chat renaming, and workspace data hallucinations.

## PHASE 1 — Create Deterministic Intent Parsing System

**New File:** `FocusOS/Services/IntentParserService.swift`

Create a new service that:

- Parses all creation prompts into a single structured `ParsedIntent` format
- Caches parsed intents by message hash/content
- Provides deterministic parsing that always produces the same output for the same input
- Extracts: action type, object type, names, secondary items, metadata (dates, tags, priority)

**Modify:** `FocusOS/Services/CoreResponseService.swift`

- Add method to get cached intent or parse new one
- Integrate with `IntentParserService` for all intent detection

**Modify:** `FocusOS/ViewModels/AIAssistantViewModel.swift`

- Store `ParsedIntent` after parsing (cache by message content)
- Use cached intent when retry is triggered
- Pass `ParsedIntent` to action execution instead of raw `ExecutionIntent`

**Modify:** `FocusOS/Services/ConversationFlowService.swift`

- Add intent caching support
- Ensure normal messages still pass through casual detection

## PHASE 2 — Fix Retry Behavior

**Modify:** `FocusOS/ViewModels/AIAssistantViewModel.swift`

- Add `retryModeActive: Bool` flag
- Modify `retryLastMessage()` to:
- Check for cached `ParsedIntent` from last message
- If found, skip re-parsing and re-routing
- Directly execute action using cached intent
- Set `retryModeActive = true` during retry execution

**Modify:** `FocusOS/Services/ModelRoutingEngine.swift`

- Add check for `retryModeActive` flag
- When retry mode is active, skip model selection and use previously selected model
- Ensure same model is reused for retry

**Requirements:**

- Retry must NOT re-route models
- Retry must NOT re-run casual/task classifiers
- Retry must NOT re-analyze raw text
- Retry must reuse cached `ParsedIntent`

## PHASE 3 — Action Execution Layer

**New File:** `FocusOS/Services/WorkspaceObjectCreationService.swift`

Create dedicated service for workspace actions:

- `executeCreation(intent: ParsedIntent, modelContext: ModelContext) async throws -> CreationResult`
- Atomic create flow:

1. Parse → structured intent (already done in Phase 1)
2. Execute workspace actions (create objects in modelContext)
3. Verify objects were created (fetch from modelContext)
4. Sync to MemoryGraph (Phase 6)
5. Return creation result with created object IDs

**Modify:** `FocusOS/Services/CoreResponseService.swift`

- Integrate `WorkspaceObjectCreationService` for all creation operations

**Modify:** `FocusOS/ViewModels/AIAssistantViewModel.swift`

- Replace direct creation logic in `executeCompoundProjectCreation`, `executeCompoundNoteCreation`, etc. with calls to `WorkspaceObjectCreationService`
- Remove markdown list generation from creation methods

**Modify:** `FocusOS/Services/FocusOSDataController.swift` (if exists) or create wrapper

- Ensure all object creation goes through verified modelContext operations
- Add validation that objects exist after creation

## PHASE 4 — Conversational Action Reports

**New File:** `FocusOS/Services/ActionReportService.swift`

Create service that generates conversational action reports:

- `generateActionReport(intent: ParsedIntent, createdObjects: [UUID], modelContext: ModelContext) async -> String`
- Tone: casual, human, 1-2 sentences
- Examples:
- "All good — I created the project 'Daily Systems' and added the tasks you listed. What's next?"
- "Done! I've set up 'Morning Routine' with those three tasks. Ready to tackle them?"
- NO lists, NO markdown, NO structured bullet points

**Modify:** `FocusOS/Services/LanguagePersonalityService.swift`

- Add method to generate conversational action acknowledgements
- Integrate with personality context

**Modify:** `FocusOS/ViewModels/AIAssistantViewModel.swift`

- Replace markdown list responses with `ActionReportService.generateActionReport()`
- Use conversational responses for all creation/edit/deletion actions

## PHASE 5 — Chat Auto-Naming & Tagging

**Modify:** `FocusOS/Services/ConversationFlowService.swift`

- Add `evaluateAndRenameChat(intent: ParsedIntent, conversation: AIConversation, modelContext: ModelContext) async`
- Extract keywords from `ParsedIntent` for title generation
- Trigger after any successful workspace action

**Modify:** `FocusOS/ViewModels/AIAssistantViewModel.swift`

- Call chat naming after ALL workspace actions (not just first message)
- Use `ParsedIntent` keywords for better title generation
- Ensure naming happens after creation workflows complete

**Note:** `ConversationClassifier.swift` doesn't exist - functionality is in `ConversationFlowService.swift`

## PHASE 6 — MemoryGraph Sync

**Modify:** `FocusOS/Services/MemoryGraphService.swift`

- Add sync methods for all workspace operations:
- `syncOnCreate(object: RecallTrackable, modelContext: ModelContext) async`
- `syncOnUpdate(object: RecallTrackable, modelContext: ModelContext) async`
- `syncOnRename(object: RecallTrackable, oldTitle: String, modelContext: ModelContext) async`
- `syncOnArchive(object: RecallTrackable, modelContext: ModelContext) async`
- `syncOnDelete(objectId: UUID, objectType: RecallObjectType, modelContext: ModelContext) async`
- `syncOnStatusChange(object: RecallTrackable, modelContext: ModelContext) async`
- `syncOnTaskCompletion(task: Task, modelContext: ModelContext) async`

**Modify:** `FocusOS/Services/WorkspaceObjectCreationService.swift`

- Call MemoryGraph sync after each object creation
- Verify sync completed before returning result

**Modify:** `FocusOS/Services/AIActionRouter.swift`

- Add MemoryGraph sync calls for update, delete, archive operations
- Ensure sync happens for all state changes

**New File:** `FocusOS/Services/WorkspaceObjectPersister.swift` (optional helper)

- Centralized persistence and sync operations
- Ensures MemoryGraph is always updated

## PHASE 7 — Workspace Object Lookups

**New File:** `FocusOS/Services/WorkspaceLookupService.swift`

Create service for workspace object lookups:

- `lookupProject(name: String, modelContext: ModelContext) async -> Project?`
- `lookupTask(name: String, projectId: UUID?, modelContext: ModelContext) async -> Task?`
- `lookupArea(name: String, modelContext: ModelContext) async -> Area?`
- `lookupNote(name: String, modelContext: ModelContext) async -> Note?`
- All methods return `nil` if object doesn't exist (never hallucinate)

**Modify:** `FocusOS/Services/IntentParserService.swift`

- When parsing intent, extract object names
- Pass names to `WorkspaceLookupService` to resolve UUIDs
- Store resolved UUIDs in `ParsedIntent`

**Modify:** `FocusOS/ViewModels/AIAssistantViewModel.swift`

- Before executing actions, verify referenced objects exist
- If object not found, respond: "I didn't find a project named 'Fitness System'. Want me to create it?"
- Never proceed with action if referenced object doesn't exist

## PHASE 8 — Model Routing Hardening

**Modify:** `FocusOS/Services/ModelRoutingEngine.swift`

- Add `isCreationAction: Bool` parameter to `selectModel()`
- For creation/editing actions:
- Always use `qwen3:1.7b` with thinking enabled
- NEVER use `gemma3:1b` for creation
- NEVER use DeepSeek for creation (unless research mode)
- Ensure retry uses same model that executed first action

**Modify:** `FocusOS/ViewModels/AIAssistantViewModel.swift`

- Pass `isCreationAction: true` when routing for creation intents
- Store selected model in cached intent for retry reuse

## PHASE 9 — Logging & Debugging Visibility

**Modify:** `FocusOS/ViewModels/AIAssistantViewModel.swift`

- Add debug logs (only in DEBUG mode):
- When intent is parsed
- When retry occurs
- When workspace action fires
- When chat title is generated

**Modify:** `FocusOS/Services/ModelRoutingEngine.swift`

- Add debug logs for model selection (already exists, ensure it's comprehensive)

**Modify:** `FocusOS/Services/IntentParserService.swift`

- Add debug logs for parsing operations

**Modify:** `FocusOS/Services/MemoryGraphService.swift`

- Add debug logs for sync operations

## PHASE 10 — Testing Scenarios

Verify these flows work correctly:

**Scenario A — Create Project + Tasks**

- Prompt: "Create a project called Morning Routine with tasks: Wake up, Shower, Journal."
- Expected: Project created, 3 tasks added, conversational confirmation, chat renamed to "Morning Routine Setup"

**Scenario B — Retry the above**

- Expected: Same items created again without prompt misreading, no hallucinated task names, no full-prompt-as-title bug

**Scenario C — Rename Chat**

- Prompt: "Rename this chat to Productivity Flow."
- Expected: Clean rename without errors

**Scenario D — No Hallucinating Workspace Items**

- Prompt: "Add a task to 'Fitness System'."
- If project doesn't exist: Aurora must say "I didn't find a project named 'Fitness System'. Want me to create it?"

**Scenario E — Conversational Action Reports**

- Prompt: "Create a task called 'Track water intake'."
- Expected: Conversational reply, no markdown lists

## Implementation Order

1. Phase 1 (Intent Parsing) - Foundation for everything
2. Phase 2 (Retry Fix) - Depends on Phase 1
3. Phase 7 (Lookups) - Needed before Phase 3
4. Phase 3 (Action Execution) - Depends on Phases 1 & 7
5. Phase 6 (MemoryGraph Sync) - Needed for Phase 3
6. Phase 4 (Action Reports) - Depends on Phase 3
7. Phase 5 (Chat Naming) - Depends on Phase 1
8. Phase 8 (Model Routing) - Can be done in parallel
9. Phase 9 (Logging) - Add throughout implementation
10. Phase 10 (Testing) - Verify all scenarios

### To-dos

- [ ] Create IntentParserService.swift with deterministic parsing and caching
- [ ] Integrate IntentParserService into CoreResponseService.swift
- [ ] Modify AIAssistantViewModel.swift to cache and use ParsedIntent
- [ ] Fix retry behavior to reuse cached ParsedIntent without re-parsing
- [ ] Update ModelRoutingEngine to skip routing during retry mode
- [ ] Create WorkspaceLookupService.swift for object lookups
- [ ] Integrate lookups into IntentParserService to resolve object names to UUIDs
- [ ] Create WorkspaceObjectCreationService.swift with atomic create flow
- [ ] Replace direct creation logic in AIAssistantViewModel with WorkspaceObjectCreationService
- [ ] Add sync methods to MemoryGraphService for all workspace operations
- [ ] Integrate MemoryGraph sync into WorkspaceObjectCreationService and AIActionRouter
- [ ] Create ActionReportService.swift for conversational action reports
- [ ] Replace markdown list responses with ActionReportService in AIAssistantViewModel
- [ ] Add chat auto-naming to ConversationFlowService and trigger after all workspace actions
- [ ] Harden ModelRoutingEngine to always use qwen3:1.7b with thinking for creation actions
- [ ] Add debug logging throughout all services (only in DEBUG mode)