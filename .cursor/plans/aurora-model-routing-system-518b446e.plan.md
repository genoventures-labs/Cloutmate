<!-- 518b446e-4c31-4c41-96ce-ff2f5ea9383c 07b84f3a-1e9c-43ee-8745-c5eb9f94d561 -->
# Vision Pipeline Architecture Implementation Plan

## Overview

Replace the current OCR-first image processing with a three-layer vision pipeline:

1. **QwenVisionLayer** (qwen3-vl:2b local) - Primary semantic vision intelligence
2. **OCRLayer** (SwiftyTesseract) - Fallback when Qwen fails
3. **GemmaInterpretationLayer** (gemma3:4b) - Cognitive reasoning that merges all outputs

**CRITICAL:** All layers run in detached Tasks to prevent UI thread blocking that caused previous crashes.

## Architecture Flow

```
Image Input → QwenVisionLayer (detached Task) → (confidence check) 
    → Good? → GemmaInterpretationLayer (detached Task) → Final Output
    → Bad? → OCRLayer (detached Task) → GemmaInterpretationLayer (detached Task) → Final Output
```

## Implementation Steps

### 1. Add qwen3-vl:2b to ModelTierMap

**File:** `FocusOS/Models/ModelTierMap.swift`

- Add `qwen3-vl:2b` back to `localModels` array with capabilities: `["vision", "image-processing", "multimodal"]`
- Update `imageModel()` to return `"qwen3-vl:2b"` as primary
- Keep `imageSecondaryModel()` and `imageFallbackModel()` methods for compatibility

### 2. Create VisionPipelineService

**New File:** `FocusOS/Services/VisionPipelineService.swift`

**Data Structures:**

- `VisionOutput` struct (rawVisionText, structuredItems, layoutNotes, visionConfidence)
- `OCROutput` struct (fullText, lines, regions, ocrConfidence)
- `PipelineContext` struct (qwenUsed, ocrUsed, fallbackTriggered, finalConfidence, processingPath)
- `VisionPipelineResult` struct (tasks, summary, detectedIntent, insights, finalConfidence, context: PipelineContext)
- `VisionConfidence` enum (high, medium, low, failed)

**Core Methods:**

- `processImage()` - Main entry point (all async, never blocks UI)
- `qwenVisionLayer()` - Layer 1: Local qwen3-vl:2b vision analysis (detached Task)
- `ocrLayer()` - Layer 2: SwiftyTesseract fallback (detached Task)
- `gemmaInterpretationLayer()` - Layer 3: Merge and interpret with gemma3:4b (detached Task)
- `evaluateQwenConfidence()` - Confidence scoring (0-100)
- `evaluateOCRQuality()` - OCR quality scoring (0-100)
- `mergeSignals()` - Combine qwen + OCR outputs
- `shouldFallbackToOCR()` - Determines when to trigger OCR fallback

### 3. QwenVisionLayer Implementation

**Method:** `qwenVisionLayer(imageData:prompt:modelContext:context:) async -> VisionOutput`

- **MUST run in detached Task:** `Task.detached { await ... }` - prevents UI blocking
- Use local Ollama with `qwen3-vl:2b` model via `OllamaBridgeService.makeOllamaRequestWithImages()`
- Extract structured output: rawVisionText, structuredItems, layoutNotes
- Calculate visionConfidence using `evaluateQwenConfidence()`
- Update PipelineContext: `qwenUsed = true`, append "QwenVisionLayer" to processingPath
- Return `VisionOutput` struct

**Confidence Evaluation Criteria:**

- Output length (>100 chars = +20, <50 = -30)
- Noun/verb presence (+20 if contains both)
- Hallucination detection (checks for generic summaries when tasks expected)
- Task extraction success (+30 if tasks found)
- Error handling (timeout = -40, empty = -50)

### 4. OCRLayer Implementation

**Method:** `ocrLayer(imageData:context:) async -> OCROutput`

