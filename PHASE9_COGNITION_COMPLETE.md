# Phase 9 – Predictive Reflection Engine (Implementation Notes)

## Overview

Phase 9 elevates Aurora from reactive insight to anticipatory cognition. We now forecast focus rhythm, detect drift in near real time, and adapt ARTE tones proactively. This document summarizes the implementation, integration touchpoints, and validation for the Predictive Reflection Engine.

## Architecture Flow

```
AnalyticsEngine → RitualAnalytics → CognitionPredictor → DriftMonitor
        ↑                              ↓             ↓
 FocusRitualManager            ToneProfileCache   SmartNudgeService
        ↑                              ↓             ↓
      ARTE EmotionalStatePublisher → PredictiveContextManager → InsightsView
```

Key loop:

1. **CognitionPredictor** runs every 1–4 hours (configurable). It analyses the past 48 hours of ritual completions, focus sessions, smart nudges, and ARTE transitions to create `FocusForecast` records.
2. **DriftMonitor** samples active focus sessions every five minutes and compares live performance against the latest forecast. Deviations beyond the user-selected sensitivity generate `DriftEvent` entries.
3. **PredictiveContextManager** listens to both forecasts and drift events. It adjusts tone weights via `ToneProfileCache`, updates suppression flags, and issues predictive nudges through `SmartNudgeService`.
4. **InsightsView** surfaces the newest forecast via the **Cognitive Forecast** card, including fatigue risk, tone adaptation status, and historical accuracy trends.
5. **SettingsView** exposes a new Predictive Cognition pane for turning the engine on/off, tuning confidence thresholds, selecting forecast intervals, and resetting history.

## Data Model Layer

| Model | Purpose |
| --- | --- |
| `FocusForecast` | Persists predicted cognitive states: fatigue risk, focus stability, energy trend, recommended tone, and optional next focus window intervals. Stores metadata for diagnostics and accuracy auditing. |
| `DriftEvent` | Captures runtime drift detections with severity, expected vs. actual metrics, trigger identifiers, and linkage to focus sessions. |

Both models are registered with the app-wide `ModelContainer` and participate in the shared app group store (`Cloutmate_v3.sqlite`).

## Services

| Service | Responsibilities |
| --- | --- |
| `CognitionPredictor` | Schedules prediction cycles, computes fatigue/focus metrics, writes `FocusForecast`, broadcasts Combine events, and retroactively scores forecast accuracy. |
| `DriftMonitor` | Observes active focus sessions, applies configurable deviation thresholds, writes `DriftEvent`, and notifies listeners via Combine. |
| `CognitionAnalytics` | Aggregates forecast accuracy, drift volume, nudge counts, and tone adaptations for analytics surfaces. |
| `PredictiveContextManager` | Bridges forecasts/drift to tone adaptation, suppression flags, and proactive nudges. |
| `ToneProfileCache` | UserDefaults-backed store for tone weights, confidence thresholds, suppression flags, and adaptation history. |

Additional updates:

- `SmartNudgeService` exposes `deliverPredictiveNudge` for immediate delivery of forecast-driven nudges.
- `AnalyticsEngine` now enriches `AnalyticsSnapshot` with latest forecast metadata, drift counts, accuracy averages, and tone adaptation totals.
- `CloutmateApp` bootstraps the predictor/monitor/context manager when predictive mode is enabled.

## UI Enhancements

- **InsightsView** adds `CognitiveForecastCard` after ARTE status, conditionally rendered when predictive mode is on.
- **SettingsView** gains a "Predictive Cognition" glass card that links to the dedicated settings pane.
- **PredictiveCognitionSettingsView** includes toggles, segmented control, sliders, and reset utilities for the cognition layer.

## Configuration & Persistence

AppStorage keys:

- `predictiveModeEnabled` – master toggle (default `true`).
- `predictionConfidence` – slider (0.5–0.95, default `0.75`) mapped to `ToneProfileCache.confidenceThreshold`.
- `toneAdaptationEnabled` – toggles automatic tone coefficient updates.
- `forecastInterval` – forecast cadence (1/2/4 hours) used by `CognitionPredictor` scheduling.
- `driftDetectionThreshold` – user-facing sensitivity (5–20%) consumed by `DriftMonitor`.

Tone data (`ToneProfileCache`) automatically persists tone weights, suppression flags, last prediction timestamps, and a rolling history of adaptation events (capped at 50 entries).

## Testing & Validation

- **Static validation:** `read_lints` executed on all new/modified files; no linter issues reported.
- **Runtime wiring:** `CloutmateApp` ensures predictor stack starts only when predictive mode is on.
- **Threshold overrides:** Drift monitor respects the configured detection sensitivity; tone adaptation respects the user toggle.
- **Command-line tests:** `swift test` is not available for this Xcode-based project (no `Package.swift`). Manual build via Xcode is required.

Recommended manual validation checklist:

1. Enable predictive cognition in Settings and confirm services start (logs display start messages).
2. Complete focus sessions and rituals to populate forecasts; verify new `FocusForecast` records via SwiftData inspector.
3. Trigger drift by pausing in a focus session; observe `DriftEvent` entries and proactive nudges.
4. Inspect Insights → Cognitive Forecast card for updated risk metrics and accuracy trendlines.
5. Adjust confidence slider/forecast interval; confirm predictor interval reschedules (timer logs).
6. Reset history; ensure forecasts/events clear and tone profile resets.

## Success Metrics Tracking

- Forecast accuracy (rolling 7-day mean) surfaced via `CognitionAnalytics`.
- Drift detection precision approximated through severity + action auditing (`DriftEvent.wasActedOn`).
- Tone adaptation counts derived from `ToneProfileCache` adaptation timestamps.

## Future Enhancements

- Feed `DriftMonitor` with productivity telemetry beyond focus sessions (e.g., calendar vs. actual completions).
- Persist tone adaptation disablement as part of ARTE configuration rather than suppression flags.
- Expose per-forecast accuracy timeline in Insights for deeper transparency.
- Hook `PredictiveContextManager` into ARTE manual overrides for blended auto/manual tone control.


