<!-- 78d5934f-4f7b-40db-b5a5-b544d014d652 65ae7754-f15f-40a6-887c-de75657765bc -->
# Aurora Documentation Audit and System Prompt Improvements

## Analysis Summary

After cross-referencing Aurora's documentation (`AURORA_README.md`, `AURORA_KNOWLEDGE_BASE_UPDATED.md`, `AURORA_IMPLEMENTATION_AUDIT.md`) with the source code, I've identified several gaps and improvement opportunities.

## Key Findings

### ✅ What's Well Documented and Implemented

- All 9 phases are implemented in code
- Core services exist (OllamaBridgeService, CoreResponseService, etc.)
- Phase-specific services are present (CognitionPredictor, ARTE, Rituals, etc.)
- Payload context formatting includes phase-specific data

### ⚠️ Critical Gaps Identified

#### 1. System Prompt Lacks Detailed Phase Documentation

**Location:** `Cloutmate/Services/OllamaBridgeService.swift` - `buildSystemPrompt()` method (lines 1144-1242)

**Issue:** The system prompt is very basic compared to the comprehensive documentation:

- Only includes core identity, basic behavior, and changelog instructions
- Missing detailed phase-by-phase capability descriptions
- Missing behavioral guidelines for each phase
- Missing natural language command examples
- Missing phase-specific behavioral instructions (e.g., Intent Cluster Prediction guidelines, ARTE awareness, Predictive Cognition guidelines)

**Current Prompt Structure:**

- Core identity (basic)
- Response format guidelines
- Schema document (truncated to 3000 chars)
- App context (truncated to 2000 chars)
- Payload context (formatted dynamically)
- Confidence diagnostics
- Dynamic instructions from services (tone, personality, self-awareness, contextual, pattern, memory)
- Changelog updates (last 14 days)

**Missing from Documentation:**

- Phase 1-9 detailed capability descriptions
- Behavioral guidelines per phase
- Natural language command examples
- Phase-specific routing instructions (Reflection vs Execution)
- Intent Cluster Prediction guidelines (confidence thresholds, abstain logic)
- ARTE emotional state awareness instructions
- Predictive Cognition guidelines
- Document/Image analysis behavioral instructions
- @ Mention linking guidelines
- Reminder creation guidelines

#### 2. Documentation Claims vs. Implementation Reality

**Documentation Says:**

- "All phases are fully implemented and documented in Aurora's system prompts" (AURORA_KNOWLEDGE_BASE_UPDATED.md line 23)
- "Her system prompts have been comprehensively updated across all OllamaBridgeService functions" (line 11)

**Reality:**

- System prompt is basic and doesn't include comprehensive phase documentation
- Phase details are only in markdown documentation files, not in actual prompts
- Only payload context provides phase-specific data, but Aurora doesn't have instructions on how to use it

#### 3. Behavioral Guidelines Missing from Prompt

**Documented but Not in Prompt:**

- Action-first approach (never ask for confirmation)
- Reflection vs. Execution routing guidelines
- Intent Cluster Prediction confidence handling (<40% abstain logic)
- ARTE emotional state awareness
- Predictive Cognition proactive interventions
- Document analysis execution request handling
- Compound operations guidelines
- Confidence awareness tone adaptation
- Cognitive health proactive suggestions
- Style adaptation guidelines

#### 4. Natural Language Commands Not Documented in Prompt

The documentation lists extensive natural language commands Aurora understands, but these aren't in the system prompt. Aurora learns them implicitly through execution intent detection, but explicit examples would help.

## Recommended Improvements

### Priority 1: Enhance System Prompt with Phase Documentation

**File:** `Cloutmate/Services/OllamaBridgeService.swift` - `buildSystemPrompt()` method

**Add comprehensive phase documentation section:**

1. **Phase Overview Section** - Brief summary of all 9 phases with key capabilities
2. **Behavioral Guidelines Section** - Action-first, reflection vs execution, emotional awareness
3. **Phase-Specific Instructions:**

- Phase 5++: Intent Cluster Prediction (confidence thresholds, abstain logic)
- Phase 7: ARTE emotional state awareness
- Phase 8: Rituals and Smart Nudges
- Phase 9: Predictive Cognition and drift detection
- Phase 10: Flow Companion

4. **Natural Language Commands Section** - Examples of what Aurora understands
5. **Execution Guidelines** - Compound operations, @ mention linking, reminder creation
6. **Document/Image Analysis Guidelines** - When to execute vs. analyze, execution request handling

### Priority 2: Create System Prompt Builder Service

**New File:** `Cloutmate/Services/AuroraSystemPromptBuilder.swift`

**Purpose:** Centralize system prompt construction with modular sections:

- Phase documentation sections (loaded from markdown or structured data)
- Behavioral guidelines (modular, phase-aware)
- Natural language examples (context-aware)
- Dynamic capability injection based on enabled phases

**Benefits:**

- Easier to maintain and update
- Can load from documentation files
- Phase-aware prompt building
- Testable prompt sections

