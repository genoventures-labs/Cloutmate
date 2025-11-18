<!-- 9e37ae95-23cd-47f0-a37f-9c95fe71a475 fe770ba1-c5b6-4dc8-84e6-939bf98ee906 -->
# Fix Dashboard Toggles and Add Comprehensive Workflow Insights

## Overview

The dashboard toggles in `DashboardSettingsView` don't work because the static `DashboardView` is used instead of `CustomizableDashboardView`. We'll replace the static view with the customizable one, add comprehensive workflow insights (tasks, projects, social media, PARA metrics) as toggleable cards, and implement fully functional card sizing.

## Changes Required

### 1. Update MainWindowView to use CustomizableDashboardView

**File**: `FocusOS/Views/MainWindowView.swift`

- Replace `case .home: HomeView()` routing to use `CustomizableDashboardView` instead

### 2. Expand DashboardCardType with Comprehensive Insights

**File**: `FocusOS/Models/DashboardCard.swift`

Add new insight card types organized by category:

**PARA Workflow Insights:**

- `projectsOverview` - Active/completed projects breakdown
- `tasksOverview` - Tasks by priority and status
- `areasHealth` - Area health scores and cadence tracking
- `notesActivity` - Recent notes and knowledge capture trends

**Social Media Insights:**

- `socialOverview` - Combined social metrics (posts, engagement, reach)
- `postingStreak` - Current streak and consistency
- `contentPerformance` - Best/worst performing posts
- `platformComparison` - Threads vs Facebook metrics

**Facebook Page Insights (Individual & Combined):**

- `facebookPageViews`, `facebookPageFans`, `facebookPageReach`
- `facebookPageImpressions`, `facebookEngagedUsers`, `facebookPostEngagements`
- `facebookPageInsightsOverview` - Combined FB metrics card

**Productivity Insights:**

- `upcomingDeadlines` - Next 7 days tasks/projects due
- `workloadBalance` - Time allocation across projects/areas
- `completionRate` - Weekly/monthly completion trends
- `inboxTrend` - Inbox processing velocity

Add appropriate icons and default sizes for each

### 3. Create Comprehensive Insight Card Components

**File**: `FocusOS/Views/Dashboard/WorkflowInsightsCards.swift` (new file)

**File**: `FocusOS/Views/Dashboard/SocialInsightsCards.swift` (new file)

**File**: `FocusOS/Views/Dashboard/FacebookInsightsCards.swift` (new file)

Each card should:

- Query relevant SwiftData models
- Calculate meaningful metrics
- Display prominently with visual indicators (trends, charts, progress bars)
- Adapt content based on size (small/medium/large)
- Handle empty states gracefully

**Example cards to create:**

- `ProjectsOverviewCard` - Shows active projects count, completion rate, timeline health
- `TasksOverviewCard` - Tasks breakdown by priority, overdue count, today's tasks
- `AreasHealthCard` - Area cadence status, task distribution, attention needed
- `SocialOverviewCard` - Total posts (7d), avg engagement, reach, platform split
- `PostingStreakCard` - Current streak, best streak, calendar visualization
- `ContentPerformanceCard` - Top post metrics, improvement areas
- `UpcomingDeadlinesCard` - Next 3-5 deadlines with time remaining
- `CompletionRateCard` - Weekly completion percentage with trend graph
- `InboxTrendCard` - Processing rate, current backlog

### 4. Implement Dynamic Card Sizing System

**File**: `FocusOS/Views/Dashboard/CustomizableDashboardView.swift`

Replace fixed 2-column grid (lines 29-32) with adaptive sizing:

```swift
LazyVGrid(columns: [
    GridItem(.adaptive(minimum: 160), spacing: 16)
], spacing: 16) {
    ForEach(sortedCards) { card in
        DashboardCardView(card: card)
            .gridCellColumns(card.cardSize == .small ? 1 : 2)
            .frame(height: cardHeight(for: card.cardSize))
    }
}
```

Height mapping:

- Small: 140pt
- Medium: 140pt (wider, same height)
- Large: 300pt (wider and taller)

