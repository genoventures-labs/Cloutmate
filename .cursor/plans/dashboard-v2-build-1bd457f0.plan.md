<!-- 1bd457f0-bf26-4b2a-af3b-57e89dc05a8c 129b5d59-79d5-45a3-b8c8-4c69e866d60e -->
# Dashboard V2 Build Plan

## Overview

Create `DashboardViewV2` as a serene, ambient intelligence dashboard that surfaces the user's day at a glance. The design emphasizes calm awareness over active interaction, using ARTE emotional states, Focus Gravity priorities, Predictive Cognition forecasts, and Aurora's insights to create a cohesive overview.

## Architecture

**Main View:** `FocusOS/Views/Dashboard/DashboardViewV2.swift`

- Scrollable container with unified header (semi-persistent on scroll)
- Sections: Daily Overview → Active Workfeed → Rituals & Streaks → Journal & Reflection → Footer
- Aurora Insights Drawer (side panel, swipe/button activated)

**Component Files:**

- `DashboardHeaderView.swift` - Unified header with title, subline, quick actions, ARTE status light
- `DailyOverviewPanel.swift` - 3-column adaptive cards (Focus Gravity Summary, ARTE Mood Pulse, Predictive Cognition Forecast)
- `ActiveWorkfeedView.swift` - Ongoing Projects, Active Tasks, Recent Artifacts
- `RitualsSummaryView.swift` - Morning/Evening ritual completion, streak tracker, next nudge forecast
- `ReflectionFeedView.swift` - Recent Journal entries and AI reflections with tone arcs
- `AuroraInsightsDrawer.swift` - Side panel with Aurora's active commentary
- `DashboardFooterView.swift` - End of day summary shortcut and quick stats

## Phase 1: Unified Header Zone

**File:** `FocusOS/Views/Dashboard/Components/DashboardHeaderView.swift`

**Layout:**

- Title: "Dashboard" (28pt, bold, SF Pro Rounded)
- Subline: "Your day at a glance." (metricLabelStyle)
- Quick Actions row:
  - "New Entry" button (opens `UniversalCaptureMenu` via `.openContextualCreate` notification)
  - "Refresh" button (triggers data refresh)
  - "Search" button (global search - integrate with existing search system)
- ARTE Status Light: Small ring indicator showing current emotional state
  - Use `ReactiveThemeManager.shared.currentState`
  - Color mapping: Calm (kosmicBlue), Reflective (kosmicPurple), Energized (kosmicGreen), Fatigued (orange), Focused (kosmicBlue)
- **Cognitive Tempo Pulse Strip**: Small animated line visualizing current energy rhythm
  - Positioned below subline or integrated into header background
  - Animation speed varies by ARTE state:
    - Calm: Slow pulse (3-4 second cycle)
    - Reflective: Moderate pulse (2-3 second cycle)
    - Energized: Fast pulse (1-1.5 second cycle)
    - Focused: Steady rhythm (2 second cycle)
    - Fatigued: Very slow pulse (5-6 second cycle)
  - Visual: Horizontal line with animated gradient wave
  - Color: ARTE-modulated accent color with opacity pulse
  - Subtle, non-distracting animation

**Visual:**

- `.glassPanel(tier: .overlay)` background
- Gradient header: `LinearGradient(colors: [.kosmicBlue, .kosmicPurple], startPoint: .leading, endPoint: .trailing)`
- Header opacity fades on scroll (use `ScrollViewReader` + `GeometryReader` to track scroll position)
- Remains semi-persistent at top with reduced opacity

**Implementation:**

- Use `@EnvironmentObject` for `GlassColorSystem`
- Integrate with `ReactiveThemeManager.shared` for ARTE state
- Post `.openContextualCreate` notification for quick-add

## Phase 2: Daily Overview Row

**File:** `FocusOS/Views/Dashboard/Components/DailyOverviewPanel.swift`

**3-Column Adaptive Layout:**

- Use `LazyVGrid` with 3 flexible columns (collapses to 2/1 on smaller screens)
- Spacing: 16pt between cards

