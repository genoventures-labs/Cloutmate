# Predictive Brain (Phase 9) Guide

Aurora’s predictive capabilities anticipate fatigue, flow drift, and likely intent clusters before the user asks. This layer is a fusion of Cognition forecasts, drift monitoring, and proactive posture management.

---

## 1. Components

| File | Role |
| --- | --- |
| `CognitionPredictor.swift` | Generates `FocusForecast` records every few hours, analyzing the last 48 hours of rituals, focus sessions, state transitions, and nudges. |
| `PredictiveContextManager.swift` | Consumes forecasts + drift events, fuses signals (fatigue risk, focus stability, posture), and distributes them to tone systems and Flow Companion. |
| `DriftMonitor.swift` | Observes active focus sessions, user activity, and ARTE oscillations to emit `DriftEvent`s + `MomentumMetrics`. |
| `FlowTriggersService.swift` | Uses drift/idle triggers plus rituals to fire Flow Companion prompts. |
| `MomentumMetrics.swift`, `DriftEvent.swift`, `FocusForecast.swift`, `EnergyWindow.swift` | SwiftData models storing predictive state. |
| `AdaptiveScheduler.swift`, `CalendarSyncService.swift`, `ContextSwitchGuard.swift` | Temporal intelligence extensions that react to forecasts (reflow sessions, block context switches, sync with calendars).

---

## 2. Forecast Generation (`CognitionPredictor`)

1. `start()` checks `UserDefaults.predictiveModeEnabled` (set during app launch). If enabled, it immediately runs a prediction cycle and schedules recurring timers.
2. `runPredictionCycle()` gathers:
   - Ritual completions (`RitualCompletion`)
   - Focus sessions (`FocusSession`)
   - ARTE transitions (`StateTransitionHistory`)
   - Smart nudges delivered (`SmartNudge`)
3. Generates a `FocusForecast` with:
   - `fatigueRisk` (0–1)
   - `focusStability`
   - `energyTrend` (rising/steady/falling)
   - `confidence`
   - Predicted next focus window (`nextFocusWindowStart`)
4. Saves to SwiftData, publishes via `forecastPublisher`, and evaluates historical accuracy with `CognitionAnalytics`.
5. Provides helper methods like `predictEnergyWindows(daysAhead:)` for UI surfaces (Rituals, Dashboard, Focus Mode suggestions).

---

## 3. Predictive Context Fusion

`PredictiveContextManager` subscribes to forecasts, drift events, and ARTE changes. It:

- Tracks a rolling history of `FocusForecast` entries to compute `CognitiveTrajectory` (fatigue slope, momentum slope, ARTE oscillation).
- Builds `ClusterRiskProfile`s by correlating `IntentClusterSummary` output with drift/fatigue histories.
- Determines a `PredictivePosture` (supportive, assertive, calm, strategic, reflective) to influence tone + Flow Companion messaging.
- Surfaces `FusedPredictiveState` to:
  - `AuroraToneKit` / `ToneForecastService` for copy adjustments.
  - `AIPayloadContext` so Aurora can mention predicted windows in reflections.
  - `SmartNudgeService` for anticipatory nudges.
  - Flow/Focus UI elements (e.g., Dashboard predictive card).
- Optionally triggers anticipatory replies when `shouldTriggerAnticipatoryReply` is true (e.g., "I expect your energy to dip around 3pm; shall we prep a ritual?").

---

## 4. Flow & Ritual Hooks

- `DriftMonitor` publishes both drift events and `momentumPublisher` updates. Flow Companion uses these to decide whether to prompt, while `FlowHoldService` can temporarily suppress notifications.
- `FlowCompanionEngine` listens for `FlowTriggersService` signals (drift, evening ritual, idle, manual) and surfaces prompts with ARTE tinting.
- `FocusRitualManager` + `SmartNudgeService` adjust cadence based on predictive posture (e.g., more gentle nudges when fatigue risk is high).

---

## 5. Surfacing Predictions

- **Dashboard → DailyOverviewPanel** uses `CognitionPredictor.shared.fetchLatestForecast` to display the next focus window.
- **Insights → Focus Analytics** charts forecast accuracy, drift frequency, and energy windows.
- **Aurora responses** include predictive snippets when the user asks "When will I be most focused?" or "Am I going to be productive today?"—those commands pull from `PredictiveContextManager.latestFusedState`.
- **Flow Companion** uses `FlowCompanionPersonality` settings to decide how to phrase predictive nudges.

---

## 6. Enabling / Debugging

- Ensure `UserDefaults` flag `predictiveModeEnabled` is set (app launch defaults it to `true`).
- Start services at launch (`FocusOSApp.startRitualSystemsIfNeeded`) to boot `CognitionPredictor`, `DriftMonitor`, `PredictiveContextManager`, `AdaptiveScheduler`, `CalendarSyncService`, and `ContextSwitchGuard`.
- Use the console logs (`os_log` categories `CognitionPredictor`, `PredictiveContextManager`, `DriftMonitor`) to verify signal flow.
- Inspect SwiftData `FocusForecast` records via `FocusOS/Models/FocusForecast.swift` to confirm values look reasonable.

---

## 7. Extending Predictions

- **New signals** – feed additional metrics (heart rate, location, external calendars) into `PredictionContext` and `PredictiveContextManager`.
- **Additional postures** – extend `PredictivePosture` enum + mapping logic to represent new modes (e.g., "regenerative").
- **UX surfacing** – add cards, notifications, or Flow Companion personalities that react to more nuanced predictive states.
- **Accuracy tracking** – extend `CognitionAnalytics` to compute precision/recall or integrate telemetry dashboards.

Predictive cognition is Aurora’s anticipatory brainstem; treat it like infrastructure that other experiences (Flow Companion, Nudges, Tone) can subscribe to.
