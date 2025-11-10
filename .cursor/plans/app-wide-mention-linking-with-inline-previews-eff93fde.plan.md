<!-- eff93fde-22a7-4ed1-bb43-23deed766e51 bf502199-d24c-4f25-92a8-0c6224dafe4a -->
# Replace All Sheets with Inline Drawers

## Overview

Remove all `.sheet()` presentations for creating and editing items across the app, replacing them with inline drawer overlays that match the `NoteDetailDrawer` pattern. Drawers slide in from the right and hide the list content when open.

## Implementation Steps

### 1. Create Missing Drawer Components

**TaskDetailDrawer** (`Cloutmate/Views/Tasks/Components/TaskDetailDrawer.swift`)

- Match `NoteDetailDrawer` structure and style
- Include Focus Gravity sidebar (for editing existing tasks)
- Fields: title, notes (with MentionTextEditor), status, priority, due date, project/area links
- Use `MentionTextEditor` for notes field
- No Focus Gravity sidebar for new tasks

**ProjectDetailDrawer** (`Cloutmate/Views/Projects/Components/ProjectDetailDrawer.swift`)

- Match `NoteDetailDrawer` structure and style
- Include Focus Gravity sidebar (for editing existing projects)
- Fields: title, goal/description (with MentionTextEditor), status, due date, area link, tags
- Use `MentionTextEditor` for description field
- No Focus Gravity sidebar for new projects

### 2. Update Unified Views to Use Overlays

**UnifiedNotesView** (`Cloutmate/Views/Notes/UnifiedNotesView.swift`)

- Remove `.sheet(isPresented: $showCreateSheet)` for creating
- Replace with `.overlay` pattern matching editing drawer
- Create note inline when `showCreateSheet` becomes true
- Drawer slides in from right, hides list content

**UnifiedJournalView** (`Cloutmate/Views/Journal/UnifiedJournalView.swift`)

- Remove `.sheet(isPresented: $showCreateSheet)` for creating
- Replace with `.overlay` pattern matching editing drawer
- Create journal entry inline when `showCreateSheet` becomes true
- Drawer slides in from right, hides list content

**UnifiedTasksView** (`Cloutmate/Views/Tasks/UnifiedTasksView.swift`)

- Remove `.sheet(isPresented: $showCreateSheet)` for creating
- Remove `.sheet(isPresented: Binding(...))` for editing
- Add `@State private var showDrawer = false`
- Add `.overlay` for both creating and editing using `TaskDetailDrawer`
- When drawer is open, hide list content (use conditional rendering or opacity)
- Drawer slides in from right with `.transition(.move(edge: .trailing))`

**UnifiedProjectsView** (`Cloutmate/Views/Projects/UnifiedProjectsView.swift`)

- Remove `.sheet(isPresented: $showCreateSheet)` for creating
- Remove `.sheet(item: $projectToShow)` for editing
- Add `@State private var showDrawer = false`
- Add `.overlay` for both creating and editing using `ProjectDetailDrawer`
- When drawer is open, hide list content
- Drawer slides in from right with `.transition(.move(edge: .trailing))`

**UnifiedAreasView** (`Cloutmate/Views/Areas/UnifiedAreasView.swift`)

- Remove `.sheet(isPresented: $showCreateSheet)` for creating
- Already uses `.sheet(item: $selectedArea)` for editing - replace with `.overlay`
- Add `@State private var showDrawer = false`
- Update to use `.overlay` pattern for both creating and editing
- When drawer is open, hide list content

**UnifiedResourcesView** (`Cloutmate/Views/Resources/UnifiedResourcesView.swift`)

- Remove `.sheet(isPresented: $showImportSheet)` for importing
- Already uses `.overlay` for editing - keep that pattern
- Add import functionality to overlay or create separate import drawer
- When drawer is open, hide list content

**UnifiedCalendarView** (`Cloutmate/Views/Calendar/UnifiedCalendarView.swift`)

- Remove `.sheet(isPresented: $showingComposer)` for posts
- Remove `.sheet(isPresented: $showingArtifactComposer)` for artifacts
- Remove `.sheet(item: $selectedPost)` for post preview
- Remove `.sheet(item: $selectedArtifact)` for artifact preview
- Remove `.sheet(item: $selectedTask)` for task preview
- Create drawer components for Post, Artifact, and Task previews
- Use `.overlay` pattern for all previews and composers
- When drawer is open, hide calendar content

