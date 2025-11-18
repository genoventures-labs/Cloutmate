<!-- fb858c13-86ff-4588-9fe6-7a2824629d2d 5698dab4-a5a8-4b3a-b4d6-2b8e5af33575 -->
# Calendar V2 Redesign Plan

## Overview

Transform the Calendar view from a static utility into a calm, expressive moment map that reflects focus, energy, and creative rhythm. The redesign emphasizes Apple's visual language, smooth animations, and Kosmic's accessibility-first design ethos.

## Phase 1: Header Zone Redesign

### 1.1 Redesign Header Layout

**File:** `FocusOS/Views/Calendar/UnifiedCalendarView.swift`

- Move month title to center with smooth fade transitions between months
- Update arrow buttons to use GlassButton with iconOnly style
- Add smooth hover animations (scale + opacity changes)
- Replace current Monthly/Weekly toggle with pill-style switch

**Changes:**

- Create new `CalendarHeaderView` component
- Use centered HStack with Spacers for balanced layout
- Month title: `.system(.title, design: .rounded)` with gradient foreground (kosmicBlue → kosmicPurple)
- Arrow buttons: 32x32 GlassButton with iconOnly style, animated on hover
- Month transitions: `.transition(.opacity.combined(with: .move(edge: .leading)))`

### 1.2 Create Pill-Style Toggle

**File:** `FocusOS/Views/Calendar/Components/CalendarViewToggle.swift` (new)

- Replace segment control with rounded capsule toggle
- Use GlassPanel background with `.overlay` tier
- Selected state: violet accent glow (kosmicPurple.opacity(0.2))
- Unselected state: reduced opacity (0.35)
- Add haptic feedback styling (subtle scale animation on tap)
- Smooth transition between states

**Implementation:**

- Create custom toggle view using HStack with two GlassButton pills
- Use `@Binding var isWeeklyView: Bool`
- Apply GlassMotion spring animations for state changes
- Add subtle shadow for selected state

## Phase 2: Calendar Grid Enhancement

### 2.1 Enhance Day Cell Design

**File:** `FocusOS/Views/Calendar/Components/CalendarDayCellV2.swift` (new)

**Day Cell Features:**

- Minimalist responsive cells (larger tap targets: min 60x60)
- Active days: small accent dot (4pt circle) or ring indicator
- Today's date: glow outline using Kosmic gradient shimmer
- Inactive/empty days: reduced opacity (0.4) instead of gray fills
- Soft hover elevation: scale(1.02) + shadow increase
- Click ripple effect using GlassMotion ripple animation

**Visual Details:**

- Background: transparent with subtle border on hover
- Today indicator: RoundedRectangle stroke with kosmicBlue gradient, 2pt width
- Active indicator: HStack of colored dots (blue for artifacts, purple for artifacts, green for tasks)
- Text: `.system(.body, design: .rounded)` with bold weight for today
- Hover state: `.glassPanel(tier: .contentCard)` background appears

### 2.2 Update Monthly Grid Layout

**File:** `FocusOS/Views/Calendar/UnifiedCalendarView.swift` (UnifiedMonthlyCalendarView)

- Replace `UnifiedCalendarDayCell` with new `CalendarDayCellV2`
- Update grid spacing: 8pt between cells
- Add smooth animations for cell interactions
- Ensure proper accessibility labels and keyboard navigation

## Phase 3: Context Drawer (Daily Snapshot)

### 3.1 Create Daily Snapshot Drawer

**File:** `FocusOS/Views/Calendar/Components/DailySnapshotDrawer.swift` (new)

**Drawer Features:**

- Slide-in right-hand panel (350px width)
- Adaptive blur background using `.ultraThinMaterial` with frosted glass style
- Triggered when selecting a date
- Shows "Daily Snapshot" for selected date

**Content Sections:**

1. **Header**: Date with formatted style (e.g., "Wednesday, November 12")
2. **Tasks Due**: List of tasks with dueDate matching selected date
3. **Projects with Deadlines**: Projects with deadlines in the week containing selected date
4. **Artifacts Captured**: Artifacts created on that day
5. **Empty State**: Calm message when no items exist

**Visual Design:**

- Use GlassPanel with `.overlay` tier
- Section headers: `.headline` font with accent color
- Item cards: GlassCard components matching Dashboard style
- Smooth slide-in animation: `.transition(.move(edge: .trailing))`
- Backdrop: semi-transparent overlay that closes drawer on tap

### 3.2 Integrate Drawer into Calendar

**File:** `FocusOS/Views/Calendar/UnifiedCalendarView.swift`

- Add `@State private var showDrawer = false`
- Add `@State private var drawerDate: Date?`
- Update date selection to open drawer instead of sheet
- Add drawer overlay using ZStack
- Handle drawer dismissal (tap outside or close button)