**Card 1: Focus Gravity Summary**

- Top 3 entities by CPS score (from `PriorityEngine.shared.getTopObjects(limit: 3)`)
- Mini radial chart showing distribution (use `Charts` framework or custom `Path`)
- "Next Priority Window: [time]" from `CognitionPredictor.shared` latest forecast
- Tap → deep link to `FocusGravityView`

**Card 2: ARTE Mood Pulse**

- Current tone display (from `ReactiveThemeManager.shared.currentState`)
- Short description: "You've maintained a steady calm energy since yesterday."
- Quote-style text with tone color accent
- Use `GlassPanel(tier: .contentCard)` with ARTE-modulated colors

**Card 3: Predictive Cognition Forecast**

- Fatigue risk meter (progress bar, 0-1 scale)
- Peak Focus window display (from `FocusForecast.nextFocusWindow`)
- "Cognitive Drift: Low/Medium/High" indicator
- Data from `CognitionPredictor.shared` latest forecast

**Interactions:**

- Tap cards → deep link to respective views (Focus Gravity, Insights, Predictive Cognition settings)
- Hover → `.floatLift()` animation (scale 1.015, shadow increase)

## Phase 3: Active Workfeed

**File:** `FocusOS/Views/Dashboard/Components/ActiveWorkfeedView.swift`

**Sections:**

**Ongoing Projects:**

- Fetch active projects (status != completed) from `PriorityEngine`
- Display as cards styled like `ProjectListCard` (from Projects V2)
- Show: Title, completion %, next task preview
- Limit to top 3-5 by CPS score

**Active Tasks:**

- Fetch top 5 tasks from `PriorityEngine.shared.getTopObjects(ofType: "task", limit: 5)`
- Filter out completed tasks
- Display compact task cards (similar to `TaskCardV2` but simplified)
- Inline status toggles (checkmark completion)
- Use `TaskCardV2` component with simplified props

**Recent Artifacts:**

- Fetch last 3 artifacts (creative or reflective outputs)
- Use `ArtifactCardV2` component
- Filter by `ArtifactState.published` or `ArtifactState.draft`

**Logic:**

- Pull from unified CPS priority index (`PriorityEngine.shared`)
- Filter out completed items
- Aurora reflection appears below feed:
  - Use `AIReflectionService` or `NarrativeEngine` to generate contextual insight
  - Display as quote-style text: "Your current rhythm is steady — one more completed focus block will bring your streak to 5 days."

## Phase 4: Rituals & Streaks Panel

**File:** `FocusOS/Views/Dashboard/Components/RitualsSummaryView.swift`

**Content:**

- Morning & Evening ritual completion bars (progress indicators)
- Streak tracker (current streak, best streak)
- "Next Nudge" forecast (from `SmartNudge` system)
- ARTE adaptive icon animation (gentle pulse if streak active)

**Data Source:**

- `RitualAnalytics.shared.generateSummary(timeRange: .week, modelContext: modelContext)`
- Display `RitualMetricsSummary.morningStreak`, `eveningStreak`, `completionRate`
- Fetch upcoming rituals from `FocusRitualManager.shared.upcomingRituals`

**Visual:**

- Use `GlassPanel(tier: .contentCard)` with ARTE-modulated accent
- Completion bars with gradient (kosmicGreen → kosmicBlue)
- Streak badges with pulse animation when active

## Phase 5: Journal & Reflection Feed

**File:** `FocusOS/Views/Dashboard/Components/ReflectionFeedView.swift`

**Layout:**

- List of recent Journal entries (last 5-7)
- Each entry shows:
  - Date + tone color dot (from ARTE state at time of entry)
  - Snippet preview (first 2 lines of content)
  - ARTE tone arc behind it (calm → creative gradient)
- Aurora's "Reflection of the Day" bubble at top:
  - Use `NarrativeEngine` or `AIReflectionService` to generate daily reflection
  - Quote-style: "You've been most consistent when your sessions begin before noon."

