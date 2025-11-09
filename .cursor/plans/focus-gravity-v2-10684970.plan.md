<!-- 10684970-8e8e-492b-921b-2eb215e20999 51c2df07-2eb4-43b6-b839-61a6c20a0c09 -->
# Focus Gravity V2 — Build Plan

## Overview

Transform the existing `FocusGravityView.swift` into a comprehensive cognitive priority visualization dashboard. The new V2 integrates PriorityEngine CPS scores with FocusSessionService metrics, Predictive Cognition forecasts, ARTE emotional tone, and RitualAnalytics streaks to create a live map of cognitive engagement.

## Architecture

### Data Flow

```
PriorityEngine → FocusGravityService → FocusGravityViewV2
      ↑                    ↓
FocusSessionService ← RitualAnalytics ← ARTE (ReactiveThemeManager)
      ↑
CognitionPredictor (FocusForecast)
```

### New Service: FocusGravityService

**File:** `Cloutmate/Services/FocusGravityService.swift`

Purpose: Central service that aggregates CPS data with session/ritual/predictive layers and computes gravity weights for orbit visualization.

**Key Methods:**

- `fetchFocusEntities(timeScope: TimeScope, filter: EntityFilter, modelContext: ModelContext) -> [FocusEntity]`
- `computeGravityWeights(entities: [FocusEntity]) -> [UUID: Double]`
- `getOrbitPositions(entities: [FocusEntity], center: CGPoint, radius: CGFloat) -> [UUID: CGPoint]`
- `getLatestForecast(modelContext: ModelContext) -> FocusForecast?`
- `getFocusDistribution(entities: [FocusEntity]) -> FocusEnergyProfile`

**Caching:** 10-minute TTL, invalidates on CPS updates or session changes

### New Model: FocusEntity

**File:** `Cloutmate/Models/FocusEntity.swift`

```swift
struct FocusEntity: Identifiable {
    let id: UUID
    let name: String
    let type: String  // "task", "project", "note", "artifact"
    let cpsScore: Double
    let energy: FocusEnergyProfile  // cognitive, creative, completion ratios
    let forecast: FocusForecast?
    let lastActivity: Date?
    let sessionCount: Int
    let ritualWeight: Double  // Morning/evening streak contribution
}
```

**FocusEnergyProfile:**

```swift
struct FocusEnergyProfile {
    let cognitive: Double  // 0-1
    let creative: Double   // 0-1
    let completion: Double // 0-1
}
```

## File Structure

```
Cloutmate/Views/Focus/
├── FocusGravityViewV2.swift          (Main view - replaces FocusGravityView.swift)
├── Components/
│   ├── FocusGravityOrbit.swift       (Orbit visualization with spring physics)
│   ├── FocusGravityCard.swift        (Priority card matching Tasks/Projects V2 style)
│   ├── FocusTrendChart.swift         (Weekly focus distribution bar chart)
│   ├── FocusForecastRing.swift       (Predictive energy ring overlay)
│   └── FocusInsightsDrawer.swift     (Sidebar commentary + stats)
└── Services/
    └── FocusGravityService.swift      (New aggregation service)

Cloutmate/Models/
└── FocusEntity.swift                 (New data model)
```

## Implementation Phases

### Phase 1: Core Service & Models

1. **Create FocusGravityService.swift**

   - Implement `fetchFocusEntities()` using PriorityEngine.getTopObjects()
   - Merge with FocusSessionService active/recent sessions
   - Integrate RitualAnalytics streak weights
   - Fetch latest FocusForecast from CognitionPredictor
   - Compute FocusEnergyProfile per entity (cognitive/creative/completion ratios)
   - Add 10-minute cache with invalidation

2. **Create FocusEntity.swift model**

   - Define FocusEntity struct with all required fields
   - Define FocusEnergyProfile struct
   - Add helper methods for energy type determination

### Phase 2: Main View Structure

3. **Create FocusGravityViewV2.swift**

   - Replace existing FocusGravityView.swift (or create new and update navigation)
   - Header section:
     - Title "Focus Gravity" with ARTE glow ring (using ReactiveThemeManager)
     - Filter chips: All, Tasks, Projects, Artifacts, Notes
     - Time scope selector: Today, Week, Month
     - Search bar + refresh button
   - Main content area:
     - Focus Orbit Visualization (center)
     - Priority List (right side, matching TaskCardV2/ProjectListView style)
     - Trend Panels (bottom)
   - Sidebar Insights Drawer (collapsible)

### Phase 3: Orbit Visualization