**Layout:**

- Use GeometryReader to position drawer on right side
- Drawer slides in from right edge
- Main calendar content shifts slightly left when drawer opens (optional)

## Phase 4: Quick Actions Integration

### 4.1 Add Quick Actions Button

**File:** `FocusOS/Views/Calendar/Components/CalendarHeaderView.swift`

- Add small "+" button in top-right corner of header
- Use GlassButton with iconOnly style (28x28)
- Position: trailing edge of header HStack
- Opens Context-Aware Create Sheet with Calendar context

**Integration:**

- Post notification: `.openContextualCreate` with `.calendar` tab identifier
- Update `ContextualCreateSheet` to include Calendar-specific actions:
- "New Task" (preselects selected date)
- "Reflection" (preselects selected date)
- "Journal Entry" (preselects selected date)

### 4.2 Update ContextualCreateSheet for Calendar

**File:** `FocusOS/Views/Components/ContextualCreateSheet.swift`

- Add `.calendar` case to `actionsForTab`
- Calendar actions:
- "New Task" → icon: "checkmark.circle.fill", color: .kosmicBlue
- "Reflection" → icon: "brain.head.profile", color: .kosmicPurple
- "Journal Entry" → icon: "book.fill", color: .kosmicGreen
- Pass selected date context via notification userInfo

## Phase 5: Focus Gravity Integration

### 5.1 Add Focus Gravity Background Gradients

**File:** `FocusOS/Views/Calendar/Components/CalendarDayCellV2.swift`

- Query Focus Gravity metrics for each day
- Render subtle background gradients behind day cells
- Deeper gradient = higher focus gravity score
- Use kosmicPurple → kosmicBlue gradient with opacity based on score

**Implementation:**

- Add `@Query` for Focus Gravity data (if available)
- Calculate daily focus score from CPS metrics
- Apply gradient overlay: `LinearGradient(colors: [kosmicPurple.opacity(score), kosmicBlue.opacity(score * 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)`
- Ensure gradient doesn't interfere with text readability

**Note:** If Focus Gravity metrics aren't available per-day, use weekly average or skip this feature initially.

## Phase 6: Weekly View Updates

### 6.1 Enhance Weekly View Header

**File:** `FocusOS/Views/Calendar/UnifiedCalendarView.swift` (UnifiedWeeklyCalendarView)

- Apply same header design as monthly view
- Use centered week range text (e.g., "Nov 10 - Nov 16, 2025")
- Match arrow button styling
- Update week transitions with smooth fade

### 6.2 Update Weekly Day Columns

**File:** `FocusOS/Views/Calendar/UnifiedCalendarView.swift` (UnifiedDayColumn)

- Apply minimalist design matching new day cells
- Add Daily Snapshot drawer integration
- Update card styling to match Dashboard aesthetic
- Add subtle hover states

## Phase 7: Accessibility & Polish

### 7.1 Keyboard Navigation

**File:** `FocusOS/Views/Calendar/UnifiedCalendarView.swift`

- Arrow keys: Navigate between dates
- Enter: Open drawer for selected date
- Space: Toggle between Monthly/Weekly views
- Escape: Close drawer
- Tab: Navigate between interactive elements

### 7.2 Calm Mode Support

- Respect `AccessibilityGlassManager` settings
- Reduce motion for calm mode users
- High contrast support for day cells
- Large tap targets (min 44x44, ideally 60x60)

### 7.3 Motion & Animation

- Use GlassMotion constants for all animations
- Smooth fade transitions: `.transition(.opacity.combined(with: .move(edge: .leading)))`
- Spring animations for interactive elements
- Respect system reduce motion preferences

## Key Files to Create/Modify

**New Files:**

- `FocusOS/Views/Calendar/Components/CalendarHeaderView.swift`
- `FocusOS/Views/Calendar/Components/CalendarViewToggle.swift`
- `FocusOS/Views/Calendar/Components/CalendarDayCellV2.swift`
- `FocusOS/Views/Calendar/Components/DailySnapshotDrawer.swift`

**Modified Files:**

- `FocusOS/Views/Calendar/UnifiedCalendarView.swift` - Main calendar view
- `FocusOS/Views/Components/ContextualCreateSheet.swift` - Add calendar actions
- `FocusOS/Extensions/Notification+Names.swift` - Add calendar date context notification

## Design Tokens

- Corner radius: 12pt (2xl) for interactive elements
- Accent colors: kosmicBlue, kosmicPurple, kosmicGreen
- Typography: Inter/SF Pro with `.rounded` design
- Shadows: Light drop shadows (radius: 2-4pt)
- Blur: `.ultraThinMaterial` for drawer background
- Animation: GlassMotion.spring for state changes