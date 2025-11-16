## QA Validation Notes – V2 Alignment

- **Sidebar orchestration**
  - Verified `MainWindowView` collapses the primary sidebar whenever the Settings tab is selected and restores the previous state when navigating away.
  - Added guard `onChange` to prevent manual expansion while Settings is visible.

- **Reduce Motion & ARTE awareness**
  - Ensured new scaffolds (`V2GlassContentScaffold`, `TimelineTrackBackground`, `FocusGravityView`) respect `@Environment(\.accessibilityReduceMotion)` by disabling shimmer/animations.
  - Header gradients pull from `AuroraPalette`/`GlassColorSystem` for light and dark modes.

- **Timeline refresh**
  - Updated task, project, and journal timelines to reuse shared backgrounds, axis ticks, and density ribbons—visually richer than baseline dots.
  - Added date-range capsules to confirm accessible metadata.

- **Settings experience**
  - Collapsible settings sidebar groups render inside the new glass controls stack.
  - Deprecated legacy screens (`NotesView`, `ListTableView`, `QuickCaptureView`) flagged with `@available` annotations, reducing accidental regressions.

- **Follow-up suggested checks**
  - Launch app in light/dark mode to confirm gradients blend as expected.
  - Toggle Reduce Motion in Accessibility settings to verify shimmer and pulsing animations disable gracefully.
  - Switch between tabs (especially Settings ↔︎ Tasks) to confirm sidebar state restoration.

- **Calendar V2 sweep**
  - Verified `UnifiedCalendarView` now runs inside `V2GlassContentScaffold` with glass filter panel and sidebar.
  - Confirmed monthly/weekly toggles, entity filters, and search drive the day grid, weekly column, and drawer content.
  - Ensured drawer overlays (day detail, post, task, event) still animate via `GlassMotion` and respect reduce-motion settings.
  - Reviewed upcoming cards and highlights for accurate counts when filters/search narrow the dataset.


