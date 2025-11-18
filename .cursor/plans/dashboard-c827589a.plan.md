<!-- c827589a-d808-4892-a8de-b4a6e448fdff f499227d-c4f1-4ee5-a119-d6460dcfdc46 -->
# Dashboard: Align With Insights Sections

## Goals

- Add distinct, collapsible sections (Pipeline, Social, Performance, Inbox) with headings matching `InsightsView` style.
- Cards render only within their correct section and only when toggled on in Dashboard Settings; sizes respected per card.
- Keep hero Social Overview centered and lifted.
- Remove legacy groups usage in `DashboardView` and replace with explicit sections.

## Files To Update

- `FocusOS/Views/Dashboard/DashboardView.swift`
- New: `FocusOS/Views/Dashboard/DashboardSectionPanel.swift` (reusable collapsible section)
- `FocusOS/Views/Dashboard/DashboardSettingsView.swift` (only if minor label updates are needed; logic is already OK)

## Implementation Steps

1. Create `DashboardSectionPanel` reusable view

- Props: `title: String`, `icon: String`, `accent: Color`, `isCollapsed: Binding<Bool>`, `@ViewBuilder content: () -> Content`.
- Style to match Insights: glass panel, header HStack with icon + `sectionTitleStyle()`, 20pt inner padding, 16pt spacing. Chevron to collapse.
- Persist collapse state with `@AppStorage("dashboard.section.<key>.collapsed")` keys per section.

2. Update `DashboardView.swift` layout to match Insights

- Header: title + subtitle (like Insights header) and single settings button on right.
- Hero: centered `SocialOverviewCard(size: .large)` with `.heroCard()` and width 420–520.
- Sections grid: two flexible columns with 16pt spacing, 28pt page padding.
- Add `@Query private var dashboardCards: [DashboardCard]` and helpers:
- `isVisible(_:)`, `size(for:fallback:)`, `anyVisible(_:)` (same as in `CustomizableDashboardView`).
- Sections (inside `DashboardSectionPanel`):
- Pipeline: `ProjectsOverviewCard`, `TasksOverviewCard`
- Social: `ContentPerformanceCard`, `PlatformComparisonCard`
- Performance: `CompletionRateCard` (+ friendly streak copy)
- Inbox: `InboxCountCard`, `UpcomingDeadlinesCard`
- Show only cards whose `isVisible` is true; use `size(for:)` to render selected size.
- If a section has no visible cards, render an inline empty state like Insights (calm copy) OR hide entirely (based on answer below).

3. Wire collapsible behavior

- Each section panel header has a chevron button; content is shown/hidden via `isCollapsed`.
- Persist collapsed state per-section via `@AppStorage` so it survives app restarts.

4. Remove legacy group calls

- Replace existing calls to `PipelineGroup`, `SocialGroup`, etc., with new section panels in `DashboardView`.

5. Keep settings behavior

- `DashboardSettingsView` already toggles visibility and size; no logic change needed. Cards now appear under the correct section due to section-specific rendering.

## Notes

- This change does not modify database schema.
- Styling reuses `sectionTitleStyle`, `KosmicPalette`, and glass panels to match Insights.

## Decisions

- Empty sections: Show a calm empty state banner (like Insights banner) instead of hiding the section.
- Collapse persistence: Persist per-section collapse state using `@AppStorage` keys.

## Additional Requirements

- Fully remove old `PipelineGroup`, `SocialGroup`, `PerformanceGroup`, `InboxGroup` usage from `DashboardView.swift` (no comments left behind).
- Ensure the collapsible section visuals match Insights: glass blur (`GlassPanel`), rounded corners, header HStack with icon + `sectionTitleStyle()`, 20pt inner padding, 16pt vertical spacing.