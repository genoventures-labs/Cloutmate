# Dashboard V2 Specification

Dashboard V2 lives in `Cloutmate/Views/Dashboard/` and is rendered by `DashboardViewV2`. It surfaces the day’s momentum through five stacked sections.

---

## 1. Layout Overview

`DashboardViewV2` wraps content in `V2GlassContentScaffold` with a top header (`V2GlassHeaderBar`). The scrollable body contains:

1. `DailyOverviewPanel`
2. `ActiveWorkfeedView`
3. `RitualsSummaryView`
4. `ReflectionFeedView`
5. `DashboardFooterView` (End-of-day summary CTA)

The view can open `AuroraInsightsDrawer` (right overlay) and `DailySummaryView` (sheet) via state toggles.

---

## 2. Panels

### 2.1 Daily Overview Panel (`Components/DailyOverviewPanel.swift`)

- **Grid of three adaptive cards:**
  1. **Focus Gravity Summary Card** – Uses `PriorityEngine` to show top three objects + next predicted focus window from `CognitionPredictor`.
  2. **ARTE Mood Pulse Card** – Displays current ARTE state (icon, label, short copy) using `ReactiveThemeManager`.
  3. **Predictive Cognition Card** – Visualizes `FocusForecast` (fatigue risk, energy trend, next window) with a CTA stub for settings.
- **Interactions:** tapping cards deep-links to Focus Gravity or Insights tabs.

### 2.2 Active Workfeed (`Components/ActiveWorkfeedView.swift`)

- **Ongoing Projects** – Renders `CompactProjectCard` per project (completion %, next task snippet). Projects pulled from `PriorityEngine` + `Project` queries.
- **Active Tasks** – `CompactTaskCard` with inline completion toggles and priority colors.
- **Recent Artifacts** – `CompactArtifactTile` showing latest drafts/published work.
- **Aurora Reflection** – A short textual insight (hardcoded placeholder now) for top-of-mind guidance.

### 2.3 Rituals Summary (`Components/RitualsSummaryView.swift`)

- Highlights ritual streaks, upcoming rituals, and completion stats via `FocusRitualManager`, `RitualAnalytics`, `RitualCompletion` models.
- ARTE-aligned badges clarify morning/evening rituals with tone colors (via `AuroraToneKit`).

### 2.4 Reflection Feed (`Components/ReflectionFeedView.swift`)

- Streams recent `ReflectionNote` entries, Flow Companion interactions, or journaling cards with quick filters (personal, work, insights).
- Each tile links to the Journal/Insights tab for deeper dives.

### 2.5 Footer (`Components/DashboardFooterView.swift`)

- Buttons for "End of Day Summary" (opens `DailySummaryView`) and shortcuts to Rituals or Insights.

---

## 3. Supporting Components

- `DashboardTile` – Glassmorphic container with accent color and padding options.
- `QuickStatsCard`, `WorkflowInsightsCards`, `DashboardSectionPanel` – legacy components still available for future sections.
- `ActivityChart.swift` – Historical completion chart used in older dashboards; can be reintroduced if needed.

---

## 4. Data Dependencies

- **SwiftData queries**: Projects, Tasks, Artifacts, FocusSessions, Rituals, ReflectionNotes.
- **Services**: `PriorityEngine`, `CognitionPredictor`, `ReactiveThemeManager`, `RitualAnalytics`, `FlowCompanionEngine` (for reflection context), `AnalyticsEngine` (if charting is re-enabled).
- **Notifications**: Cards post `.switchTab` notifications to deep-link into Focus Gravity/Insights.

---

## 5. Extending the Dashboard

1. **Add Panels** – Drop additional `GlassCard` or `DashboardTile` sections inside `dashboardContent`. Keep spacing at 24pt.
2. **Dynamic Insights** – Replace placeholder `auroraReflection` text with real `AIFlowCompanion` or `NarrativeEngine` snippets by querying `StoryToken` or `FlowCompanionState`.
3. **Forecast CTA** – Wire `PredictiveCognitionCard` tap gesture to open Predictive settings or Flow Companion view.
4. **Customization** – `CustomizableDashboardView` is stubbed for per-user card selection.

---

## 6. QA Checklist

- Verify ARTE colors update immediately when the state changes.
- Ensure `PriorityEngine` returns at least one item; fallback copy should handle empty states.
- Confirm tapping cards posts the right `.switchTab` notifications.
- Test on both collapsed/expanded sidebar widths to ensure layout adapts.
- Load with no data (fresh workspace) to ensure empty states render gracefully.

Use this specification when tweaking layout, data sources, or adding cards so the dashboard stays coherent with Aurora’s intelligence layer.
