<!-- 2b1969c9-4e15-4f0e-be2d-183c94e9b5e3 978bc221-19bf-46e4-90f2-93a338265788 -->
# Fix Theme and Layout Issues

## Problem Analysis

The new PARA tabs (Dashboard, Today, Inbox, Projects, Areas, Resources) have several issues:

1. White backgrounds not respecting system theme
2. Using `NavigationSplitView` inside tabs creates nested sidebars (unprofessional)
3. Dashboard Settings sheet is too small (500x400)
4. Areas cards don't navigate to area details
5. Missing AI info in AI Assistant
6. Projects should be list-style, not split-view

## Solution

### 1. Fix White Backgrounds (Issues #1, #2, #5)

**Root cause**: Views are missing `.background(Color.clear)` and not using glass panels consistently.

**Files to modify**:

`Cloutmate/Views/Dashboard/CustomizableDashboardView.swift`:

- Add `.background(Color.clear)` to `ScrollView`
- Ensure cards use `.glassPanel()` consistently

`Cloutmate/Views/Today/TodayView.swift`:

- Add `.background(Color.clear)` to `ScrollView`
- Already has glass panels - verify rendering

`Cloutmate/Views/Inbox/InboxView.swift`:

- Replace `HStack` with single-column layout
- Remove `NavigationSplitView` usage
- Use `.glassPanel()` for content areas

`Cloutmate/Views/Projects/ProjectsView.swift`:

- Remove `NavigationSplitView`
- Use list with expandable rows or sheet modals for project details
- Apply glass styling

`Cloutmate/Views/Areas/AreasView.swift`:

- Add `.background(Color.clear)` to `ScrollView`
- Verify glass panels

`Cloutmate/Views/Resources/ResourcesView.swift`:

- Remove `NavigationSplitView`
- Use modal/sheet for note editing instead

### 2. Remove NavigationSplitView Sidebars (Issue #3)

**Affected files**:

`Cloutmate/Views/Inbox/InboxView.swift`:

- Replace split view with:
  - Vertical list of inbox items with glass cards
  - Tap to show detail in sheet/modal
  - Convert button in detail sheet

`Cloutmate/Views/Projects/ProjectsView.swift`:

- Replace split view with:
  - Grid/list of project cards
  - Tap card to navigate to `ProjectHubView` in sheet or push

`Cloutmate/Views/Resources/ResourcesView.swift`:

- Replace split view with:
  - List of note cards with search
  - Tap to open `NoteEditorView` in sheet

### 3. Fix Dashboard Settings Sheet (Issue #4)

`Cloutmate/Views/Dashboard/DashboardSettingsView.swift`:

- Change `.frame(width: 500, height: 400)` to `.frame(minWidth: 600, minHeight: 500)`
- Add `.presentationDetents([.large])` for better sizing

### 4. Add Area Detail View (Issue #6)

Create `Cloutmate/Views/Areas/AreaDetailView.swift`:

```swift
struct AreaDetailView: View {
    let area: Area
    @Query private var allTasks: [Task]
    @Query private var allNotes: [Note]
    @Query private var allProjects: [Project]
    
    var areaTasks: [Task] {
        allTasks.filter { $0.areaId == area.id }
    }
    
    var areaNotes: [Note] {
        allNotes.filter { $0.areaId == area.id }
    }
    
    var areaProjects: [Project] {
        allProjects.filter { $0.areaId == area.id }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Area header with title, notes, cadence
                AreaHeaderSection(area: area)
                
                // Projects in this area
                if !areaProjects.isEmpty {
                    AreaProjectsSection(projects: areaProjects)
                }
                
                // Tasks in this area
                if !areaTasks.isEmpty {
                    AreaTasksSection(tasks: areaTasks)
                }
                
                // Notes in this area
                if !areaNotes.isEmpty {
                    AreaNotesSection(notes: areaNotes)
                }
            }
            .padding()
        }
        .background(Color.clear)
        .navigationTitle(area.title)
    }
}
```

Update `Cloutmate/Views/Areas/AreasView.swift`:

- Make `AreaCard` tappable with `NavigationLink` or `.sheet()`
- Navigate to `AreaDetailView(area: area)`

### 5. Add AI Info Icon (Issue #7)

`Cloutmate/Views/AIAssistant/AIAssistantView.swift`:

- Add toolbar button with info icon
- Show alert/popover explaining:
  - Uses Google Gemini API
  - Context-aware of tasks, projects, posts, notes
  - Can extract tasks, suggest projects
  - Privacy: API key stored securely
```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button(action: { showAIInfo = true }) {
            Image(systemName: "info.circle")
        }
    }
}
.alert("AI Assistant", isPresented: $showAIInfo) {
    Button("OK") { }
} message: {
    Text("Powered by Google Gemini, Cloutmate's AI is context-aware of your tasks, projects, posts, and notes. It can help extract tasks, suggest projects, and answer questions about your work. Your API key is stored securely in Keychain.")
}
```


### 6. Convert Projects to List Style (Issue #8)

`Cloutmate/Views/Projects/ProjectsView.swift`:

- Remove `NavigationSplitView`
- Create scrollable list of project cards
- Each card shows: title, goal, status, task count
- Tap opens `ProjectHubView` in sheet
- Add actions menu per project (edit, archive, delete)

## Implementation Order

1. Fix Dashboard/Today/Areas backgrounds (simple `.background(Color.clear)` additions)
2. Remove NavigationSplitViews from Inbox, Projects, Resources
3. Expand Dashboard Settings sheet size
4. Create and wire up AreaDetailView
5. Add AI info icon and alert
6. Convert Projects to list-style cards

## Files to Create

- `Cloutmate/Views/Areas/AreaDetailView.swift`

## Files to Modify

- `Cloutmate/Views/Dashboard/CustomizableDashboardView.swift`
- `Cloutmate/Views/Dashboard/DashboardSettingsView.swift`
- `Cloutmate/Views/Today/TodayView.swift`
- `Cloutmate/Views/Inbox/InboxView.swift`
- `Cloutmate/Views/Projects/ProjectsView.swift`
- `Cloutmate/Views/Areas/AreasView.swift`
- `Cloutmate/Views/Resources/ResourcesView.swift`
- `Cloutmate/Views/AIAssistant/AIAssistantView.swift`

### To-dos

- [ ] Add .background(Color.clear) to all ScrollViews in Dashboard, Today, Areas views
- [ ] Remove NavigationSplitView from InboxView, replace with vertical list + detail sheet
- [ ] Remove NavigationSplitView from ProjectsView, convert to list-style with cards
- [ ] Remove NavigationSplitView from ResourcesView, replace with list + sheet modal
- [ ] Increase DashboardSettingsView sheet size from 500x400 to minWidth: 600, minHeight: 500
- [ ] Create AreaDetailView showing projects, tasks, and notes for selected area
- [ ] Make AreaCard tappable with sheet/NavigationLink to AreaDetailView
- [ ] Add info icon to AI Assistant toolbar with alert explaining Gemini integration