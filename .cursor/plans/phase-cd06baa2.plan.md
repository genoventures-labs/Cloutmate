<!-- cd06baa2-41e8-4a55-bc2d-c9645cbeb235 51d7c4c3-7ca1-4a5a-a80c-b20b40410ce7 -->
# Phase 1 UX Polish Plan

## New Item Flow Hardening

- Refactor creation triggers in [Cloutmate/Views/Tasks/UnifiedTasksView.swift](Cloutmate/Views/Tasks/UnifiedTasksView.swift), [Cloutmate/Views/Projects/UnifiedProjectsView.swift](Cloutmate/Views/Projects/UnifiedProjectsView.swift), [Cloutmate/Views/Journal/UnifiedJournalView.swift](Cloutmate/Views/Journal/UnifiedJournalView.swift), and [Cloutmate/Views/Artifacts/ArtifactsViewV2.swift](Cloutmate/Views/Artifacts/ArtifactsViewV2.swift) to open drawers using in-memory drafts instead of immediately inserting models.
- Update drawers such as [Cloutmate/Views/Tasks/Components/TaskDetailDrawer.swift](Cloutmate/Views/Tasks/Components/TaskDetailDrawer.swift), [Cloutmate/Views/Projects/Components/ProjectDetailDrawer.swift](Cloutmate/Views/Projects/Components/ProjectDetailDrawer.swift), [Cloutmate/Views/Journal/Components/JournalDetailDrawer.swift](Cloutmate/Views/Journal/Components/JournalDetailDrawer.swift), and [Cloutmate/Views/Artifacts/ArtifactQuickAddDrawer.swift](Cloutmate/Views/Artifacts/ArtifactQuickAddDrawer.swift) to expose explicit Save / Cancel flows that persist only confirmed entries.

## Timeline Alignment & Interaction

- Normalize layout constants and alignment math in [Cloutmate/Views/Tasks/Views/TaskTimelineView.swift](Cloutmate/Views/Tasks/Views/TaskTimelineView.swift), [Cloutmate/Views/Projects/Views/ProjectTimelineView.swift](Cloutmate/Views/Projects/Views/ProjectTimelineView.swift), and [Cloutmate/Views/Journal/Components/JournalTimelineView.swift](Cloutmate/Views/Journal/Components/JournalTimelineView.swift) so nodes share a consistent baseline, hover state, and scaling behavior.
- Audit scroll/zoom gestures across these views to ensure consistent track padding and smooth detail reveal animations.

## Journal Drawer Modernization

- Replace the legacy centered presentation with a trailing drawer in [Cloutmate/Views/Journal/UnifiedJournalView.swift](Cloutmate/Views/Journal/UnifiedJournalView.swift) and align styling in [Cloutmate/Views/Journal/Components/JournalDetailDrawer.swift](Cloutmate/Views/Journal/Components/JournalDetailDrawer.swift) with the Focus Mode drawer tokens (spacing, rounded corners, materials).
- Confirm close controls and Escape shortcuts dismiss cleanly across light/dark themes.

## Artifact Drawer Tab Styling

- Refresh the “Add New” experience by updating tab styling and transitions in [Cloutmate/Views/Artifacts/ArtifactQuickAddDrawer.swift](Cloutmate/Views/Artifacts/ArtifactQuickAddDrawer.swift) (and related drawer components) to match current drawer typography, accent colors, and underline animations.
- Ensure drawer content alignment matches other tabs for cohesive spacing.

## AI Assistant Responsiveness & Actions

- Adjust layout constraints in [Cloutmate/Views/AIAssistant/UnifiedAIAssistantView.swift](Cloutmate/Views/AIAssistant/UnifiedAIAssistantView.swift) and toolbar/composer components to scale with window size while preserving minimum padding.
- Fix input behaviors in [Cloutmate/Views/Components/MentionInputField.swift](Cloutmate/Views/Components/MentionInputField.swift) and [Cloutmate/Views/AIAssistant/AIMessageComposer.swift](Cloutmate/Views/AIAssistant/AIMessageComposer.swift) so Enter sends, Shift+Enter inserts a newline, the cursor stays stable, and drafts persist until send succeeds.
- Add the Resend affordance to assistant bubbles via [Cloutmate/Views/AIAssistant/Components/MessageBubble.swift](Cloutmate/Views/AIAssistant/Components/MessageBubble.swift) and wire it through [Cloutmate/ViewModels/AIAssistantViewModel.swift](Cloutmate/ViewModels/AIAssistantViewModel.swift) to reuse the prior payload without resetting session state.
- Tune message list anchoring and theme tokens (blur, shadows, typography) for light/dark polish and smooth arrival animations.

### To-dos

- [ ] Implement draft-based creation flow for tasks, projects, journals, and artifacts
- [ ] Align timeline node geometry, hover states, and scroll behavior across task/project/journal views
- [ ] Modernize journal drawer presentation and ensure consistent theming/controls
- [ ] Restyle artifact drawer tabs and spacing to match current drawer design language
- [ ] Improve AI Assistant responsiveness, composer behavior, and add resend action