# Aurora Architecture Guide

Aurora is an on-device cognitive operating system layered on top of the FocusOS workspace. The runtime lives entirely inside the macOS target under `FocusOS/Services` and `FocusOS/Models`, with SwiftData providing the long-term memory substrate. This document describes how a single message flows through the system and how each phase contributes to the final response.

---

## 1. High-Level Message Flow

```
User Input
  ↓
AIAssistantViewModel.processMessage()
  ↓ intent detection → reflection or execution?
Reflection            Execution
(AIReflectionService)  (AIActionRouter)
  ↓                        ↓
AnalyticsEngine snapshot   Workspace mutations via services (Tasks, Projects, Drafts, etc.)
  ↓                        ↓
Payload Context Builder (context, memories, CPS, themes, reminders)
  ↓
AuroraSystemPromptBuilder + AuroraToneKit assemble system prompt with version tracking
  ↓
ModelRoutingEngine chooses model + thinking mode; ModelWarmupService / HybridBridge / FallbackRoutingService ensure availability
  ↓
OllamaBridgeService streams tokens (optionally via Hybrid Bridge) with typing simulation + response timing tuning
  ↓
Post-processing: AIActionRouter executes directives, AIFeedbackLogger stores learning signals, CPS boosted, MemoryGraph updated, Flow systems notified.
```

Everything above happens per conversational turn; background services (PredictiveContextManager, CognitiveHealthService, MemoryConsolidationService, etc.) continuously enrich the payload context even when no chat is active.

---

## 2. Layered Services (Phases 1–10)

| Phase | Focus | Key Files |
| --- | --- | --- |
| 1 | Recall + emotional continuity | `AIRecallService.swift`, `EmotionAnalyzer.swift`, `RecallIndexEntry` (model) |
| 2 | Action routing + feedback loop | `AIActionRouter.swift`, `AIFeedbackLogger.swift` |
| 3 | Contextual Priority System | `PriorityEngine.swift`, `PriorityScore.swift`, `FocusGravityService.swift` |
| 4 | Focus Mode | `FocusSessionService.swift`, `FocusSession.swift`, Focus Mode UI |
| 5 | Narrative Engine | `NarrativeEngine.swift`, `ConceptTracker.swift`, `StoryToken.swift`, `StoryArc.swift` |
| 5+ | Cross-conversation memory | `ConversationArchive.swift`, `ConversationDigest.swift`, `ConversationCompressionService.swift` |
| 5++ | Intent cluster prediction | `ConversationArchive.extractIntentClusters()`, `IntentClusterSummary` |
| 6 | Memory Graph | `MemoryGraphService.swift`, `MemoryNode.swift`, `MemoryEdge.swift`, `ThemeExtractionPipeline.swift` |
| 6.1 | Intelligence dashboard visibility + automation | `AnalyticsEngine.swift`, `Insights` views, `SmartAutomationEngine.swift` |
| 6.1+ | Reflection vs. execution routing | `AIReflectionService.swift`, `CoreResponseService.swift` |
| 7 | ARTE emotional UI | `ReactiveThemeManager.swift`, `EmotionalStateDetector.swift`, `ThemeInterpolator.swift`, `ARTEConfiguration.swift` |
| 8 | Focus rituals + smart nudges | `FocusRitualManager.swift`, `RitualAnalytics.swift`, `SmartNudgeService.swift`, `NudgeToneAdapter.swift` |
| 9 | Predictive cognition + temporal intelligence | `CognitionPredictor.swift`, `PredictiveContextManager.swift`, `DriftMonitor.swift`, `AdaptiveScheduler.swift`, `CalendarSyncService.swift` |
| 10 | Flow Companion | `FlowCompanionEngine.swift`, `FlowTriggersService.swift`, `AIFlowCompanion.swift`, `FlowCompanionState.swift` |

Each phase augments the payload context or the UI so that later phases (e.g., Predictive Brain, Flow Companion) can react to the same signals Aurora sees.

---

## 3. Request Lifecycle in Detail

1. **Input pre-processing** (`AIAssistantViewModel.processMessage`)
   - Normalizes mentions via `MentionParser`/`MentionService` so `@Object` links to SwiftData entities.
   - Applies `CasualConversationDetector` to flag casual vs imperative instructions before routing.
   - Runs `ContextSwitchGuard` checks for focus-mode interruptions.

