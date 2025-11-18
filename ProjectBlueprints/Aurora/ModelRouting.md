# Aurora Model Routing Reference

Aurora runs entirely on-device through Ollama, but every request passes through a sophisticated routing stack that balances latency, reasoning quality, and modality needs. This document summarizes how models are selected, warmed, and recovered when failures occur.

---

## 1. Components

| Component | Role | Key Files |
| --- | --- | --- |
| `ModelTierMap` | Declares all supported models, tiers, capabilities, and thinking-mode support. | `FocusOS/Models/ModelTierMap.swift` |
| `ModelRoutingEngine` | Central actor that selects the model per turn and enforces cooldown/stickiness. | `FocusOS/Services/ModelRoutingEngine.swift` |
| `CasualConversationDetector` | Flags casual chit-chat vs imperative commands to avoid overthinking short requests. | `FocusOS/Services/CasualConversationDetector.swift` |
| `ModelWarmupService` | Warms primary models at launch and monitors load times. | `FocusOS/Services/ModelWarmupService.swift` |
| `HybridBridgeService` | Optional cloud acceleration path via Ollama Cloud + OSS models with health checks. | `FocusOS/Services/HybridBridgeService.swift` |
| `FallbackRoutingService` | Graceful degradation (Apple LLM / offline summarizer) when Ollama fails. | `FocusOS/Services/FallbackRoutingService.swift`, `AppleLLMService.swift`, `OfflineSummarizationService.swift` |
| `ConfidenceScorer` | Tracks response confidence + abstain heuristics surfaced to the UI. | `FocusOS/Services/ConfidenceScorer.swift` |
| `ResponseTimingService` & `TypingSimulationService` | Balance streaming cadence and typing animation once a route is chosen. | `FocusOS/Services/ResponseTimingService.swift`, `TypingSimulationService.swift` |

---

## 2. Model Inventory (`ModelTierMap`)

| Name | Capability Highlights | Typical Use |
| --- | --- | --- |
| `gemma3:1b` | Fast casual chat | Small talk, confirmations, sticky follow-ups when marked casual |
| `qwen3:1.7b` | Thinking support, general tasks | Default task model, thinking-enabled |
| `qwen3-vl:2b` | Vision | Image analysis, multimodal prompts |
| `granite3.2-vision` | Vision fallback | Secondary image model |
| `gemma3:4b` | Document analysis | PDF/text ingestion, image fallback |
| `gwen2.5-coder:1.5b` | Coding/reasoning | Structured reasoning, coding/tool output |
| `deepseek-r1:1.5b` | Research/doc fallback | Deep research chains + fallback when gemma fails |
| `granite3.2:2b` | Background cognition | Confidence scaffolding, cognition summaries |

All models are expected to be locally available via Ollama. When Airplane Mode is off, hybrid routing can optionally call `deepseek-r1` or `gpt-oss:20b` through the cloud path, but the same tier metadata applies.

---

## 3. Selection Algorithm

1. **Research override** – `/research` commands and deep research mode force the research tier list (DeepSeek → GPT-OSS). Cooldown/stickiness ensures the same model handles the entire research session.
2. **Casual detection** – `CasualConversationDetector` considers tone, length, and detected imperative verbs. Short casual requests go to `gemma3:1b`; imperative verbs override casual classification.
3. **Intent cluster cache** – If the conversation has a current `IntentClusterSummary`, the routing engine reuses the last successful model for that cluster to preserve continuity.
4. **Cooldown & stickiness** – Recently used models stay active for three turns to avoid jarring switches mid-thread.
5. **Task determination** – Non-casual inputs choose between reasoning/coding (`gwen2.5-coder`) vs. general task (`qwen3:1.7b`) vs. doc/image specialized models.
6. **Fallback validation** – If a chosen model is missing locally, the engine swaps to `ModelTierMap.defaultModel()` (`gemma3:1b`) while logging the fallback.
7. **Thinking mode** – Enabled when the selected model supports it (per tier metadata) and the message is not casual; disabled for short/casual prompts to prioritize speed.

Research, image, and document flows bypass most heuristics and route directly to the correct tier to avoid prompting a chat model with binary data.

---

## 4. Warmup & Health Checks

- `ModelWarmupService` starts at app launch, sequentially pings required Ollama models, and records load times in SwiftData so Aurora can say "Warming up Qwen3" with accurate durations.
- `HybridBridgeService.performHealthCheck` validates the cloud API key (if provided) and toggles networking fallback.
- `FallbackRoutingService` monitors failures from `OllamaBridgeService` and transparently routes requests through:
  1. `AppleLLMService` (on-device Summarization / Translation APIs) when the request matches supported use cases.
  2. `OfflineSummarizationService` for deterministic heuristics when no LLM is reachable.
- `ModelRoutingEngine.clearCooldown()` is called during app launch to avoid stale stickiness after cold boots.

---

## 5. Integration Points

- **Reflection responses** use the same routing logic but typically end up on `qwen3:1.7b` with thinking on, because reflection prompts exceed the `>80` character reasoning threshold.
- **Document/image attachments** call `OllamaBridgeService.analyzeDocument` / `.analyzeImage`, which select `gemma3:4b` or `qwen3-vl:2b` directly and reformat payloads (base64 for vision).
- **Hybrid Bridge** automatically falls back to local models when the network stalls; Aurora notifies the user via `HybridBridgeService` status updates.
- **Research mode** triggers `ResearchAction` updates so the UI can stream "Searching...", "Synthesizing..." states while the routing engine sticks to the research model for at least three turns.

---

## 6. Adding or Updating Models

1. **Update `ModelTierMap.localModels`** with metadata (name, displayName, capabilities, tier, thinking support).
2. **Adjust heuristics** inside `ModelRoutingEngine` if the new model targets a special case (vision, reasoning, etc.).
3. **Teach Aurora**: update `AuroraSystemPromptBuilder` (model inventory section) and `AURORA_README.md` so she can describe the new capability.
4. **Warmup + fallback**: extend `ModelWarmupService` + `FallbackRoutingService` to cover the new model.
5. **Document**: add notes under `/ProjectBlueprints/Aurora/ModelRouting.md` if the logic changes materially.

Keeping the tier map, documentation, and prompts synchronized ensures Aurora can self-report which models she is using and why.