**Data Source:**

- Fetch recent `Journal` entries (sorted by `createdAt` descending)
- Use `JournalAIService` for AI-generated reflections
- Map ARTE state to entry timestamps (if available in metadata)

**Visual:**

- Each entry card uses `GlassPanel(tier: .contentCard)`
- Tone arc as background gradient (subtle, low opacity)
- Date formatting: relative time ("2 hours ago") or absolute if >24h

## Phase 6: Aurora Insights Drawer

**File:** `FocusOS/Views/Dashboard/Components/AuroraInsightsDrawer.swift`

**Purpose:**

Side panel (swipe or button open) providing Aurora's active commentary sections:

- "Today's Forecast" (from Predictive Cognition)
- "Behavioral Trends" (from AnalyticsEngine)
- "Suggested Focus Intent" (from CPS priorities)
- "Emotional Summary" (from ARTE state history)
- "Small Wins" recap (from recent completions)

**Visual:**

- `.glassPanel(tier: .contentCard)` background
- Gradient header: `LinearGradient(colors: [.kosmicGreen, .kosmicBlue], startPoint: .topLeading, endPoint: .bottomTrailing)`
- Closes with swipe gesture or Escape key
- Slide-in animation from trailing edge

**Implementation:**

- Use `@State` for drawer visibility
- `DragGesture` for swipe-to-close
- `.keyboardShortcut(.escape)` for keyboard close
- Fetch insights from:
  - `CognitionPredictor.shared` for forecast
  - `AnalyticsEngine.shared` for trends
  - `PriorityEngine.shared` for focus intent
  - `ReactiveThemeManager.shared` for emotional summary
  - `RitualAnalytics.shared` for small wins

## Phase 7: Footer Zone

**File:** `FocusOS/Views/Dashboard/Components/DashboardFooterView.swift`

**Content:**

- "End of Day Summary" shortcut button
- Quick stats:
  - Sessions Completed Today (from `FocusSession` queries)
  - Total Focus Time (sum of session durations)
  - Current Streak (from `RitualAnalytics`)
- Aurora quote: "Momentum begins with awareness."

**Visual:**

- Subtle `GlassPanel(tier: .contentCard)` background
- Stats displayed as metric cards
- Quote styled as italic, secondary text color

## Phase 8: Data & Integration Flow

**Services Integration:**

| Service | Purpose | Usage |

|---------|---------|-------|

| `PriorityEngine.shared` | CPS priority data | `getTopObjects(limit:)`, `getTopObjects(ofType:limit:)` |

| `ReactiveThemeManager.shared` | ARTE emotional state | `currentState`, `emotionalStatePublisher` |

| `CognitionPredictor.shared` | Predictive forecasts | Latest `FocusForecast`, `nextFocusWindow` |

| `RitualAnalytics.shared` | Ritual metrics | `generateSummary()`, streak data |

| `FocusGravityService.shared` | Focus gravity data | Top entities, CPS distribution |

| `JournalAIService` | Journal reflections | Recent entries, AI-generated insights |

| `MemoryGraphService` | Entity cross-links | Related entities, theme connections |

| `NarrativeEngine` or `AIReflectionService` | Aurora commentary | Behavioral summaries, reflections |

**Data Fetching Pattern:**

- Use `@Query` for SwiftData models where possible
- Use `@State` + `Task` for async service calls
- Cache results with `@State` variables, refresh on appear or manual refresh
- Debounce rapid updates (e.g., ARTE state changes)

## Phase 9: Visual Rhythm & Tokens

**Design Tokens:**

- Corner Radius: 12pt (consistent with existing cards)
- Font: SF Pro Rounded for titles, Inter for body text
- Blur: `.ultraThinMaterial` backgrounds (via `GlassPanel`)
- Primary Gradient: `LinearGradient(colors: [.kosmicBlue, .kosmicPurple], ...)`
- Accent Gradient: `LinearGradient(colors: [.kosmicGreen, .kosmicPurple], ...)`
- Animation: `GlassMotion.Easing.spring` (response: 0.3, dampingFraction: 0.7)
- Shadow: `Color.kosmicPurple.opacity(0.15), radius: 3`
- Hover: `.floatLift()` (scale 1.015, shadow increase)
- Transition: `.opacity` + `.move(edge: .trailing)`

