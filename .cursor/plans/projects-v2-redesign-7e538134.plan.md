<!-- 7e538134-4767-4875-b250-69b69b15d2da 3461095f-9b81-4907-9548-804de5b51f0f -->
# Projects V2 Redesign Plan (with Focus Gravity Integration)

## Overview

Transform the Projects view from a simple table into a multi-mode orchestration hub that balances big-picture calm with moment-level clarity. The redesign introduces List, Board, Timeline, and Gallery views that integrate Focus Gravity visual overlays to show cognitive engagement patterns.

## Phase 1: Unified View Structure & Header

### 1.1 Create UnifiedProjectsView

**File:** `Cloutmate/Views/Projects/UnifiedProjectsView.swift` (new, replaces `ProjectsView.swift`)

**Header Zone:**

- **Title & Count:** "Projects" title with project count badge (e.g., "12 active")
- **Filter Dropdown:** Glass dropdown with filters (Active, Paused, Completed, All)
- **View Selector:** Segmented control or button group for List / Board / Timeline / Gallery
- **Quick Create:** "+" button matching Calendar/Tasks style
- **Visual Design:**
  - Background: `.glassPanel(tier: .overlay)`
  - Smooth fade-in animation when scrolling (`@State private var headerOpacity`)
  - Haptic feedback on view toggle using `NSHapticFeedbackManager`
  - Padding: `.horizontal(20)` and `.vertical(16)`

**State Management:**

- `@State private var selectedViewMode: ProjectViewMode = .list`
- `@State private var selectedFilter: ProjectFilter = .all`
- `@State private var scrollOffset: CGFloat = 0`
- `@Query` for projects, tasks, areas (existing)

### 1.2 Create ProjectViewMode Enum

**File:** `Cloutmate/Views/Projects/ProjectViewMode.swift` (new)

```swift
enum ProjectViewMode: String, CaseIterable {
    case list, board, timeline, gallery
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .board: return "square.grid.2x2"
        case .timeline: return "timeline.selection"
        case .gallery: return "photo.on.rectangle"
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}
```

## Phase 2: Core View Implementations

### 2.1 List View

**File:** `Cloutmate/Views/Projects/Views/ProjectListView.swift` (new)

**Card Structure:**

- **Compact GlassCard** with:
  - Title with status pill badge
  - Progress bar (completion percentage based on linked tasks)
  - Due date badge (color-coded: blue=today, purple=upcoming, gray=none)
  - **Focus Gravity bar** at left edge (4pt width):
    - Represents current attention pull (0–100)
    - Blue gradient = high cognitive engagement
    - Purple gradient = creative flow
    - Green gradient = completion energy
    - Shimmer gradient across border when actively worked on today

**Hover Expansion:**

- Reveals quick actions: Open, Edit, Archive
- Shows description + linked tasks summary
- Smooth `.spring(duration: 0.35, bounce: 0.3)` animation

**Implementation:**

- Use `LazyVStack` with spacing: 12pt
- Each card wrapped in `ProjectListCard` component
- Integrate `FocusGravityOverlay` component for left-edge bar

### 2.2 Board View

**File:** `Cloutmate/Views/Projects/Views/ProjectBoardView.swift` (new)

**Kanban Structure:**

- **Horizontal lanes:** Planning → Building → Reviewing → Complete
- Map `ProjectStatus` to lanes:
  - `active` → Building
  - `paused` → Planning
  - `completed` → Complete
  - Add "Reviewing" as intermediate state

**Lane Headers:**

- Display small circular Focus Gravity markers (average focus intensity)
- Background hue shift based on dominant focus type:
  - Planning = blue tint (cognitive)
  - Building = purple tint (creative)
  - Reviewing = green tint (completion)

**Drag & Drop:**

- Use `DropDelegate` pattern (similar to `PostDropDelegate.swift`)
- Create `ProjectDragInfo` struct conforming to `Transferable`
- Update project status on drop between lanes
- Haptic feedback on drop

**Quick Add:**