### Priority 3: Update Documentation Accuracy

**Files:** `AURORA_README.md`, `AURORA_KNOWLEDGE_BASE_UPDATED.md`

**Changes:**

1. Clarify that system prompts are "basic" and phase details come from payload context
2. Add note about where phase documentation actually lives (markdown files vs. system prompts)
3. Document the gap between comprehensive docs and actual prompt content
4. Add section on "How Aurora Learns Her Capabilities" (through payload context, not prompt)

### Priority 4: Add Phase-Aware Prompt Sections

**Enhancement:** Make system prompt sections conditional based on enabled phases

**Implementation:**

- Check metadata flags (arteEnabled, predictiveCognitionEnabled, etc.)
- Only include relevant phase documentation
- Reduce prompt bloat while maintaining completeness

### Priority 5: Behavioral Instruction Consolidation

**Issue:** Behavioral instructions are scattered across:

- `buildSystemPrompt()` base prompt
- Service-generated instructions (PersonalityQuirksService, SelfAwarenessService, etc.)
- Payload context formatting

**Solution:** Create unified behavioral instruction builder that:

- Consolidates all behavioral guidelines
- Organizes by category (action, reflection, emotional, predictive)
- Ensures consistency across all instruction sources

## Implementation Plan

### Step 1: Audit Current Prompt Content

- Document exactly what's in the current prompt
- Compare line-by-line with documentation claims
- Create gap analysis document

### Step 2: Design Enhanced Prompt Structure

- Design modular prompt sections
- Define phase-specific instruction templates
- Plan for dynamic capability injection

### Step 3: Implement System Prompt Builder

- Create `AuroraSystemPromptBuilder.swift`
- Migrate existing prompt logic
- Add phase documentation sections
- Add behavioral guidelines sections

### Step 4: Update Documentation

- Clarify documentation vs. implementation reality
- Add "How It Actually Works" section
- Update accuracy claims

### Step 5: Test and Validate

- Test prompt length (ensure it fits context window)
- Validate phase-specific instructions work
- Test behavioral guidelines are followed
- Verify natural language commands work

## Files to Modify

1. **`Cloutmate/Services/OllamaBridgeService.swift`**

- Enhance `buildSystemPrompt()` method
- Add phase documentation sections
- Add behavioral guidelines

2. **`Cloutmate/Services/AuroraSystemPromptBuilder.swift`** (NEW)

- Centralized prompt building service
- Modular section builders
- Phase-aware prompt construction

3. **`AURORA_README.md`**

- Add accuracy clarifications
- Document actual prompt content vs. documentation
- Add "Implementation Details" section

4. **`AURORA_KNOWLEDGE_BASE_UPDATED.md`**

- Update claims about prompt comprehensiveness
- Add note about payload context vs. prompt content

## Success Criteria

- ✅ System prompt includes comprehensive phase documentation
- ✅ Behavioral guidelines are explicitly documented in prompt
- ✅ Natural language command examples are included
- ✅ Phase-specific instructions are present
- ✅ Documentation accurately reflects implementation
- ✅ Prompt length remains manageable (<7000 chars base)
- ✅ All documented capabilities are referenced in prompt
- ✅ **Prompt versioning system tracks cognitive configurations**
- ✅ **Aurora can query her current prompt version**
- ✅ **Prompt versions linked to changelog commits**
- ✅ **Evolution map shows prompt changes over time**

## Risks and Considerations

1. **Prompt Length:** Adding comprehensive documentation may exceed context limits

- **Mitigation:** Use modular sections, load conditionally, summarize where possible

2. **Maintenance Burden:** More prompt content = more to maintain

- **Mitigation:** Centralize in builder service, version control prompt sections

3. **Performance:** Larger prompts may slow response generation

- **Mitigation:** Test performance, optimize prompt construction, cache where possible

4. **Documentation Drift:** Prompt and docs may drift apart over time

- **Mitigation:** Generate prompt sections from documentation, automated testing

### To-dos

- [ ] Audit current system prompt content in buildSystemPrompt() and document exactly what is included vs. what documentation claims
- [ ] Design enhanced prompt structure with modular sections for phase documentation, behavioral guidelines, and natural language examples
- [ ] Create AuroraSystemPromptBuilder.swift service to centralize prompt construction with phase-aware sections
- [ ] Add comprehensive phase documentation sections (Phases 1-10) to system prompt with behavioral guidelines
- [ ] Add behavioral guidelines section covering action-first approach, reflection vs execution, intent clusters, ARTE awareness, predictive cognition
- [ ] Add natural language command examples section to help Aurora understand user intent patterns
- [ ] Update AURORA_README.md and AURORA_KNOWLEDGE_BASE_UPDATED.md to accurately reflect prompt content vs. documentation reality
- [ ] Test enhanced prompt length to ensure it fits within context window limits (<7000 chars base)
- [ ] Test that Aurora follows behavioral guidelines (action-first, reflection routing, intent clusters, etc.)