### 3. Drawer Behavior Requirements

**Layout Pattern** (matching `NoteDetailDrawer`):

- `NavigationStack` wrapper
- `HStack(spacing: 0)` containing:
- Focus Gravity sidebar (4px `RoundedRectangle` with gradient) - only for editing existing items
- Main content `VStack(spacing: 0)`:
- Header `HStack` with title field and close button
- `ScrollView` with content sections
- Frame: `.frame(minWidth: 600, minHeight: 500).frame(idealWidth: 800, idealHeight: 600)`
- Background: `glassColorSystem.backgroundColor()`
- Close button in toolbar: `ToolbarItem(placement: .cancellationAction)`

**When Drawer Opens**:

- List/grid content should be hidden (use `if !showDrawer { ... }` or opacity)
- Drawer slides in from right with `.transition(.move(edge: .trailing))`
- Animation: `GlassMotion.Easing.modalOpen` or `.spring(response: 0.35, dampingFraction: 0.7)`

**State Management**:

- Use `@State private var showDrawer = false` to control visibility
- Use `@State private var selectedItem: ItemType?` for editing
- Use `@State private var createSheetItem: ItemType?` for creating (create inline when drawer opens)
- Update `showDrawer` based on `selectedItem` or `showCreateSheet` state

### 4. Component-Specific Requirements

**TaskDetailDrawer**:

- Include task-specific fields: status picker, priority picker, due date picker
- Use `MentionTextEditor` for notes
- Focus Gravity sidebar only for existing tasks
- Save on close or auto-save on change

**ProjectDetailDrawer**:

- Include project-specific fields: status picker, due date picker, area picker
- Use `MentionTextEditor` for goal/description
- Focus Gravity sidebar only for existing projects
- Save on close or auto-save on change

**AreaDetailDrawer**:

- Already exists - ensure it matches the new pattern
- Update to use overlay instead of sheet

**ResourceDetailDrawer**:

- Already exists - ensure it matches the new pattern
- Already uses overlay - verify it hides list when open

### 5. Cleanup

- Remove all old sheet components that are no longer needed:
- `CreateTaskSheet`, `EditTaskSheet` (replace with `TaskDetailDrawer`)
- `CreateProjectSheet` (replace with `ProjectDetailDrawer`)
- `CreateJournalEntrySheet` (replace with `JournalDetailDrawer`)
- `CreateResourceSheet` (replace with `ResourceDetailDrawer` or inline creation)
- `AreaQuickAddSheet` (replace with `AreaDetailDrawer` for creation)
- Update any references to old sheet components
- Ensure keyboard shortcuts (Escape to close) work with overlays

## Files to Modify

**New Files**:

- `Cloutmate/Views/Tasks/Components/TaskDetailDrawer.swift`
- `Cloutmate/Views/Projects/Components/ProjectDetailDrawer.swift`

**Modified Files**:

- `Cloutmate/Views/Notes/UnifiedNotesView.swift`
- `Cloutmate/Views/Journal/UnifiedJournalView.swift`
- `Cloutmate/Views/Tasks/UnifiedTasksView.swift`
- `Cloutmate/Views/Projects/UnifiedProjectsView.swift`
- `Cloutmate/Views/Areas/UnifiedAreasView.swift`
- `Cloutmate/Views/Resources/UnifiedResourcesView.swift`
- `Cloutmate/Views/Calendar/UnifiedCalendarView.swift`
- `Cloutmate/Views/Areas/Components/AreaDetailDrawer.swift` (update to match pattern)
- `Cloutmate/Views/Resources/Components/ResourceDetailDrawer.swift` (verify pattern)

**Files to Remove** (after migration):

- `Cloutmate/Views/Tasks/TasksView.swift` (if deprecated, check usage)
- Old sheet components if they become unused

## Testing Checklist

- [ ] All drawers slide in from right smoothly
- [ ] List content is hidden when drawer is open
- [ ] Creating new items works via overlay
- [ ] Editing existing items works via overlay
- [ ] Focus Gravity sidebar appears only for editing existing items
- [ ] Close button (X) dismisses drawer
- [ ] Escape key dismisses drawer
- [ ] Drawer content is scrollable
- [ ] MentionTextEditor works in all drawers
- [ ] Auto-save or save-on-close works correctly
- [ ] Empty items are deleted when drawer closes (if applicable)