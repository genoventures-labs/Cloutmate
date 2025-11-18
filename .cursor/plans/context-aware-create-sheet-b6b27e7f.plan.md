<!-- b6b27e7f-1e4f-45aa-a307-dfd1a97eaeb3 14e09950-ccf8-452b-8bd4-28f54c3ccdf2 -->
# Context-Aware Create Sheet Implementation

## Overview
The "+" button currently always opens the ComposerWindow (New Post sheet). We need to make it context-aware:
- **In Posts view**: Opens ComposerWindow directly (existing behavior)
- **In all other views**: Opens a multi-purpose sheet with context-appropriate options

## Implementation Steps

### 1. Create Context-Aware Sheet Component
Create a new `ContextualCreateSheet.swift` that displays different options based on the current tab:

**File**: `FocusOS/Views/Components/ContextualCreateSheet.swift`

- Accepts `currentTab: TabIdentifier` as a parameter
- Displays a grid/menu of action buttons based on the tab:
  - **Inbox**: "New Note", "Quick Capture", "Voice Memo"
  - **Notes**: "New Note", "Quick Capture", "Voice Memo"
  - **Tasks**: "Task", "Subtask", "Routine Builder"
  - **Projects**: "New Project"
  - **Posts**: Should not be shown (handled separately)
  - **Other tabs**: Generic options or specific to that tab

### 2. Predictive Smart Defaults System
**File**: `FocusOS/Services/CreateActionUsageTracker.swift` - **NEW FILE**

- Track usage patterns for each create action (Note, Task, Project, etc.) per tab
- Store in SwiftData model `CreateActionUsage`:
  - `tab: TabIdentifier`
  - `actionType: String` (e.g., "New Note", "Task", "Subtask")
  - `timestamp: Date`
  - `weekOfYear: Int` (for "most used last week" queries)
- Query methods:
  - `mostUsedActions(in tab: TabIdentifier, timeRange: TimeRange) -> [String]`
  - `recentlyCreatedType(in tab: TabIdentifier) -> String?`
- Update usage when user selects an action from ContextualCreateSheet

**Integration in ContextualCreateSheet:**
- Query smart defaults on sheet open
- Display top 1-2 most-used actions prominently (e.g., larger button, highlighted)
- Show "Recently created: [Type]" badge on relevant actions
- Visual indicators: "✨ Most used this week" or "🕐 Recently created"

### 3. Aurora Trigger Integration
**File**: `FocusOS/Views/AIAssistant/AIAssistantView.swift`

- Detect "+" key combo (Cmd+N or "+" key) while Aurora chat is active
- When detected, open ContextualCreateSheet inline within Aurora view
- Pass current tab context to sheet
- Sheet should appear as overlay/modal within Aurora conversation area

**File**: `FocusOS/Views/Spotlight/AuroraSpotlightView.swift`

- Add keyboard handler for "+" key combo while spotlight is open
- When triggered, show ContextualCreateSheet overlay
- Sheet should be context-aware based on current tab (not AI Assistant tab)

**Implementation:**
- Add state variable `@State private var showCreateSheet = false` in Aurora views
- Listen for keyboard events: `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`
- Detect "+" key or Cmd+N when Aurora input is focused
- Present ContextualCreateSheet as overlay/sheet

### 4. ARTE Emotional Tinting Integration
**File**: `FocusOS/Views/Components/ContextualCreateSheet.swift`

- Detect creation context and apply appropriate emotional tinting:
  - **Notes/Inbox**: Use `.calm` emotional state
  - **Tasks**: Use `.focused` emotional state
  - **Projects**: Use `.energized` emotional state
  - **Posts**: Use `.energized` emotional state
  - **Default**: Use `.calm` emotional state

**Implementation:**
- Create helper function `emotionalStateForTab(_ tab: TabIdentifier) -> EmotionalState`
- Apply tinting via `GlassColorSystem`:
  ```swift
  let targetState = emotionalStateForTab(currentTab)
  glassColorSystem.updateEmotionalState(targetState, intensity: 0.7)
  ```
