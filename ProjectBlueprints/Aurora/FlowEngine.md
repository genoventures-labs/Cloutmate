# Flow Companion & Reflection Bubble

Phase 10 introduced the Flow Companion—Aurora’s clarity coach that surfaces contextual prompts whenever attention drifts, rituals end, or the user becomes idle. This doc covers how the Flow Engine works across services and UI.

---

## 1. Moving Pieces

| Component | Role | Key Files |
| --- | --- | --- |
| `FlowCompanionEngine` | Controls the floating reflection bubble, prompt selection, persistence, and panel expansion. | `Cloutmate/Services/FlowCompanionEngine.swift` |
| `FlowTriggersService` | Monitors drift, rituals, idle detection, manual triggers, and broadcasts when to show prompts. | `Cloutmate/Services/FlowTriggersService.swift` |
| `FlowCompanionSettings` | Stores enablement, trigger toggles (drift/evening/idle), idle timeout, reflection tone, and bubble duration. | Inside `FlowTriggersService.swift` |
| `MetaReflectionProcessor` | Analyzes responses, updates CPS weights, syncs ARTE state, and records analytics. | `Cloutmate/Services/MetaReflectionProcessor.swift` |
| `FlowCompanionState` | SwiftData model tracking Flow Companion personality, interaction history, total nudges. | `Cloutmate/Models/FlowCompanionState.swift` |
| `AIFlowCompanion` | Generates longer-form insights/nudges with a distinct "clarity coach" tone. | `Cloutmate/Services/AIFlowCompanion.swift` |
| `AIFlowCompanionView` | Settings + insight log for the coach. | `Cloutmate/Views/AIFlowCompanion/AIFlowCompanionView.swift` |
| `FlowHoldService` | Temporarily blocks notifications during deep work windows. | `Cloutmate/Services/FlowHoldService.swift` |

---

## 2. Trigger Pipeline

1. **Monitoring**
   - `DriftMonitor` publishes drift + momentum events when focus sessions slip.
   - `FocusRitualManager` posts notifications when rituals open/close.
   - `MainWindowView` posts `.UserActivity` notifications on tab switches, quick capture usage, etc.
   - Idle timer inside `FlowTriggersService` increments when no activity occurs and triggers after the configured timeout.

2. **Trigger Evaluation**
   - Each trigger (drift, evening, idle, manual) checks if it’s enabled in `FlowCompanionSettings` before firing.
   - Once triggered, `shouldTriggerReflection` flips to `true`, `currentTriggerType` is set, and the Flow Companion bubble animates in.

3. **Prompt Selection**
   - `FlowCompanionEngine` loads `ReflectionPrompts.plist` grouped by ARTE emotion states, falling back to defaults if the plist is missing.
   - When the bubble opens, it picks a prompt that matches both the trigger type and ARTE state for emotional resonance.
   - Bubble auto-dismisses after ~60 seconds (configurable) unless the user responds.

4. **Response Handling**
   - User text is wrapped in a `ReflectionNote` with emotion tint and context tags.
   - `MetaReflectionProcessor` analyzes responses, updates CPS weights, informs `MomentumMetrics`, and optionally syncs ARTE state.
   - `RitualAnalytics` records reflections so Insights can display them.
   - Long responses (>100 chars) open the reflection panel for deeper journaling.

5. **AI Flow Companion**
   - Personalized insights and nudges live in `AIFlowCompanion`. It observes momentum, ARTE state, rituals, and focus completions.
   - Personalities (`clarityCoach`, `momentumGuide`, `reflectionPartner`) adjust tone and phrasing; configured via `AIFlowCompanionView`.
   - Insights are persisted to `FlowCompanionState.interactionHistory` and can be refreshed manually.

---

## 3. UI Surfaces

- **Bubble** – Minimal UI overlay triggered anywhere in the app.
- **Full Panel** – Presents longer responses with additional context.
- **Settings** – Toggle triggers, idle timeout, tone, intensity.
- **AI Flow Companion Tab** – Review insights, change personality, trigger manual insights.

---

## 4. Extending Flow Companion

- **New triggers** – Add detection logic in `FlowTriggersService` and extend `ReflectionTriggerType`. Remember to update settings + UI toggles.
- **Prompt packs** – Update `ReflectionPrompts.plist` with new emotion keys or import remote prompt packs.
- **Personalities** – Extend `FlowCompanionPersonality` + `AIFlowCompanion` prompt builders for new voices.
- **Integrations** – Hook external signals (Calendar events, Focus modes) by posting notifications or plugging services into `FlowTriggersService`.

---

## 5. Debugging Tips

- Logs use the `FlowCompanion`/`FlowTriggers` categories; watch Console.app to confirm triggers fire.
- Ensure `FlowCompanionSettings.isEnabled` is true before expecting prompts.
- Idle detection relies on `.UserActivity` notifications—call `FlowTriggersService.shared.updateActivity()` from new UI elements that should reset idle timers.
- Prompts not saving? Verify `ReflectionNote` is inserted and `modelContext.save()` succeeds in `FlowCompanionEngine.handleResponse`.

The Flow Companion is the human layer that keeps users in dialogue with themselves. Keep prompts contextual, make tone adjustments through `AuroraToneKit`, and let predictive posture determine when to be supportive vs. assertive.