- **MUST run in detached Task:** `Task.detached { await ... }` - prevents UI blocking
- Reuse existing SwiftyTesseract OCR from `ImageAnalysisService`
- Extract: fullText, lines (split by newlines), regions (placeholder for bounding boxes)
- Calculate ocrQualityScore (text length, character variety, line structure)
- Update PipelineContext: `ocrUsed = true`, append "OCRLayer" to processingPath
- Return `OCROutput` struct

### 5. GemmaInterpretationLayer Implementation

**Method:** `gemmaInterpretationLayer(qwenOutput:ocrOutput:userPrompt:appContext:modelContext:context:) async -> VisionPipelineResult`

- **MUST run in detached Task:** `Task.detached { await ... }` - prevents UI blocking
- Use `gemma3:4b` via `OllamaBridgeService.generateResponse()`
- Build prompt that includes:
  - Qwen's vision output (if available)
  - OCR raw text (always included as fallback)
  - Original user prompt
  - Instructions to merge, normalize, and structure output
- Parse gemma response to extract: tasks, summary, detectedIntent, insights
- Calculate finalConfidence (weighted average of all scores)
- Update PipelineContext: append "GemmaInterpretationLayer" to processingPath, set finalConfidence
- Return `VisionPipelineResult` struct with populated PipelineContext

**Prompt Structure:**

```
You are interpreting vision analysis results. Combine the following:

Vision Intelligence (if available):
[Qwen output]

OCR Text (always available):
[OCR output]

User Request: [userPrompt]

Extract:
- Tasks: [structured list]
- Summary: [brief description]
- Intent: [detected intent]
- Insights: [key observations]
```

### 6. Confidence Engine Implementation

**Methods:**

- `evaluateQwenConfidence(output:) -> Int` - Scores 0-100 based on quality metrics
- `evaluateOCRQuality(output:) -> Int` - Scores 0-100 based on readability
- `calculateFinalConfidence(qwen:ocr:gemma:) -> Int` - Weighted average

**Scoring Logic:**

- qwenVisionScore: Output quality, structure, task detection
- ocrQualityScore: Text readability, line structure
- gemmaInterpretationScore: Reasoning quality (parsed from gemma response)

### 7. Multi-Signal Merging Logic

**Method:** `mergeSignals(qwen:ocr:) -> String`

- Start with qwen's structuredItems if available
- Patch missing pieces using OCR lines
- Remove duplicates (fuzzy matching)
- Normalize structure (task formatting, list ordering)
- Return merged text for Gemma to interpret

### 8. Failure-Proofing

**Method:** `handleFailure(qwen:ocr:gemma:context:) -> VisionPipelineResult`

- If all layers fail, return minimal summary with UX-friendly message:
  - **Aurora response:** "I wasn't able to understand the full image, but here's what I can say..."
  - What's visible (if anything)
  - Why parts are missing
  - Suggestions for better screenshot
- Never throw errors to UI - always return some result
- Log failures for debugging but gracefully degrade
- Update PipelineContext: `fallbackTriggered = true`, append "FailureFallback" to processingPath

### 9. Update CoreResponseService

**File:** `FocusOS/Services/CoreResponseService.swift`

- Update `analyzeImage()` to call `VisionPipelineService.shared.processImage()` (already async)
- Convert `VisionPipelineResult` to `DocumentAnalysisResult`
- Map confidence scores appropriately
- Extract PipelineContext for transparency messages

### 10. UI State Updates

**File:** `FocusOS/ViewModels/AIAssistantViewModel.swift`

- Add state tracking: `.processingVision`, `.processingOCR`, `.interpreting`
- Update `handleImageMessage()` to show processing states with context tags:
  - **"Scanning image... Using on-device vision"** (blue shimmer) during Qwen
  - **"Extracting text... Using fallback OCR"** (if OCR fallback triggered)
  - **"Understanding what's shown..."** (purple shimmer) during Gemma