**Color Definitions:**

- `.kosmicBlue`: `Color(red: 72/255, green: 131/255, blue: 255/255)`
- `.kosmicPurple`: `Color(red: 124/255, green: 77/255, blue: 255/255)`
- `.kosmicGreen`: Use existing definition from codebase

## Phase 10: Accessibility & Calm Mode

**Calm Mode:**

- Desaturated gradients (reduce saturation by 30%)
- Slower transitions (multiply duration by 1.5x)
- Ambient breathing dot animation (subtle pulse)
- Toggle via `@AppStorage("dashboard.calmMode")`

**Accessibility:**

- VoiceOver-friendly feed hierarchy (`accessibilityLabel`, `accessibilityHint`)
- Large Text compliant (use `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)`)
- Reduce Motion disables micro-animations (check `@Environment(\.accessibilityReduceMotion)`)
- Semantic grouping with `accessibilityElement(children: .combine)`

## Phase 11: Main View Integration

**File:** `FocusOS/Views/Dashboard/DashboardViewV2.swift`

**Structure:**

```swift
ScrollView {
    VStack(spacing: 24) {
        DashboardHeaderView(...)
            .padding(.horizontal)
            .padding(.top)
        
        DailyOverviewPanel(...)
            .padding(.horizontal)
        
        ActiveWorkfeedView(...)
            .padding(.horizontal)
        
        RitualsSummaryView(...)
            .padding(.horizontal)
        
        ReflectionFeedView(...)
            .padding(.horizontal)
        
        DashboardFooterView(...)
            .padding(.horizontal)
            .padding(.bottom)
    }
}
.overlay(alignment: .trailing) {
    if showAuroraInsights {
        AuroraInsightsDrawer(...)
            .transition(.move(edge: .trailing))
    }
}
```

**State Management:**

- `@State private var showAuroraInsights = false`
- `@State private var headerOpacity: Double = 1.0`
- `@Environment(\.modelContext) private var modelContext`
- `@EnvironmentObject private var glassColorSystem: GlassColorSystem`

**Navigation:**

- Deep links to Focus Gravity, Insights, Journal, Projects, Tasks
- Use `NavigationLink` or notification-based navigation

## Implementation Order

1. Create `DashboardViewV2.swift` main container
2. Implement `DashboardHeaderView.swift` (Phase 1)
3. Implement `DailyOverviewPanel.swift` (Phase 2)
4. Implement `ActiveWorkfeedView.swift` (Phase 3)
5. Implement `RitualsSummaryView.swift` (Phase 4)
6. Implement `ReflectionFeedView.swift` (Phase 5)
7. Implement `AuroraInsightsDrawer.swift` (Phase 6)
8. Implement `DashboardFooterView.swift` (Phase 7)
9. Integrate all components in main view
10. Add accessibility features (Phase 10)
11. Add Calm Mode toggle
12. Test scroll behavior and header persistence

## Key Files to Reference

- `FocusOS/Views/Focus/Components/FocusGravityCard.swift` - Card styling reference
- `FocusOS/Views/Tasks/Components/TaskCardV2.swift` - Task card patterns
- `FocusOS/Views/Projects/Views/ProjectListView.swift` - Project card patterns
- `FocusOS/Views/Components/GlassPanel.swift` - Glass panel component
- `FocusOS/Services/PriorityEngine.swift` - CPS data source
- `FocusOS/Services/ReactiveThemeManager.swift` - ARTE state source
- `FocusOS/Services/CognitionPredictor.swift` - Predictive forecasts
- `FocusOS/Services/RitualAnalytics.swift` - Ritual metrics
- `FocusOS/Utilities/GlassMotion.swift` - Animation constants