- "+" button inside each column
- Opens `CreateProjectSheet` with pre-filled status

### 2.3 Timeline View

**File:** `Cloutmate/Views/Projects/Views/ProjectTimelineView.swift` (new)

**Timeline Structure:**

- Horizontal timeline with gradient baseline (kosmicBlue → kosmicPurple)
- Project milestones displayed as glowing `GlassDots`
- Hover: Shows milestone summary + linked focus graph snippet
- Click: Opens `ProjectSnapshotDrawer`

**Background Wave Animation:**

- Visualizes overall Focus Gravity strength that week
- Strong focus = tighter waveform (higher frequency)
- Low focus = smoother line (lower frequency)
- Use `Path` with `Wave` animator

**Implementation:**

- Use `GeometryReader` for horizontal scrolling
- Calculate milestone positions based on project dates
- Integrate `FocusGravityWaveView` component

### 2.4 Gallery View

**File:** `Cloutmate/Views/Projects/Views/ProjectGalleryView.swift` (new)

**Grid Layout:**

- `LazyVGrid` with 2-3 columns (adaptive)
- Large `GlassCards` (min height: 200pt)

**Card Content:**

- Title with status badge
- Cover image or gradient background (based on project tags/area)
- Due date indicator
- **Hover Overlay:** Shows focus intensity rings (subtle concentric glow)
- **Focus Gravity Heatmap:** Influences gradient tone:
  - Blue = active cognitive work
  - Purple = deep creative flow
  - Green = near completion

**Implementation:**

- Use `ProjectGalleryCard` component
- Integrate `FocusIntensityRings` overlay component

## Phase 3: Focus Gravity Integration

### 3.1 Create Focus Gravity Data Service

**File:** `Cloutmate/Services/ProjectFocusGravityService.swift` (new)

**Purpose:** Calculate and cache focus metrics per project

**Data Structure:**

```swift
struct ProjectFocusMetrics {
    let cognitiveFocus: Double    // 0.0 - 1.0
    let creativeFlow: Double      // 0.0 - 1.0
    let completionEnergy: Double  // 0.0 - 1.0
    let lastActiveAt: Date?
    let avgSessionDuration: TimeInterval
    let weeklyTrend: [(Date, Double)]
}
```

**Calculation Logic:**

- Pull from `PriorityEngine.shared` for project priority scores
- Analyze linked tasks' `TaskFocusMetrics` (if available)
- Calculate based on:
  - Recent activity (last 7 days)
  - Task completion patterns
  - Time spent on project (from linked tasks)
- Cache results per project (5-minute TTL)

**Methods:**

- `func focusMetrics(for project: Project, modelContext: ModelContext) -> ProjectFocusMetrics`
- `func weeklyFocusTrend(for project: Project, days: Int) -> [(Date, Double)]`

### 3.2 Create Focus Gravity Visual Components

**File:** `Cloutmate/Views/Projects/Components/FocusGravityOverlay.swift` (new)

**Components:**

1. **FocusGravityBar:** Left-edge vertical bar for List view

   - Width: 4pt
   - Height: scales with card height
   - Gradient based on dominant focus type
   - Animated shimmer when active

2. **FocusGravityMarker:** Circular marker for Board lane headers

   - Size: 8pt diameter
   - Inner glow based on intensity
   - Color based on focus type

3. **FocusGravityWave:** Background wave for Timeline view

   - Animated `Path` with wave pattern
   - Frequency adjusts based on focus strength
   - Gradient: kosmicBlue → kosmicPurple → kosmicGreen

4. **FocusIntensityRings:** Concentric rings for Gallery hover

   - Appears on hover
   - 3-4 rings with opacity fade
   - Color matches dominant focus type

**Visual Mapping:**

