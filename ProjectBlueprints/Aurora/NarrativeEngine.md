# Narrative Engine (Phase 5) Guide

Aurora’s Narrative Engine turns productivity metrics and conceptual themes into weekly story artifacts. It keeps users anchored to the meaning behind their work rather than raw checklists.

---

## 1. Purpose

- Generate weekly narrative summaries (`StoryToken` records) that combine focus stats, CPS deltas, Memory Graph themes, emotional trajectories, and key insights.
- Feed Insight dashboards (Live Themes, Connections) and Aurora’s reflection responses ("Week Overview", "Detected Patterns").
- Provide export-ready Markdown for newsletters, reports, or journaling artifacts.

---

## 2. Core Files

| File | Role |
| --- | --- |
| `NarrativeEngine.swift` | Orchestrates data gathering and Markdown generation for weekly summaries. |
| `ConceptTracker.swift` | Tracks concept mentions and determines whether concepts are "alive" (>30% relevance). |
| `StoryToken.swift` | SwiftData model storing title, markdown, summary, theme list, emotional tone, metrics. |
| `StoryArc.swift` / `ArcDetectionService.swift` | Detect medium-term arcs across StoryTokens. |
| `StoryTokenExportService.swift` | Handles exporting tokens to Markdown/PDF/email flows. |
| `ThemeExtractionPipeline.swift` | Provides Memory Graph clusters referenced in narratives.

---

## 3. Generation Flow

1. `NarrativeEngine.generateWeeklySummary(endDate:)` is typically invoked from rituals or Insights.
2. It calculates a 7-day range and queries:
   - Concepts & mentions via `ConceptTracker`.
   - Focus statistics via `FocusSessionService.getSessionStats`.
   - CPS deltas via `PriorityEngine`.
   - Emotional metrics via analytics snapshots.
3. Sections assembled include:
   - Overview (alive concepts, focus session count/duration)
   - Live Themes table (top 5)
   - Priority Trends (rising/falling objects)
   - Focus Performance metrics
   - Emotional Trajectory summary
   - Key Insight sentence tying everything together
4. A `StoryToken` is saved with metrics (focus hours, completion rate, alive concept count) and top concepts for future comparisons.
5. Aurora references `StoryToken` data when answering "Summarize my week" or "What themes dominated recently?".

---

## 4. Presentation

- **Artifacts tab** – Story tokens appear as narrative artifacts with Markdown preview/editing.
- **Insights → Connections** – Surfaces current story arcs, alive concepts, and emotional patterns.
- **Exports** – `StoryTokenExportService` can push Markdown to clipboard or other apps once wired up.

---

## 5. Extending the Narrative Engine

- **New sections** – Update `buildNarrative` to append metrics (e.g., publishing cadence, ritual completion streaks).
- **Custom formats** – Add new `storyType` values (monthly, quarterly) and adjust copy accordingly.
- **Automations** – Tie `NarrativeEngine` into `SmartAutomationEngine` to auto-generate tokens when enough data accrues.
- **AI Collaboration** – Pipe raw sections through Aurora for tone polishing or summarization, but keep deterministic metrics on the Swift side for trust.

---

## 6. Troubleshooting

| Issue | Fix |
| --- | --- |
| Empty narratives | Ensure focus sessions, tasks, or reflections exist during the selected week; check `ConceptTracker` for alive concepts. |
| Missing StoryTokens | Verify the model is added to the schema in `FocusOSApp.sharedModelContainer`. |
| Export failures | Confirm `StoryTokenExportService` has file permissions and that Markdown is well-formed.

Narratives turn analytics into meaning—keep the storytelling voice consistent with FocusOS’s supportive, insightful tone.
