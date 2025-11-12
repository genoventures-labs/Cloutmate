<!-- 363e902c-0f97-4d0b-bc6d-5a4350ebbb72 0c032062-49c9-4d86-870f-6cdb2554ea13 -->
# Timeline & Drawer V2 Overhaul

## Phase 1 – Baseline Discovery & Design Sync

- Audit current timeline components (`Cloutmate/Views/**/Timeline*`, `Cloutmate/Views/Components/TimelineNode*`) to document layout misalignment and hover behavior; cross-reference V2 specs in `.cursor/plans/*-v2.plan.md` and drawer structure guidance at `Cloutmate/Views/Notes`.
- Inventory all drawers/sheets across tabs (Tasks, Calendar, Insights, Projects, Journal, Artifact, Areas, Focus, Archives) noting deviations from `NotesHeaderView`/`NoteDetailDrawer` patterns.

## Phase 2 – Timeline V2 Implementation

- Update shared timeline view models and rendering to align nodes, add multi-node hover interactivity, and adopt Apple-like motion (likely in `Cloutmate/Views/Components/TimelineView.swift` and related styles). Ensure all timeline consumers import the enhanced component.
- Standardize node template (radius, gradient, labels) via shared modifiers and ensure focus/hover states expose underlying data tooltips and scroll syncing.

## Phase 3 – Context-Linking Search Enhancements

- Extend search provider (e.g., `Cloutmate/Services/Search/ContextLinkingService.swift`) to parse `@task`, `@project`, `@area`, etc., returning filtered datasets when only the prefix is present.
- Update UI components (likely `ContextualCreateSheet`, linking drawers) to show tab-specific results and default tab contents when no trailing text.

## Phase 4 – Tasks Tab Kanban Interactivity

- Reuse Projects board logic (`Cloutmate/Views/Projects/Components/ProjectBoardView.swift`) to make Tasks board draggable, status-aware, and real-time.
- Ensure task card actions (open drawer, edit, context menus) follow V2 drawer spec and sync with timers/automation hooks.

## Phase 5 – Calendar Recurrence & Drawer Redesign

- Add recurrence data to calendar models (`CloutmateShared/.../Models/Event.swift`) with enums for daily/weekly/bi-weekly/monthly/yearly.
- Update scheduling services and Aurora automation API to handle recurrence presets and delegate creation to Aurora when requested.
- Replace “Add Event” sheet with V2 drawer (`Cloutmate/Views/Calendar/Components/EventDrawer.swift`) including recurrence controls.

## Phase 6 – Insights Tab Polish

- Fix toolbar icon visibility and ensure export/share workflow hits all exporters (`Cloutmate/Services/Insights/ExportService.swift`).
- Validate exports for each dataset and update error handling UI.

## Phase 7 – Projects Tab Navigation & Drawer Behavior

- Restore double-click NAV to legacy detail view (charts/tasks) while keeping new UI consistent.
- Gate edit drawer display behind explicit edit action; ensure drawer layout matches V2 spec.

## Phase 8 – Journal & Artifact Drawer Modernization

- Replace legacy add/edit sheets with V2 drawers (`Cloutmate/Views/Journal/Components/JournalEntryDrawer.swift`, `Cloutmate/Views/Artifacts/ArtifactDrawer.swift`) using glass styling and consistent headers/tabs.
- Refine Artifact drawer tab styling/alignment per V2 tokens.

## Phase 9 – Areas Tab Review Workflow

- Create dedicated review drawer to inspect items listed in review section; ensure “Needs Review” filter surfaces applicable entities.
- Fix linking buttons to navigate to selected entities instead of closing, and enable linked entity tapping to open respective detail views.

## Phase 10 – Focus Mode Stats & Streaks

- Implement V2 designs for Stats/Streaks tabs, integrating existing analytics services and ensuring animations follow V2 motion guidelines.

## Phase 11 – Archives Tab Fixes

- Correct stats sheet alignment; audit auto-layout in archive detail drawers.
- Verify all filters (including ARTE Tone) execute expected queries; make Review Summary cards fully interactive across filters.

## Phase 12 – Global Drawer Standardization

- Apply `Notes V2` drawer spec (`Cloutmate/Views/Notes/Components/NoteDetailDrawer.swift`) across all editing drawers, extracting shared components where helpful.
- Confirm accessibility (VoiceOver, reduce motion) and haptic cues align with V2 defaults.

## Validation

- Regression test interactions in each tab, including timeline hover, linking search, drawers, exports, recurrence, filters.
- Update automated/UI tests where coverage exists; document manual QA checklist per tab.

### To-dos

- [ ] Assess existing timeline components and drawer deviations versus V2 specs
- [ ] Realign timeline nodes and apply V2 interactivity across consumers
- [ ] Enhance context linking search to support @ prefixes
- [ ] Make Tasks board fully interactive using Projects board patterns
- [ ] Add recurrence logic and redesign event drawer with Aurora support
- [ ] Polish Insights toolbar and ensure export reliability
- [ ] Restore Projects double-click view and gate edit drawer
- [ ] Replace Journal and Artifact drawers with V2 implementations
- [ ] Build Areas review drawer and fix linking/navigation
- [ ] Implement Focus Mode Stats and Streak tabs per V2
- [ ] Fix Archives stats alignment and filter functionality
- [ ] Standardize all drawers to Notes V2 spec