```swift
LinearGradient(
    colors: [
        .kosmicBlue.opacity(cognitiveFocus),
        .kosmicPurple.opacity(creativeFlow),
        .kosmicGreen.opacity(completionEnergy)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

### 3.3 Integrate Focus Metrics in Project Detail View

**File:** `Cloutmate/Views/Projects/ProjectDetailView.swift` (new, replaces `ProjectHubView`)

**Sidebar:**

- Real-time Focus Gravity metrics:
  - Focus Type breakdown (Cognitive %, Creative %, Completion %)
  - Last active time
  - Avg session duration
  - Weekly focus trend (mini line graph using `Charts`)

**Tabs:**

- Overview (goal, context, milestones)
- Tasks (linked tasks table with filters)
- Artifacts (related artifacts, replace Posts section)
- Focus Log (pulls Focus Gravity data per project)

**Focus Ring Indicator:**

- Circular progress ring in header
- Shows dominant focus type
- Animated pulse when actively worked on

## Phase 4: Motion & Interaction Polish

### 4.1 Animation System

**Transitions:**

- All view transitions: `.spring(duration: 0.35, bounce: 0.3)`
- Hover effects: Use `.floatLift()` modifier from `GlassMotion`
- Shadow on hover: `.shadow(radius: 6)`
- Section collapses: `.easeInOut(duration: 0.25)`

**Reduce Motion:**

- Respect `accessibilityReduceMotion` environment value
- Fallback to simple fade for calm mode

### 4.2 Haptic Feedback

**File:** `Cloutmate/Views/Projects/Components/ProjectHaptics.swift` (new utility)

**Haptic Cues:**

- Light tick (`NSHapticFeedbackManager.FeedbackType.selectionChanged`) = select
- Medium (`NSHapticFeedbackManager.FeedbackType.generic`) = drag/drop
- Success pulse (`NSHapticFeedbackManager.FeedbackType.alignment`) = completion

**Integration Points:**

- View mode toggle
- Card selection
- Drag & drop operations
- Project completion

## Phase 5: Accessibility & Integration

### 5.1 Keyboard Navigation

**Keyboard Shortcuts:**

- `←` `→` to switch between views
- `↑` `↓` to navigate items
- `Enter` to open detail
- `⌘N` to create new project
- `⌘F` to focus search

**Implementation:**

- Use `keyboardShortcut` modifier
- Track focus state with `@FocusState`
- Implement `Focusable` protocol for cards

### 5.2 VoiceOver Support

**Labels:**

- Descriptive labels for focus metrics
- Announce focus type changes
- Read focus intensity values

**Dynamic Type:**

- Support `.large`, `.extraLarge`, `.extraExtraLarge`
- Scale card sizes proportionally

**High Contrast:**

- Fallback to kosmicBlue solid outlines
- Increased border width (2pt → 4pt)
- Remove gradients in high contrast mode

### 5.3 Integration Points

**Focus Gravity Sync:**

- Pull from `PriorityEngine.shared.getTopObjects(ofType: "project", ...)`
- Sync every 5 minutes or on view appear
- Cache locally in `ProjectFocusGravityService`

**Calendar Integration:**

- Link project milestones to calendar dates
- Show project deadlines in UnifiedCalendarView
- Allow dragging projects to calendar dates

**Tasks Integration:**

- Show linked tasks count in all views
- Filter projects by task completion status
- Quick jump to project's tasks from detail view

## Phase 6: Migration & Cleanup

### 6.1 Update MainWindowView

**File:** `Cloutmate/Views/MainWindowView.swift`

- Replace `ProjectsView` reference with `UnifiedProjectsView`
- Update navigation/routing if needed

### 6.2 Deprecate Old Components

**File:** `Cloutmate/Views/Projects/ProjectsView.swift`

- Keep as backup or mark for deletion
- Move reusable components to `Components/` folder:
  - `ProjectCard` → `ProjectCardV2` (if needed)
  - `ProjectStatusBadge` (keep, reuse)
  - `CreateProjectSheet` (keep, reuse)

### 6.3 Update Project Model Extensions

**File:** `Cloutmate/Models/Project+Extensions.swift` (new, if needed)

- Add computed properties for Focus Gravity integration:
  - `var focusMetrics: ProjectFocusMetrics?`
  - `var linkedTasksCount: Int`
  - `var completionPercentage: Double`

## Key Files to Create

**Views:**

- `Cloutmate/Views/Projects/UnifiedProjectsView.swift`
- `Cloutmate/Views/Projects/Views/ProjectListView.swift`
- `Cloutmate/Views/Projects/Views/ProjectBoardView.swift`
- `Cloutmate/Views/Projects/Views/ProjectTimelineView.swift`
- `Cloutmate/Views/Projects/Views/ProjectGalleryView.swift`
- `Cloutmate/Views/Projects/ProjectDetailView.swift`

**Components:**

- `Cloutmate/Views/Projects/Components/FocusGravityOverlay.swift`
- `Cloutmate/Views/Projects/Components/ProjectListCard.swift`
- `Cloutmate/Views/Projects/Components/ProjectGalleryCard.swift`
- `Cloutmate/Views/Projects/Components/ProjectHaptics.swift`

**Services:**

- `Cloutmate/Services/ProjectFocusGravityService.swift`

**Models:**

- `Cloutmate/Views/Projects/ProjectViewMode.swift`

## Key Files to Modify

- `Cloutmate/Views/MainWindowView.swift` (update routing)
- `Cloutmate/Views/Projects/ProjectsView.swift` (deprecate or refactor)

## Dependencies

- Existing `PriorityEngine` from CPS system
- `GlassCard`, `GlassPanel` components
- `TaskFocusMetrics` structure (may need enhancement for project-level)
- `Charts` framework for trend visualization
- Drag & drop patterns from `PostDropDelegate.swift`

## Testing Considerations

1. **Focus Gravity Calculations:**

   - Test with projects that have no linked tasks
   - Test with projects that have many tasks
   - Verify cache expiration works correctly

2. **View Transitions:**

   - Test switching between all 4 view modes
   - Verify state preservation (selected filter, scroll position)

3. **Drag & Drop:**

   - Test dragging between all board lanes
   - Verify haptic feedback triggers
   - Test with multiple projects simultaneously

4. **Accessibility:**

   - Test with VoiceOver enabled
   - Test keyboard navigation in all views
   - Test high contrast mode

5. **Performance:**

   - Test with 50+ projects
   - Verify LazyVStack/LazyVGrid performance
   - Monitor Focus Gravity calculation overhead

### To-dos

- [ ] Create UnifiedProjectsView with header zone (title, filters, view selector, quick create button) and scroll detection for fade animation
- [ ] Create ProjectViewMode enum and implement List, Board, Timeline, and Gallery view components
- [ ] Create ProjectFocusGravityService to calculate and cache focus metrics (cognitive, creative, completion) per project
- [ ] Create FocusGravityOverlay component with FocusGravityBar, FocusGravityMarker, FocusGravityWave, and FocusIntensityRings
- [ ] Implement ProjectListView with compact GlassCards, Focus Gravity bar at left edge, hover expansion, and shimmer effects
- [ ] Implement ProjectBoardView with kanban lanes (Planning → Building → Reviewing → Complete), drag & drop, and Focus Gravity lane markers
- [ ] Implement ProjectTimelineView with horizontal timeline, milestone GlassDots, hover details, and animated background wave
- [ ] Implement ProjectGalleryView with grid layout, large GlassCards, cover images/gradients, and Focus Intensity rings on hover
- [ ] Create ProjectDetailView with tabs (Overview, Tasks, Artifacts, Focus Log) and Focus Gravity sidebar metrics
- [ ] Add spring animations, hover effects, haptic feedback (light tick, medium drag, success pulse), and reduce motion support
- [ ] Add keyboard navigation (arrow keys, Enter), VoiceOver labels, Dynamic Type support, and high contrast fallback
- [ ] Integrate with Calendar for milestones and with Tasks for linked task counts and filtering
- [ ] Update MainWindowView to use UnifiedProjectsView and deprecate old ProjectsView