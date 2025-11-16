<!-- 518b446e-4c31-4c41-96ce-ff2f5ea9383c a2125384-207f-42a7-8353-4b2f893680ad -->
# Aurora Model Routing Fix

## Overview
Fix Aurora's routing to assign models correctly. DeepSeek should only be used in research mode, not as the default. Implement the complete model hierarchy with proper fallbacks.

## Files to Modify

### 1. `Cloutmate/Models/ModelTierMap.swift`
**Current Issue:** Missing models and incorrect default/fallback assignments.

**Changes:**
- Add missing models to `localModels` array:
  - `gemma3:1b` - Casual conversations (primary)
  - `qwen3:1.7b` - Casual fallback, tasks with thinking
  - `qwen3-vl:2b` - Image processing (primary)
  - `granite3.2-vision` - Image processing (secondary)
  - `gemma3:4b` - Document analysis (primary), image fallback
  - `deepseek-r1:1.5b` - Document analysis fallback, research mode only
  - `gwen2.5-coder:1.5b` - Coding and secondary reasoning
- Update `defaultModel()` to return `"gemma3:1b"` (casual primary)
- Update `fallbackModel()` to return `"qwen3:1.7b"` (casual fallback)
- Add helper methods:
  - `casualModel()` → `"gemma3:1b"`
  - `casualFallbackModel()` → `"qwen3:1.7b"`
  - `taskModel()` → `"qwen3:1.7b"` (with thinking enabled)
  - `imageModel()` → `"qwen3-vl:2b"`
  - `imageSecondaryModel()` → `"granite3.2-vision"`
  - `imageFallbackModel()` → `"gemma3:4b"`
  - `documentModel()` → `"gemma3:4b"`
  - `documentFallbackModel()` → `"deepseek-r1:1.5b"`
  - `codingModel()` → `"gwen2.5-coder:1.5b"`
  - `reasoningModel()` → `"gwen2.5-coder:1.5b"`
  - `researchModels()` → `["deepseek-r1:1.5b", "gpt-oss:20b"]` (cloud models)
- Update `thinkingModel()` to return `"qwen3:1.7b"` (not Gwen3:8b)
- Update `supportsThinking` flags appropriately
- Update `displayName(for:)` to handle all new models

### 2. `Cloutmate/Services/ModelRoutingEngine.swift`
**Current Issue:** Incorrectly routing to DeepSeek for regular conversations. No research mode detection.

**Changes:**
- Update `selectModel()` method:
  - Remove DeepSeek from regular routing logic
  - Casual conversations: Use `gemma3:1b`, fallback to `qwen3:1.7b`
  - Non-casual (tasks): Use `qwen3:1.7b` with thinking enabled
  - Reasoning tasks: Use `gwen2.5-coder:1.5b` as secondary reasoning model
  - **Universal fallback:** If all fallbacks fail, default to `gemma3:1b` as global safe fallback
- Add research mode parameter: `isResearchMode: Bool = false`
- In `selectModel()`, if `isResearchMode` is true:
  - Return DeepSeek-R1 or OpenAI-OSS (only accessible via research mode)
  - Never route to DeepSeek for non-research requests