- After processing completes, use PipelineContext to generate user-friendly explanation:
  - If OCR was used: "I used OCR because the vision output was incomplete."
  - If both used: "I combined what I saw visually with the extracted text."
  - If fallback triggered: "Qwen didn't give enough detail, so I filled in the gaps."
- These explanations boost UX trust and show intentional transparency

### 11. Integration Points

**Files to update:**

- `FocusOS/Services/OllamaBridgeService.swift` - Ensure `makeOllamaRequestWithImages()` supports qwen3-vl:2b
- `FocusOS/Services/ModelWarmupService.swift` - Add qwen3-vl:2b to warmup list
- `FocusOS/Models/ModelTierMap.swift` - Already covered in step 1

### 12. Async Task Management (CRITICAL)

**All pipeline methods MUST:**

- Run in `Task.detached { await ... }` to prevent UI thread blocking
- Pipeline awaits tasks asynchronously, NOT the UI thread
- UI only updates on MainActor after results complete
- This prevents Aurora's chat from freezing during Ollama processing
- Use `await MainActor.run { ... }` only for final UI updates

### 13. PipelineContext Integration

**Purpose:** Track which layers were used so Aurora can explain her process transparently

**Implementation:**

- Initialize `PipelineContext` in `processImage()` with all flags = false
- Update context as each layer is used:
  - `qwenUsed = true` when QwenVisionLayer succeeds
  - `ocrUsed = true` when OCRLayer is called (fallback or intentional)
  - `fallbackTriggered = true` when fallback chain is activated
  - `processingPath` tracks order: ["QwenVisionLayer", "OCRLayer", "GemmaInterpretationLayer"]
- Pass context through all layers
- Include context in VisionPipelineResult
- Use context in UI to generate transparent explanations

## Success Criteria

- All images return structured output (tasks/summary)
- Qwen layer attempts first, OCR only on failure
- Gemma merges and normalizes all outputs
- Confidence scores guide fallback decisions
- UI shows clear processing states with context tags
- Zero hard failures - always returns something
- **No UI blocking - all processing in detached Tasks**
- **Aurora explains her process transparently using PipelineContext**

## Testing Considerations

- Test with screenshots, handwritten notes, diagrams, UI mockups
- Verify confidence scoring triggers correct fallbacks
- Ensure graceful degradation when models unavailable
- Test multi-signal merging with both qwen + OCR outputs
- **Verify UI remains responsive during processing (no freezing)**
- Test PipelineContext explanations appear correctly

### To-dos

- [ ] Add qwen3-vl:2b to ModelTierMap.localModels with vision capabilities
- [ ] Create VisionPipelineService.swift with data structures (VisionOutput, OCROutput, PipelineContext, VisionPipelineResult)
- [ ] Implement QwenVisionLayer using local Ollama qwen3-vl:2b model in detached Task
- [ ] Implement confidence scoring methods (evaluateQwenConfidence, evaluateOCRQuality, calculateFinalConfidence)
- [ ] Implement OCRLayer wrapping SwiftyTesseract in detached Task with structured output
- [ ] Implement PipelineContext tracking (qwenUsed, ocrUsed, fallbackTriggered, processingPath)
- [ ] Implement GemmaInterpretationLayer using gemma3:4b in detached Task to merge and interpret outputs
- [ ] Implement mergeSignals() to combine qwen + OCR outputs before Gemma interpretation
- [ ] Implement handleFailure() with graceful degradation and UX-friendly message: "I wasn't able to understand the full image, but here's what I can say..."
- [ ] Update CoreResponseService.analyzeImage() to use VisionPipelineService with async Task management
- [ ] Add processing states to AIAssistantViewModel with context tags ("Using on-device vision", "Using fallback OCR") and PipelineContext explanations
- [ ] Add qwen3-vl:2b to ModelWarmupService warmup list
- [ ] Test pipeline with various image types and verify UI remains responsive (no freezing)