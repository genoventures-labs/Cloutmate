# Cloutmate Structure & Feature Inventory

This document maps the entire macOS workspace, companion apps, shared framework, and supporting scripts so contributors can navigate quickly.

---

## 1. Directory Map

| Path | Contents |
| --- | --- |
| `Cloutmate/` | Main macOS target (SwiftUI). Subfolders: `Views`, `ViewModels`, `Services`, `Models`, `Utilities`, `Config`, `Extensions`, `Shared`. |
| `CloutmateShared/` | Swift package + DocC bundle providing shared models (`CloutmateShared/CloutmateShared/Models`) and services for all targets. |
| `CloutmateMenuBar/` | Menu bar utility app with quick capture, tasks, and upcoming posts. |
| `CloutmateWidget/` | WidgetKit extension summarizing calendar/tasks/posts. |
| `CloudmateHelper/` & `CloutmateHelper/` | Background helper apps (legacy + new naming) for scheduling/publishing tasks. |
| `CloutmateTests`, `CloutmateUITests`, `CloutmateSharedTests`, `CloudmateHelperTests`, `CloutmateMenuBarTests` | Test targets. |
| `scripts/` | Automation helpers (`generate_changelog.py`, `update_commit_hash.py`). |
| Root markdowns (`README.md`, `AURORA_*`, `PHASE*`, `SETUP_*`, etc.) | Institutional knowledge for every subsystem.

---

## 2. Data Layer

- **SwiftData Models:**
  - Workspace: `Project`, `Task`, `Note`, `Artifact`, `Reminder`, `Template`, `InboxItem`, `CalendarEvent`, etc. (in `CloutmateShared`).
  - AI & Analytics: `AIConversation`, `AIMessage`, `ConversationDigest`, `PriorityScore`, `FocusSession`, `FocusRitual`, `RitualCompletion`, `MemoryNode`, `StoryToken`, `FlowCompanionState`, `IntentClusterSummary`, `ConfidenceSnapshot`, etc. (in `Cloutmate/Models`).
- **Model container:** Each target calls `SharedDataManager.createSharedModelContainer()` to attach to the shared App Group store.
- **Config:** `Cloutmate/Config/AIConfig.plist` (feature flags), `Config.plist` (API keys), `ReflectionPrompts.plist` (Flow Companion), Info.plist keys for Meta/Notion/Ollama.

---

## 3. Workspace Surfaces

- **Sidebar (`Cloutmate/Views/Sidebar/`)** – ARTE-aware navigation with collapsible sections, hover rails, scroll metrics, collapse toggle.
- **MainWindowView** – Hosts tab routing, overlays (Contextual Create Drawer, Quick Capture, Voice Memo), Flow Companion panel, command palette.
- **Tabs:** Organized by folder (`Views/<Tab>`). Each area encapsulates SwiftUI screens, components, and view models.
  - Capture: Inbox, Notes, Journal (`Views/Inboxes`, `Views/Notes`, `Views/Journal`).
  - PARA: Projects, Tasks, Areas, Resources, Archives.
  - Express: Drafts, Composer, Calendar, Artifacts, Templates.
  - Tools: AI Assistant, Focus Mode, Focus Gravity, Rituals, Insights, Settings.
- **Contextual interactions:**
  - `ContextualCreateDrawer` adapts actions by tab.
  - `SlashCommandAutocompleteView` + `CommandPaletteView` provide fast actions.
  - Notifications (Focus, Flow, Reminders) via `NotificationService`/`ReminderService`.

---

## 4. Services Overview (selected)

| Category | Services |
| --- | --- |
| AI runtime | `AIActionRouter`, `AIReflectionService`, `AIRecallService`, `CoreResponseService`, `OllamaBridgeService`, `ModelRoutingEngine`, `AuroraSystemPromptBuilder` |
| Intelligence | `AnalyticsEngine`, `PriorityEngine`, `ConceptTracker`, `NarrativeEngine`, `FlowCompanionEngine`, `CognitionPredictor`, `PredictiveContextManager`, `SmartAutomationEngine`, `MemoryGraphService` |
| UX/Theme | `ReactiveThemeManager`, `AuroraToneKit`, `SidebarToneSyncService`, `GlassColorSystem`, `AccessibilityGlassManager` |
| Capture/Express | `ArtifactAnalyticsService`, `DraftEnhancementService`, `ArtifactPredictiveBridge`, `CreateActionUsageTracker`, `DocumentAttachmentService`, `ImageAttachmentService`, `VoiceTranscriptionService` |
| Integrations | `NotionService`, `OAuthCallbackServer`, `CalendarSyncService`, `HybridBridgeService`, `WebSearchService`, `GeminiService` |
| System | `MigrationRunner`, `KeychainService`, `LoginItemService`, `XPCService`, `SharedDataManager` (in shared module) |

Each service is intentionally small and focused, so new contributors can extend a single behavior without touching the entire stack.

---

## 5. Companion Apps

- **Menu Bar (`CloutmateMenuBar`)** – SwiftUI status item with `MenuBarPopoverView`, `QuickComposerView`, `TasksView`, `UpcomingPostsView`, `MenuBarSettingsView`. Uses shared models for data and `NotificationService` for local scheduling.
- **Widget (`CloutmateWidget`)** – Standard SwiftUI widget timeline; ensure `CloutmateShared.framework` is embedded and app group entitlements are set.
- **Helper (`CloutmateHelper`)** – Background publishing, login item management, deeper integration with Meta Graph/Threads (see `BUILD_AND_SIGN_MENUBAR.md`, `SIGN_MENUBAR_APP.sh`). Legacy `CloudmateHelper` remains for historical reference until fully removed.

---

## 6. Build & Setup References

- `SETUP_GUIDE.md`, `XCODE_SETUP_STEPS.md`, `XCODE_STEPS_VISUAL.md` – local environment.
- `BUILD_AND_SIGN_MENUBAR.md`, `SIGN_MENUBAR_APP.sh` – codesigning companion targets.
- `SETUP_WIDGET_MENUBAR.sh` – automation for entitlements and signing.
- `NOTION_OAUTH_SERVER_SETUP.md`, `SETUP_OAUTH.md`, `CLOUDMATEHELPER_NEEDS.md` – integration credentials.

---

## 7. Tests & QA

- `CloutmateTests` – SwiftData/service tests (priority, analytics, migrations).
- `CloutmateUITests` – Smoke coverage for navigation flows.
- Numerous QA docs at root (e.g., `QA_VALIDATION_NOTES.md`, `PHASE*_COMPLETE.md`, `FLOW_COMPANION_QUICK_START.md`).

---

## 8. Development Tips

1. **SwiftData migrations** – Add new @Model types to `CloutmateApp.sharedModelContainer` schema list and run `MigrationRunner` if shape changes.
2. **Shared components** – Prefer building UI primitives inside `CloutmateShared/CloutmateShared/UI` for reuse (Glass system, cards) rather than duplicating per target.
3. **Docs** – When adding features, update both the root markdowns and `/ProjectBlueprints` equivalents so Aurora’s knowledge stays aligned.
4. **Companion data** – Always test menu bar + widget after model changes; they rely on the same schema and can crash if not updated.

Use this map as your constant reference when exploring or modifying the workspace.
