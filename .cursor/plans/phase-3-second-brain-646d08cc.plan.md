<!-- 646d08cc-2b86-4aaf-99b9-40117240a2d7 6505e621-400e-4ec3-8879-250ab82bd3b4 -->
# Convert PARA Views to Table Format

## Overview
Transform Projects, Areas, Resources (Notes), and Inbox views from card-based scrolling layouts to detailed table views similar to the Posts (ListTableView). This provides better information density, sorting/filtering capabilities, and consistent UX across organizational tabs.

## Implementation Strategy

### 1. ProjectsTableView
Convert `Cloutmate/Views/Projects/ProjectsView.swift` to table format.

**Columns:**
- Title (min: 200, ideal: 300) - with goal preview
- Status (min: 100) - Active/Paused/Completed badge
- Due Date (min: 120) - formatted date or "—"
- Area (min: 120) - linked area name or "—"
- Tasks (min: 80) - count of linked tasks
- Updated (min: 120) - relative time

**Filters:**
- All / Active / Paused / Completed
- By Area (dynamic list)
- By Tags (dynamic list)

**Actions:**
- Row context menu: Edit, Duplicate, Archive, Delete
- Multi-select bulk actions: Archive, Delete, Change Status
- Toolbar: New Project button, bulk action menu

**Detail Sheet:**
- Keep existing `ProjectHubSheet` for editing

### 2. AreasTableView
Convert `Cloutmate/Views/Areas/AreasView.swift` to table format.

**Columns:**
- Title (min: 200, ideal: 300) - with notes preview
- Projects (min: 100) - count of linked projects
- Cadence (min: 120) - posting schedule or "—"
- Tags (min: 150) - tag chips
- Updated (min: 120) - relative time

**Filters:**
- Search by title/notes
- By Tags (dynamic list)
- By Cadence (Has Schedule / No Schedule)

**Actions:**
- Row context menu: Edit, Manage Cadence, Archive, Delete
- Multi-select bulk actions: Archive, Delete
- Toolbar: New Area button, bulk action menu

**Detail Sheet:**
- Keep existing `AreaDetailSheet` for editing

### 3. ResourcesTableView (Notes)
Convert `Cloutmate/Views/Resources/ResourcesView.swift` to table format for resource notes.

**Columns:**
- Title (min: 200, ideal: 300) - with markdown preview
- Source (min: 150) - URL or reference
- Project/Area (min: 120) - linked context
- Tags (min: 150) - tag chips
- Highlights (min: 80) - count of highlights
- Updated (min: 120) - relative time

**Filters:**
- Search by title/content
- By Project (dynamic list)
- By Area (dynamic list)
- By Tags (dynamic list)
- Has Highlights / No Highlights

**Actions:**
- Row context menu: Edit, Highlight, Archive, Delete
- Multi-select bulk actions: Archive, Delete, Export
- Toolbar: New Resource button, bulk action menu

**Detail Sheet:**
- Keep `NoteHighlightingView` for editing with highlights

### 4. InboxTableView
Convert `Cloutmate/Views/Inbox/InboxView.swift` to table format.

**Columns:**
- Content (min: 250, ideal: 400) - truncated preview
- Type (min: 100) - Text/File/URL with icon
- Created (min: 120) - relative time
- Actions (min: 180) - Quick convert buttons inline

**Filters:**
- By Type (Text / File / URL)
- By Date (Today / This Week / This Month / All)

**Actions:**
- Row context menu: Convert to Task/Note/Post/Project, Delete
- Quick inline convert buttons in Actions column
- Multi-select bulk actions: Convert All to Notes, Delete
- Toolbar: Bulk triage menu

**Detail Sheet:**
- Keep existing `InboxDetailSheet` for detailed triage

## Shared Components

### FilterChip Component
Reuse from `ListTableView`:
```swift
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
}
```

### Search Bar Pattern
Consistent search UI:
```swift
HStack {
    Image(systemName: "magnifyingglass")
    TextField("Search...", text: $searchText)
}
.padding(8)
.background(Color.secondary.opacity(0.1))
.cornerRadius(8)
```

### Multi-Select Actions Pattern
```swift
if !selectedItems.isEmpty {
    Menu("Actions") {
        Button("Archive", systemImage: "archivebox") { ... }
        Button("Delete", systemImage: "trash") { ... }
    }
}
```

## Files to Modify

1. `Cloutmate/Views/Projects/ProjectsView.swift` → Convert to table
2. `Cloutmate/Views/Areas/AreasView.swift` → Convert to table
3. `Cloutmate/Views/Resources/ResourcesView.swift` → Convert to table
4. `Cloutmate/Views/Inbox/InboxView.swift` → Convert to table

## Design Considerations

- Maintain `.background(Color(.windowBackgroundColor))` for consistency
- Use `Table` with `selection` binding for multi-select
- Column widths: `.width(min:, ideal:, max:)` for optimal display
- Context menus on rows for quick actions
- Filter chips in horizontal scroll for easy filtering
- Keep existing sheets for detailed editing
- Export capability for Resources (CSV format like Posts)

## Benefits

- See more items at once (information density)
- Quick sorting by any column (click header)
- Multi-select for bulk operations
- Consistent filtering across all PARA views
- Better keyboard navigation (arrow keys, cmd+click)
- Professional, power-user friendly interface

### To-dos

- [ ] Convert ProjectsView to table format with columns, filters, and bulk actions
- [ ] Convert AreasView to table format with columns, filters, and bulk actions
- [ ] Convert ResourcesView to table format with columns, filters, and bulk actions
- [ ] Convert InboxView to table format with inline triage actions and bulk operations
- [ ] Test all table views for sorting, filtering, multi-select, and bulk actions