- Update cooldown logic to respect research mode (don't apply research model cooldown to casual queries)
- Add method `selectImageModel()` → returns `qwen3-vl:2b` with fallback chain
  - **Safety guard:** Force `isResearchMode = false` in this method regardless of conversation mode
- Add method `selectDocumentModel()` → returns `gemma3:4b` with `deepseek-r1:1.5b` fallback
  - **Safety guard:** Force `isResearchMode = false` in this method regardless of conversation mode
- **Add verbose routing logs** (only when DebugMode is enabled):
  - Log selected model, fallback triggers, research mode activation, tool usage
  - Use conditional logging: `#if DEBUG` or check for DebugMode flag

### 3. `Cloutmate/Services/OllamaBridgeService.swift`
**Current Issue:** Image/document processing may not use correct models.

**Changes:**
- In `analyzeImage()` method:
  - Use `ModelTierMap.imageModel()` (qwen3-vl:2b) as primary
  - Fallback chain: granite3.2-vision → gemma3:4b
  - Update to use routing engine's `selectImageModel()` if available
- In `analyzeDocument()` method:
  - Use `ModelTierMap.documentModel()` (gemma3:4b) as primary
  - Fallback to `ModelTierMap.documentFallbackModel()` (deepseek-r1:1.5b) only on failure
  - Ensure DeepSeek is never primary, only fallback for documents
- Update `generateResponseWithAppContext()`:
  - Check for research mode flag (if passed via payload context or conversation mode)
  - Route to research models only when research mode is active
  - Default to casual/task routing otherwise

### 4. `Cloutmate/ViewModels/AIAssistantViewModel.swift`
**Current Issue:** Research mode may not be properly communicated to routing engine.

**Changes:**
- In `handleImageMessage()`:
  - Ensure it uses image model routing from `ModelRoutingEngine` or `ModelTierMap`
- In `handleDocumentMessage()`:
  - Ensure it uses document model routing with proper fallback
- In `processMessage()`:
  - Detect research mode via `/research` command or `researchModeActive` flag
  - Pass `isResearchMode: true` to routing engine when research mode is active
  - Ensure research mode flag is passed to `CoreResponseService.generateResponseWithAppContext()`

### 5. `Cloutmate/Services/CoreResponseService.swift`
**Current Issue:** May not pass research mode flag to routing engine.

**Changes:**
- Update `generateResponseWithAppContext()`:
  - Check for research mode in payload context or conversation mode
  - Pass `isResearchMode` flag to `ModelRoutingEngine.selectModel()` when research mode is active
- Ensure research mode routing bypasses casual detection

### 6. `Cloutmate/Services/HybridBridgeService.swift`
**Current Issue:** May route to cloud models incorrectly.

**Changes:**
- In `generateResponseWithAppContext()`:
  - Only use cloud models (OpenAI-OSS, DeepSeek) when research mode is active
  - For regular requests, use local Ollama routing only
- Update cloud model selection to check research mode flag

### 7. `Cloutmate/Services/ModelWarmupService.swift`
**Current Issue:** Missing new models in warmup list.

**Changes:**
- Update `startWarmup()` to include all new models:
  - `gemma3:1b` (casual primary)
  - `qwen3:1.7b` (casual fallback, tasks)
  - `qwen3-vl:2b` (image processing)
  - `granite3.2-vision` (image secondary)
  - `gemma3:4b` (documents, image fallback)
  - `gwen2.5-coder:1.5b` (coding, reasoning)
  - `deepseek-r1:1.5b` (research mode, document fallback)
- Ensure `granite3.2:2b` is still warmed up (background layer)
- Update `allLocalModels` reference to use `ModelTierMap.allLocalModels()`

### 8. `Cloutmate/Services/CasualConversationDetector.swift`
**No changes needed** - This is working correctly for casual detection.

## Research Mode Implementation

Research mode should be fully implemented following the research-mode-implementation-e70b680d.plan.md specifications:

### Research Mode Detection & Activation
- Detect `/research [topic]` command in user input
- Set `researchModeActive` flag in `AIAssistantViewModel`
- Pass `isResearchMode: true` through the routing chain
- Only use DeepSeek-R1, OpenAI-OSS, and Ollama Search (via WebSearchService) when research mode is active

### Research Mode Flow (using WebSearchService)
1. User triggers `/research [topic]` command
2. `AIAssistantViewModel` detects and sets `researchModeActive = true`
3. `CoreResponseService.generateResearchResponse()` is called (create if doesn't exist)
4. Research flow:
   - Use `WebSearchService.deepResearch()` to perform multi-query web searches
   - Emit progress updates: "Searched for: [query]" with source count
   - Analyze results with local model (DeepSeek-R1) first
   - Then analyze with cloud model (OpenAI-OSS/gpt-oss:20b) if available
   - Emit progress: "Analyzing with DeepSeek R1...", "Analyzing with cloud model..."
   - Synthesize comprehensive report from all sources

### Research Progress Tracking
- Add `currentResearchAction: String?` and `currentResearchSourceCount: Int` to `AIAssistantViewModel`
- Add `updateResearchProgress(action: String, sourceCount: Int)` method
- Add `clearResearchProgress()` method
- Progress updates emitted via MainActor from WebSearchService callbacks
- Use `ResearchProgressIndicator` component (already exists) instead of ThinkingIndicator during research mode

## Model Usage Summary

- **Background Layer:** `granite3.2:2b` only
- **Casual Conversations:** `gemma3:1b` → `qwen3:1.7b` (fallback)
- **Tasks (Non-casual):** `qwen3:1.7b` with thinking enabled
- **Coding/Reasoning:** `gwen2.5-coder:1.5b`
- **Image Processing:** `qwen3-vl:2b` → `granite3.2-vision` → `gemma3:4b` (fallback)
- **Document Analysis:** `gemma3:4b` → `deepseek-r1:1.5b` (fallback)
- **Research Mode:** `deepseek-r1:1.5b`, `gpt-oss:20b`, Ollama Search (cloud models only)
- **Web Requests:** Route through standard routing (no special "Ollama Web" model needed - web search is a tool, not a model)

## Testing Checklist

- [ ] Casual conversations use Gemma3:1b
- [ ] Casual fallback uses Qwen3:1.7b
- [ ] Tasks use Qwen3:1.7b with thinking
- [ ] Research mode uses DeepSeek/OpenAI-OSS only
- [ ] DeepSeek never used outside research mode
- [ ] Images use qwen3-vl:2b with proper fallbacks
- [ ] Documents use gemma3:4b with DeepSeek fallback
- [ ] Coding uses gwen2.5-coder:1.5b
- [ ] All models are warmed up correctly
- [ ] Background layer uses Granite only
