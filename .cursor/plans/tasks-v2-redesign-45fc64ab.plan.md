<!-- 45fc64ab-ed02-408b-b6e2-8252d5ec25e2 f1f5fd6d-31f1-40c9-9dea-d71846e5a3d7 -->
# Tasks V2 Redesign Plan

## Overview

Transform the Tasks view from a table-based checklist into a calm, intent-driven focus orchestration space that visually mirrors the Calendar design. The redesign emphasizes hierarchy through motion, clarity through spacing, and balance through color and typography.

## Phase 1: Header Zone Refresh

### 1.1 Create TasksHeaderView Component

**File:** `Cloutmate/Views/Tasks/Components/TasksHeaderView.swift`

- Left-aligned "Tasks" title with `.system(.title3, design: .rounded)` bold font
- "Focus Summary" subline showing:
  - Today's completion rate (e.g., "3/5 complete")
  - Current streak (e.g., "3-day streak")
  - Styled with `.caption` font and `.kosmicPurple.opacity(0.7)`
- Right-side actions:
  - Filter button: Opens glass dropdown with filters ("Today", "Upcoming", "Completed", "All")
  - Quick Add button: Small "+" button matching Calendar's Quick Actions style
- Visual design:
  - Background: `.glassPanel(tier: .overlay)` with soft blur
  - Header scroll fade: `.move(edge: .top).combined(with: .opacity)` transition
  - Padding: `.horizontal(20)` and `.vertical(16)` matching CalendarHeaderView

### 1.2 Update UnifiedTasksView Structure

**File:** `Cloutmate/Views/Tasks/UnifiedTasksView.swift` (create new)

- Replace existing `TasksView.swift` table-based implementation
- Integrate TasksHeaderView at top
- Add scroll detection for header fade effect
- Use ScrollView with LazyVStack for performance

## Phase 2: Task Card System

### 2.1 Create TaskCardV2 Component

**File:** `Cloutmate/Views/Tasks/Components/TaskCardV2.swift`

**Card Structure:**

- Title with progress pill indicator:
  - In-progress: orange pulse animation
  - Completed: green checkmark with kosmic shimmer
  - Paused: gray static
- Due date badge with color coding:
  - Blue = today
  - Purple = upcoming (within 3 days)
  - Gray = completed/no due date
- Tap to expand: Shows description, subtasks, linked project
- Hover: Reveals quick-action row (complete, edit, archive)

**Visual Design:**

- Base: `.glassPanel(tier: .contentCard, cornerRadius: 12)`
- Accent border: kosmicBlue gradient (animated pulse when due date is today or overdue)
- Shadow: `(0, 2, 4, kosmicPurple.opacity(0.15))`
- Hover effect: `.floatLift()` modifier from GlassMotion
- Minimum height: 56pt for accessibility

**Interactions:**

- Single tap: Toggle expanded state
- Double tap: Quick complete
- Right-click: Context menu (edit, duplicate, archive, delete)

## Phase 3: Sections & Grouping

### 3.1 Implement Sectioned View in UnifiedTasksView

**File:** `Cloutmate/Views/Tasks/UnifiedTasksView.swift`

**Group by Focus Window:**

1. **Today** - Active focus tasks due today
2. **Next Up** - Tasks scheduled within 3 days
3. **Later / Someday** - Backlog area (no due date or far future)
4. **Completed** - Collapsible section (default collapsed)

**Section Headers:**

- Gradient text using kosmicBlue → kosmicPurple
- Fade divider lines below headers
- Collapsible toggle (tap header to expand/collapse)
- Font: `.system(.headline, design: .rounded)`

**Animations:**

- Smooth transitions: `.animation(.spring(duration: 0.35))`
- LazyVStack with spacing: 12pt between cards, 24pt between sections
- Section expand/collapse uses `GlassMotion.Easing.spring`

**Interactions:**

- Drag & drop reorder within same section
- Swipe gestures (macOS trackpad): Left swipe = complete, right swipe = archive
- Keyboard navigation: Arrow keys to navigate, Enter to complete

## Phase 4: Focus Metrics Integration

### 4.1 Create TaskFocusMetrics Component

**File:** `Cloutmate/Views/Tasks/Components/TaskFocusMetrics.swift`

**Visual Indicators:**

- Subtle bar/dot beside each task card
- Color coding:
  - Blue = cognitive focus
  - Purple = creative flow
  - Green = completion energy
- Hover tooltip: "You were in flow 82% of this task's duration"

**Implementation:**

- Stub implementation that can be enhanced later when Focus Gravity integration is available
- Default: Show placeholder metrics based on task duration and status
- Use `TaskFocusMetrics` as a protocol/struct that can be replaced with real data later

**Focus Recap Banner:**

- Show at top when user completes all today's tasks
- Message: "All tasks complete! 🎉 Focus streak: 3 days"
- Auto-dismiss after 3 seconds
- Kosmic gradient background with subtle pulse

## Phase 5: Quick Add & Contextual Create Integration

### 5.1 Update ContextualCreateSheet

**File:** `Cloutmate/Views/Components/ContextualCreateSheet.swift`