2. **Intent routing**
   - `CoreResponseService.detectReflectionIntent` tries reflection intents (productivity, emotional trends, etc.).
   - If matched → `AIReflectionService` builds narrative from `AnalyticsEngine.generateSnapshot()`.
   - Else → `AIActionRouter` executes structured actions (create/update tasks, artifacts, reminders, doc analysis commands, etc.).

3. **Payload context assembly**
   - `AnalyticsEngine`, `FocusSessionService`, `FlowCompanionEngine`, `MemoryGraphService`, `PriorityEngine`, `ConversationArchive`, `PredictiveContextManager`, `CognitionPredictor` feed `AIPayloadContext`.
   - `AIConfig.plist` feature flags gate expensive subsystems (Memory Graph, ARTE, etc.).

4. **Prompt building**
   - `AuroraSystemPromptBuilder` composes modular sections (identity, phases, commands, behavior, schema) and versions them in `aurora_prompt_versions.json`.
   - Dynamic instructions: tone, personality, self-awareness, context, pattern, memory, schema references.

5. **Model routing**
   - `ModelRoutingEngine` chooses models using: research overrides, image/document detection, intent-cluster cache, cooldown stickiness, casual heuristics, reasoning triggers.
   - Delegates to `ModelTierMap` definitions (gemma/qwen/gwen/deepseek/granite + qwen3-vl for vision).
   - `ModelWarmupService` pre-loads models at launch; `HybridBridgeService` optionally routes to Ollama Cloud; `FallbackRoutingService` + `AppleLLMService` + `OfflineSummarizationService` ensure responses even if local models are unavailable.

6. **Generation + streaming**
   - `OllamaBridgeService` handles document/image encoding, streaming responses, and attaches `thinking` traces when supported.
   - `ResponseTimingService`, `TypingSimulationService`, and `StyleAdapter` polish UX.

7. **Post-processing hooks**
   - Execution: `AIActionRouter` writes to SwiftData models, `AIFeedbackLogger` records successes, `CreateActionUsageTracker` updates heuristics.
   - Reflection: `AIReflectionService` references Insights panes, writes `ReflectionNote`s.
   - Memory Graph + Recall: `MemoryGraphService` nodes/edges, `AIRecallService` snapshots, `MemoryWeavingService` reinforcement.
   - Predictive / Flow: `DriftMonitor`, `FlowCompanionEngine`, `SmartNudgeService` observe events for next triggers.

---

## 4. Data Contracts

- **`AIPayloadContext`** aggregates everything the model needs: CPS priorities, current ARTE state, predictive posture, Flow Companion triggers, intent clusters, memory themes, known rituals, etc.
- **`AuroraPromptVersions`** persists prompt evolution with commit hashes, enabling Aurora to self-report her version.
- **`ConversationDigest`**/`IntentClusterSummary` provide cross-conversation intelligence for predictive questions.
- **`AnalyticsSnapshot`** underpins reflections, ARTE detection, predictive posture, and Flow Companion prompts.

Any new service should either extend `AnalyticsEngine` or register hooks with `MemoryGraphService`, `PriorityEngine`, or `PredictiveContextManager` to stay in sync with the assistant.

---

## 5. Observability & Self-Maintenance

- **Feedback logging** (`AIFeedbackLogger`) records successes/failures, powering weekly learning loop insights.
- **Cognitive health checks** (`CognitiveHealthService`) track memory density, stale entries, prompt pressure.
- **Confidence + tone** (`ConfidenceScorer`, `AuroraToneKit`, `ToneForecastService`) modulate responses and Flow Companion behavior.
- **Telemetry**: `ThemeTelemetryService`, `MemoryGraphTelemetry`, `ToolbarUsageTracker`, and `ResponseTimingService` emit metrics surfaced in Insights or logs.

---

## 6. Extending Aurora Safely

When adding new capabilities:
1. **Define the model + service** (e.g., `DeepResearchService`).
2. **Register with payload builders** if the feature should appear in prompts.
3. **Update `AuroraSystemPromptBuilder`** sections so the assistant knows about the capability.
4. **Extend tests/docs** (`AURORA_README.md`, `AURORA_KNOWLEDGE_BASE_UPDATED.md`) and, when applicable, the new blueprint files.
5. **Audit** using `AURORA_IMPLEMENTATION_AUDIT.md` as a checklist to ensure parity between docs and code.

Aurora relies on accurate documentation as much as implementations—keep both synchronized to preserve her self-awareness and avoid drift.
