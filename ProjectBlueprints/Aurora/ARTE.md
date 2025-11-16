# ARTE (Aurora Reactive Theme Engine)

ARTE is Aurora's emotional nervous system. It ingests analytics signals and transitions the entire macOS interface across five emotional states: Focused, Reflective, Calm, Energized, and Fatigued. This guide explains how the system works and how to extend or debug it.

---

## 1. Core Files

| File | Purpose |
| --- | --- |
| `ReactiveThemeManager.swift` | Central state machine that polls analytics, debounces transitions, and exposes publishers to the UI. |
| `EmotionalStateDetector.swift` | Scores valence, intensity, completion rates, fatigue indicators, and time-of-day windows to identify the current state. |
| `ThemeInterpolator.swift` | Smoothes color/motion transitions over 60–120s so shifts feel organic. |
| `ThemeTelemetryService.swift` | Records polling latency, transition duration, confidence metrics. |
| `ARTEConfiguration.swift` | SwiftData-backed configuration (mode, intensity, locked state) surfaced in Settings. |
| `AuroraToneKit.swift` | Maps emotional states to micro-tones for copy/voice alignment. |
| `SidebarToneSyncService.swift`, `AuroraPalette.swift`, `GlassColorSystem.swift` | Apply ARTE state to UI surfaces (sidebar, glass gradients, background swells). |

---

## 2. Detection Pipeline

1. `ReactiveThemeManager.start()` loads the persisted configuration and spins up a polling timer (10–60s cadence depending on activity).
2. `getCachedSnapshot()` pulls aggregated metrics from `AnalyticsEngine` (task completion, CPS drift, focus stats, memory density, ritual history).
3. `EmotionalStateDetector.detectState(...)` transforms the snapshot into `(state, confidence)` using calibrated weights for completion %, emotional tone, and fatigue.
4. Debounce guard ensures at least two minutes between transitions, unless the user explicitly requests a manual override.
5. `ThemeInterpolator` tweening updates `GlassColorSystem` backgrounds, sidebar accent rails, and other `AuroraPalette` consumers.
6. `ReactiveThemeManager` publishes `currentState` + `confidence` so Insights, ARTE panels, Flow Companion, and Tone services stay synchronized.

---

## 3. Modes

- **Auto**: Detector controls state. Default for new installs.
- **Manual**: Users lock a specific state (e.g., for demos). `ReactiveThemeManager` respects `ARTEConfiguration.lockedState`.
- **Blend**: Auto detection runs, but manual overrides are permitted for a limited duration before auto resumes.
- **Disabled**: `isEnabled = false` halts polling and resets UI to baseline.

Intensity slider (0–1) multiplies visual strength (glow, contrast, motion); the recommended range is 0.4–0.7.

---

## 4. UI Touchpoints

- **Settings → ARTE**: Configures mode, intensity, learning, adaptive timing.
- **Insights → Overview**: Shows current state, recent transitions, and confidence.
- **Dashboard Daily Overview**: `ARTEMoodPulseCard` highlights the active state as part of the morning snapshot.
- **SidebarNavigationViewV2**: Gradient rails + hover glow respond to ARTE state for ambient feedback.
- **Flow Companion + Nudges**: Tone + prompts reference ARTE state for empathy.

---

## 5. Analytics & Learning

- `ThemeTelemetryService` tracks update loop durations and state dwell times. Exposed via debug logs and potential future dashboards.
- `ARTEConfiguration` stores manual overrides so the detector can recalibrate thresholds (e.g., if the user frequently overrides "fatigued" late at night).
- Insights references provide the recommended tabs (Memory Graph, Emotional Heatmap) whenever Reflection intents mention ARTE states.

---

## 6. Extending ARTE

1. **Add a new state** – extend `EmotionalState` enum, detection heuristics, `AuroraToneKit`, `GlassColorSystem`, and UI iconography.
2. **Add sensors** – e.g., integrate macOS Focus status or biometric APIs by feeding new metrics into `EmotionalStateDetector`.
3. **Expose state externally** – publish via `ReactiveThemeManager.emotionalStatePublisher` or add to `AIPayloadContext` if the model needs awareness.
4. **Tune timing** – adjust `currentPollingInterval`, `minTimeBetweenTransitions`, or `snapshotCacheValidity` conservatively to avoid flicker.

---

## 7. Troubleshooting

| Symptom | Checks |
| --- | --- |
| ARTE never changes state | Confirm `ARTEConfiguration.isEnabled`, verify `AIConfig.plist` flag `AuroraReactiveThemeEnabled`, ensure analytics data exists (Focus sessions, tasks). |
| Transitions feel abrupt | Ensure `ThemeInterpolator` is running; verify `pollingTimer` cadence; check `intensity` slider. |
| Tone mismatch between UI and AI responses | Confirm `AuroraToneKit` is referencing `ReactiveThemeManager.currentState` and that `ToneForecastService` isn't overriding due to predictive posture. |
| Performance issues | Inspect telemetry logs; ARTE should stay under ~2% CPU. Lower intensity or increase polling interval if needed.

---

ARTE is intentionally subtle; it should be *felt*, not noticed. Treat it as shared infrastructure for visual ambience, tone selection, and Flow Companion empathy.