- Already has `.tasks` case with actions (Task, Subtask, Routine Builder)
- Ensure actions trigger correct notifications
- Add haptic feedback on action selection

### 5.2 Integrate Quick Add in UnifiedTasksView

**File:** `Cloutmate/Views/Tasks/UnifiedTasksView.swift`

- "+" button in header opens ContextualCreateSheet
- Prefill task creation with "today" date when opened from Tasks view
- On task creation:
  - Haptic pulse feedback
  - Small confetti burst animation (using shimmer effect overlay)
  - Scroll to newly created task

**Confetti Animation:**

- Use shimmer gradient overlay
- Brief kosmic gradient sweep across card
- Duration: 0.6 seconds
- Respects reduce motion settings

## Phase 6: Calm Mode & Accessibility

### 6.1 Keyboard Navigation

**File:** `Cloutmate/Views/Tasks/UnifiedTasksView.swift`

- Implement keyboard handlers:
  - ↑ ↓: Navigate tasks
  - ⌘N: Create new task
  - ⌘↩: Complete selected task
  - ⎋: Clear focus/selection
  - Space: Toggle expanded state
- Track focused task index
- Visual focus indicator (subtle border highlight)

### 6.2 Accessibility Features

- Reduce motion compatibility: Fade-only transitions when `NSAccessibility.isReduceMotionEnabled`
- Large touch targets: Minimum 56pt height for all interactive elements
- High contrast: Gradient-toned outlines on dark/light backgrounds
- VoiceOver labels: Descriptive labels for all interactive elements
- Dynamic Type support: Respects system font size preferences

## Phase 7: Microinteractions & Animation Polish

### 7.1 Card Animations

- Subtle float effect on hover: `.floatLift()` modifier
- Completion animation:
  - Gradient sweep: kosmicBlue → kosmicPurple → kosmicGreen
  - Shimmer overlay using `ShimmerEffect`
  - Scale pulse: 1.0 → 1.05 → 1.0
  - Duration: 0.6 seconds
- Section expand/collapse: Soft spring easing (`GlassMotion.Easing.spring`)

### 7.2 State Transitions

- Task status changes: Smooth color transition
- Due date warnings: Pulse animation when due date is today
- Empty states: Gentle fade-in with message "No tasks in this section"

## Implementation Details

### Key Files to Create:

- `Cloutmate/Views/Tasks/Components/TasksHeaderView.swift`
- `Cloutmate/Views/Tasks/Components/TaskCardV2.swift`
- `Cloutmate/Views/Tasks/Components/TaskFocusMetrics.swift`
- `Cloutmate/Views/Tasks/UnifiedTasksView.swift` (rename/replace existing TasksView.swift)

### Key Files to Modify:

- `Cloutmate/Views/Components/ContextualCreateSheet.swift` - Ensure tasks actions work correctly
- `Cloutmate/Views/Tasks/TasksView.swift` - Replace with UnifiedTasksView or keep as fallback

### Design System Integration:

- Use `GlassPanel` for cards and header
- Use `GlassButton` for action buttons
- Use `GlassMotion.Easing.spring` for all animations
- Use `.kosmicBlue`, `.kosmicPurple`, `.kosmicGreen` for color coding
- Use `FilterChip` component for filter dropdown items

### Task Grouping Logic:

```swift
func groupTasks(_ tasks: [Task]) -> [TaskSection] {
    let today = Calendar.current.startOfDay(for: Date())
    let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: today)!
    
    return [
        TaskSection(title: "Today", tasks: tasks.filter { /* due today */ }),
        TaskSection(title: "Next Up", tasks: tasks.filter { /* within 3 days */ }),
        TaskSection(title: "Later", tasks: tasks.filter { /* no due date or far future */ }),
        TaskSection(title: "Completed", tasks: tasks.filter { $0.status == .done }, collapsed: true)
    ]
}
```

### Focus Metrics Stub:

```swift
struct TaskFocusMetrics {
    let cognitiveFocus: Double // 0.0 - 1.0
    let creativeFlow: Double
    let completionEnergy: Double
    
    static func defaultMetrics(for task: Task) -> TaskFocusMetrics {
        // Stub implementation - replace with real Focus Gravity data later
        return TaskFocusMetrics(cognitiveFocus: 0.5, creativeFlow: 0.3, completionEnergy: 0.7)
    }
}
```

### Completion Animation:

- Use `ShimmerEffect` modifier
- Combine with gradient overlay
- Trigger on task.status change to `.done`
- Respect `NSAccessibility.isReduceMotionEnabled`

## Testing Checklist

- [ ] Header scroll fade works correctly
- [ ] Task cards display all information correctly
- [ ] Card expansion/collapse works smoothly
- [ ] Section grouping logic is accurate
- [ ] Drag & drop reordering works within sections
- [ ] Keyboard navigation is responsive
- [ ] Focus metrics display correctly (even if stub)
- [ ] Quick add opens ContextualCreateSheet
- [ ] Completion animations are smooth
- [ ] Accessibility features work correctly
- [ ] Reduce motion is respected
- [ ] Empty states display correctly
- [ ] Filter dropdown works correctly
- [ ] Focus recap banner appears when all tasks complete