4. **Create FocusGravityOrbit.swift**

   - Central gravity well (pulsing node representing user focus)
   - Orbiting nodes for top entities:
     - Node color = dominant energy type (Blue=cognitive, Purple=creative, Green=completion)
     - Node size = priority score weight (scaled 20-60pt)
     - Hover tooltip: title + % focus allocation
   - Smooth orbital motion using `.spring(response: 0.6, dampingFraction: 0.8)`
   - ARTE gradient overlay responds to ReactiveThemeManager.currentState
   - Predictive overlay: wave distortion behind gravity well when forecast available
   - Node pulse speed increases as forecasted focus peak approaches

### Phase 4: Priority Cards

5. **Create FocusGravityCard.swift**

   - Match visual language from TaskCardV2.swift and ProjectListView.swift
   - Card shows:
     - Title + object type badge
     - CPS score + focus distribution bar (cognitive/creative/completion segments)
     - Recent activity: last session time, edit time, artifact count
     - Micro forecast badge: "Focus Peak in 40m" or "Fatigue risk ↑"
     - Quick actions: Open • Pin • Dismiss buttons
   - Gradient border using ARTE state color
   - Hover expansion with additional details

### Phase 5: Trend Panels

6. **Create FocusTrendChart.swift**

   - Weekly Focus Distribution: bar chart from CPS analytics
   - Uses Charts framework (already imported in OverviewTabView.swift)
   - Data from FocusGravityService weekly trend aggregation

7. **Create FocusForecastRing.swift**

   - Predictive Forecast Ring: color-coded (green → yellow → red)
   - Shows fatigue risk and focus stability from latest FocusForecast
   - Overlays on orbit visualization
   - Updates every 2 hours or on manual refresh

8. **Add Session Energy Map**

   - Heatmap showing Focus Mode + Ritual streaks
   - Data from FocusSessionService + RitualAnalytics
   - Integrated into trend panels section

9. **Add ARTE Tone Drift Graph**

   - Shows tonal consistency over past 7 days
   - Data from ReactiveThemeManager state history (if available) or inferred from sessions

### Phase 6: Insights Drawer

10. **Create FocusInsightsDrawer.swift**

    - Sidebar panel (collapsible, slides in from right)
    - Sections:
      - "Current Pull" (top weighted entities with percentages)
      - "Drift Alerts" (from Predictive Cognition DriftMonitor)
      - "Focus Bias" (ratio of cognitive vs creative vs completion)
      - Aurora commentary card (ARTE tone-adjusted insights using NudgeToneAdapter pattern)
    - Uses GlassPanel styling consistent with existing views

### Phase 7: Integration & Polish

11. **Integrate with Insights Dashboard**

    - Sync data to Insights → Focus Analytics tab
    - Provide daily focus distribution data
    - Feed into Predictive Cognition accuracy feedback loop

12. **Add Keyboard Navigation**

    - Arrow keys (← →) cycle through orbit nodes
    - Enter opens selected entity
    - Tab navigates between sections

13. **Add VoiceOver Support**

    - Reads orbit order + card details
    - Describes focus distribution percentages

14. **Add Reduce Motion Compliance**

    - Respects accessibility reduce motion setting
    - Falls back to static layout when disabled

15. **Performance Optimization**

    - Ensure snapshot refresh rate < 0.5s delay
    - Lazy load trend data
    - Debounce orbit animations

## Visual Design Notes

- **Color System:** Use existing kosmicBlue, kosmicPurple, kosmicGreen from GlassColorSystem
- **Animation:** `.spring(response: 0.6, dampingFraction: 0.8)` for smooth motion
- **Glass Panels:** Use existing GlassPanel component with tier: .contentCard
- **ARTE Integration:** Subscribe to ReactiveThemeManager.$currentState for real-time color/glow updates
- **Card Style:** Match TaskCardV2.swift gradient borders and hover effects

## Testing Checklist

- [ ] CPS ranking correctness across all object types (task, project, note, artifact)
- [ ] Orbit visualization updates smoothly on data refresh
- [ ] Forecast overlay matches Predictive Cognition metrics
- [ ] ARTE tones respond instantly to state change
- [ ] Keyboard navigation works (← → for node cycle, Enter to open)
- [ ] VoiceOver reads orbit order + card details correctly
- [ ] Reduce motion compliance verified
- [ ] Snapshot refresh rate < 0.5s delay
- [ ] Cache invalidation works correctly on CPS updates
- [ ] Integration with Insights dashboard verified

## Dependencies

- PriorityEngine (existing)
- FocusSessionService (existing)
- CognitionPredictor (existing)
- ReactiveThemeManager (existing)
- RitualAnalytics (existing)
- ProjectFocusGravityService (existing - can reuse energy calculation logic)
- Charts framework (already used in Insights)
- SwiftData models: PriorityScore, FocusSession, FocusForecast, RitualCompletion

### To-dos

- [x] 
- [x] 
- [ ] 