### 5. Update DashboardCardView Switch Statement

**File**: `FocusOS/Views/Dashboard/CustomizableDashboardView.swift`

- Add cases for all new insight card types (line 136+)
- Pass card size to components so they adapt content
- Ensure existing cards also receive size parameter

### 6. Redesign DashboardSettingsView with Categories

**File**: `FocusOS/Views/Dashboard/DashboardSettingsView.swift`

Replace flat list with categorized sections:

```swift
List {
    Section("PARA Workflow") {
        // Projects, Tasks, Areas, Notes insights
    }
    
    Section("Social Media") {
        // Social overview, streak, content performance
    }
    
    Section("Facebook Page Insights") {
        // Individual FB metrics + overview
    }
    
    Section("Productivity") {
        // Deadlines, workload, completion, inbox
    }
    
    Section("Quick Actions") {
        // Quick capture, AI suggestions (existing)
    }
}
```

Each section:

- Toggle switches with card descriptions
- "Select All" / "Deselect All" buttons
- Visual indicators for enabled cards

Visible cards section:

- Size picker (small/medium/large)
- Live preview of how card will look
- Reordering controls

### 7. Update All Card Components for Size Awareness

Ensure every card adapts content based on size:

- **Small**: Single key metric, large number, minimal text
- **Medium**: Metric + secondary info or mini trend
- **Large**: Metric + chart/graph + detailed breakdown

### 8. Add Default Dashboard Cards Setup

**File**: `FocusOS/Views/Dashboard/CustomizableDashboardView.swift`

Update `setupDefaultCardsIfNeeded()` to include workflow insights:

```swift
let defaultCards = [
    DashboardCard(cardType: .projectsOverview, position: 0, size: .medium),
    DashboardCard(cardType: .tasksOverview, position: 1, size: .medium),
    DashboardCard(cardType: .socialOverview, position: 2, size: .large),
    DashboardCard(cardType: .upcomingDeadlines, position: 3, size: .small),
    DashboardCard(cardType: .postingStreak, position: 4, size: .small),
    DashboardCard(cardType: .inboxCount, position: 5, size: .small)
]
```

### 9. Archive Old DashboardView

**File**: `FocusOS/Views/Dashboard/DashboardView.swift`

- Remove/archive since replaced by CustomizableDashboardView

## Implementation Order

1. Expand `DashboardCardType` enum with all insight types
2. Implement dynamic sizing system in `CustomizableDashboardView`
3. Create `WorkflowInsightsCards.swift` with PARA/productivity cards
4. Create `SocialInsightsCards.swift` with social media insight cards
5. Create `FacebookInsightsCards.swift` with FB page insight cards
6. Update all existing cards to be size-aware
7. Update `DashboardCardView` switch with all new cases
8. Redesign `DashboardSettingsView` with categories
9. Update default cards setup
10. Update routing in `MainWindowView`
11. Test all functionality
12. Archive old `DashboardView`

## Key Metrics to Track

**PARA Workflow:**

- Active projects count & health
- Tasks by priority/status
- Area cadence compliance
- Notes created this week

**Social Media:**

- Posts published (period)
- Average engagement rate
- Total reach & impressions
- Platform performance comparison

**Productivity:**

- Completion rate trends
- Overdue items
- Inbox processing velocity
- Time to task completion

### To-dos

- [ ] Add comprehensive insight card types (PARA, social, productivity) to DashboardCardType enum
- [ ] Implement adaptive grid layout with gridCellColumns for proper card sizing
- [ ] Create WorkflowInsightsCards.swift with PARA and productivity insight components
- [ ] Create SocialInsightsCards.swift with social media insight components
- [ ] Create FacebookInsightsCards.swift with FB page insight components
- [ ] Make all existing card components size-aware
- [ ] Add all new card cases to DashboardCardView switch
- [ ] Redesign DashboardSettingsView with categorized sections
- [ ] Update default cards setup with comprehensive insights
- [ ] Update MainWindowView to use CustomizableDashboardView
- [ ] Test all toggles, sizing, and insights; archive old DashboardView