- Reset to previous state when sheet dismisses
- Use ARTE's `applyEmotionalModulation` for smooth color transitions

**File**: `FocusOS/Utilities/GlassColorSystem.swift`
- Already has `applyEmotionalModulation` method
- Ensure `emotionalState` property updates trigger UI refreshes
- May need to temporarily override ARTE state when sheet is open

### 5. Modify Notification System
**File**: `FocusOS/Extensions/Notification+Names.swift`

- Add new notification: `.openContextualCreate` that includes the current tab context
- Or modify `.openComposer` to accept optional tab context

**File**: `FocusOS/Views/MainWindowView.swift`

- Modify the notification handler to check if we're in Posts view
- If in Posts → open ComposerWindow directly
- Otherwise → open ContextualCreateSheet with current tab

### 6. Update Sidebar Button
**File**: `FocusOS/Views/Sidebar.swift`

- Modify the "+" button to post a notification that includes the current tab
- Or pass the selectedTab to MainWindowView through ComposerViewModel

### 7. Create Sheet Actions
In `ContextualCreateSheet.swift`, implement action handlers that:
- Open the appropriate existing sheet (CreateNoteSheet, CreateTaskSheet, CreateProjectSheet, ComposerWindow)
- Each action button triggers the corresponding sheet presentation
- Track usage via `CreateActionUsageTracker` when action is selected

### 8. Handle Quick Capture & Voice Memo
For actions like "Quick Capture" and "Voice Memo":
- Check if `QuickCaptureView` or similar components exist
- If not, create simple implementations or link to existing capture functionality
- Voice Memo might link to the voice input feature (already exists in CreateNoteSheet)

### 9. Update ListTableView (Posts View)
**File**: `FocusOS/Views/List/ListTableView.swift`

- Keep the existing "New Post" toolbar button that directly opens ComposerWindow
- This ensures Posts view still has direct access to the composer

## Files to Modify

1. `FocusOS/Views/MainWindowView.swift` - Add state for contextual sheet, modify notification handler
2. `FocusOS/Views/Sidebar.swift` - Update "+" button to pass current tab context
3. `FocusOS/Views/Components/ContextualCreateSheet.swift` - **NEW FILE** - Main context-aware sheet component
4. `FocusOS/Extensions/Notification+Names.swift` - Add notification for contextual create (if needed)
5. `FocusOS/Services/CreateActionUsageTracker.swift` - **NEW FILE** - Track usage patterns for smart defaults
6. `FocusOS/Models/CreateActionUsage.swift` - **NEW FILE** - SwiftData model for usage tracking
7. `FocusOS/Views/AIAssistant/AIAssistantView.swift` - Add Aurora trigger for "+" key combo
8. `FocusOS/Views/Spotlight/AuroraSpotlightView.swift` - Add Aurora Spotlight trigger for "+" key combo
9. `FocusOS/Utilities/GlassColorSystem.swift` - Ensure ARTE integration works for contextual tinting

## Files to Reference (Existing Sheets)

- `FocusOS/Views/Notes/NotesView.swift` - CreateNoteSheet
- `FocusOS/Views/Tasks/TasksView.swift` - CreateTaskSheet  
- `FocusOS/Views/Projects/ProjectsView.swift` - CreateProjectSheet
- `FocusOS/Views/Composer/ComposerWindow.swift` - ComposerWindow
- `FocusOS/Models/EmotionalState.swift` - EmotionalState enum and palettes
- `FocusOS/Services/ReactiveThemeManager.swift` - ARTE theme management

## Design Considerations

- The sheet should be visually consistent with existing UI (glass panel style)
- Use icons and clear labels for each action
- Actions should be grouped logically (e.g., all capture options together)
- Smart defaults should be visually distinct but not overwhelming
- ARTE tinting should be subtle and enhance the creation experience
- Aurora integration should feel seamless and non-intrusive
- Keyboard shortcuts could be added later (e.g., Cmd+N for New Note, Cmd+T for New Task)