<!-- e3c16f22-d388-41e9-8f40-cd7669e78e44 8e290f9e-ed9a-4f08-a70a-e656222e727b -->
# Add Tasks Management Tab

## Overview

Create a new "Tasks" tab in the ORGANIZE section that displays all tasks (especially those not attached to projects) with comprehensive filtering, editing, creation, and management capabilities using the existing table view pattern.

## Implementation Details

### 1. Add Tasks Tab to Navigation

**File: `FocusOS/Views/MainWindowView.swift`**

- Add `case tasks = "Tasks"` to the `TabIdentifier` enum (line 18, after `projects`)
- Add icon mapping: `case .tasks: return "checkmark.circle.fill"` (around line 44)
- Add routing in `contentView`: `case .tasks: TasksView()` (around line 127)

### 2. Update Sidebar Navigation

**File: `FocusOS/Views/Sidebar.swift`**

- Add `.tasks` to the ORGANIZE section tabs array (line 64)
- Change from `tabs: [.projects, .areas, .resources, .archives]` to `tabs: [.projects, .areas, .tasks, .resources, .archives]`

### 3. Create TasksView Component

**New File: `FocusOS/Views/Tasks/TasksView.swift`**

Create a comprehensive tasks management view following the `ProjectsView.swift` pattern:

- Search bar for filtering tasks by title/notes
- Filter chips for: All, Status (Todo/In Progress/Done/Cancelled), Priority (Low/Medium/High)
- Area filter chips (similar to ProjectsView)
- Optional filter for "Unattached" (tasks with no projectId)
- Table columns:
- Title (with notes preview)
- Status badge
- Priority badge with color coding
- Due Date
- Project (show project title if attached, "—" otherwise)
- Area (show area title if linked)
- Effort
- Updated timestamp
- Multi-select support with bulk actions:
- Change Status
- Change Priority
- Delete Selected
- Assign to Project
- Context menu on rows: Edit, Duplicate, Delete
- Toolbar with "New Task" button
- Sheet for creating/editing tasks

### 4. Create Supporting Components

**New File: `FocusOS/Views/Tasks/TasksView.swift`** (continued)

Include these sub-components in the same file:

- `TaskStatusBadge`: Status pill (similar to PostStatusBadge)
- `TaskPriorityBadge`: Priority indicator with color coding
- `CreateTaskSheet`: Form for creating new tasks with fields:
- Title (required)
- Notes (multiline)
- Status picker (segmented control)
- Priority picker (segmented control)
- Due date toggle + DatePicker
- Project picker (optional, from all projects)
- Area picker (optional, from all areas)
- Effort picker (optional: small/medium/large)
- `EditTaskSheet`: Similar to CreateTaskSheet but for editing
- `BulkTaskActionSheet`: For bulk status/priority changes

### 5. Use Existing Components

Leverage these existing components already in the codebase:

- `FilterChip` (from ListTableView.swift)
- `TaskRow` (from TodayView.swift) - for potential quick preview
- Table selection and context menu patterns from ProjectsView
- Glass panel styling with `.glassPanel()` modifier

## Key Features

- Filter by status, priority, area, and project attachment
- Standalone tasks (no projectId) highlighted/filterable
- Full CRUD operations (Create, Read, Update, Delete)
- Bulk operations on multiple selected tasks
- Search functionality across title and notes
- Due date management with visual indicators
- Integration with existing Area and Project models
- Consistent glassmorphic UI design

## Files to Create

1. `FocusOS/Views/Tasks/TasksView.swift` - Main tasks view with all components

## Files to Modify

1. `FocusOS/Views/MainWindowView.swift` - Add tasks tab identifier and routing
2. `FocusOS/Views/Sidebar.swift` - Add tasks to ORGANIZE section

### To-dos

- [ ] Add 'tasks' case to TabIdentifier enum in MainWindowView.swift
- [ ] Add tasks tab to ORGANIZE section in Sidebar.swift
- [ ] Create comprehensive TasksView.swift with table, filters, and all CRUD operations
- [ ] Verify tasks tab appears in sidebar and functions correctly with existing data