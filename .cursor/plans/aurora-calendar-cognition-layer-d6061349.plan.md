<!-- d6061349-cb6b-4334-b21f-69e2ffb73256 71847e77-522a-49a1-b92b-3153f4549163 -->
# Aurora Calendar Cognition Layer - Auto-Colorized Dynamic Scheduling

## Overview

Transform the Calendar into a living "urgency map" where Aurora automatically analyzes tasks, projects, deadlines, energy patterns, and urgency levels to dynamically color-code every calendar event. Colors shift throughout the day as context changes, providing real-time visual feedback on cognitive reality.

## Architecture

```
AuroraCalendarCognitionService
    ↓
CalendarColorEngine (core logic)
    ↓
EventColorReason (explainability)
    ↓
CalendarEvent.colorHex (persisted)
    ↓
Calendar Views (visual rendering)
```

## 1. Core Service Layer

### 1.1 AuroraCalendarCognitionService

**File:** `FocusOS/Services/AuroraCalendarCognitionService.swift` (new)

Main orchestrator service that:

- Analyzes all calendar events on a schedule (every 15 minutes + on-demand)
- Fetches linked tasks, projects, focus sessions
- Computes urgency scores using multiple factors
- Assigns colors via CalendarColorEngine
- Stores reasoning in EventColorReason
- Triggers triage recommendations when needed
- Suggests light-day optimizations

**Key Methods:**

- `analyzeAndColorizeEvents(modelContext:) async` - Main analysis loop
- `getColorForEvent(_:modelContext:) async -> EventColor` - Single event analysis
- `checkTriageNeeded(for:modelContext:) -> TriageRecommendation?` - Overload detection
- `suggestLightDayOptimizations(for:modelContext:) -> [DayOptimization]` - Light day suggestions
- `updateEventColor(_:reason:modelContext:)` - Persist color + reasoning

**Dependencies:**

- PriorityEngine (CPS scores)
- CognitionPredictor (energy patterns)
- AnalyticsEngine (historical patterns)
- FocusRitualManager (streak risk)
- CalendarSyncService (external events)

### 1.2 CalendarColorEngine

**File:** `FocusOS/Services/CalendarColorEngine.swift` (new)

Core color assignment logic with weighted scoring:

**Color Mapping:**

- **Red** → Critical urgency (deadline < 24h, overdue tasks, high slippage risk)
- **Orange** → High priority (deadline < 3 days, approaching urgency, high CPS)
- **Yellow** → Mild time pressure (deadline < 7 days, medium priority)
- **Blue** → Deep focus work (linked to focus sessions, high effort, meaningful)
- **Green** → Calm/flexible (low urgency, negotiable, recovery time)
- **Purple** → Personal/recovery (rituals, breaks, mental maintenance)

**Scoring Factors (weighted):**

1. Deadline proximity (0-1, exponential decay)
2. Overdue linked tasks count (0-1, normalized)
3. Project phase urgency (early=0.2, mid=0.5, final=0.9)
4. User-set priority (low=0.2, medium=0.5, high=0.9)
5. Actual vs planned slippage (0-1, based on FocusSession history)
6. Effort required (small=0.2, medium=0.5, large=0.9)
7. Energy/time of day match (0-1, from CognitionPredictor)
8. Streak risk (0-1, from FocusRitualManager)
9. Ritual/anchor status (0.8 if ritual-linked)
10. Daily workload density (0-1, events per hour)

**Method:**

- `computeUrgencyScore(for:modelContext:) -> Double` - Weighted urgency (0-1)
- `assignColor(urgency:factors:) -> EventColor` - Map score to color
- `getColorExplanation(urgency:factors:) -> String` - Human-readable reason

### 1.3 EventColorReason Model

**File:** `FocusOS/Models/EventColorReason.swift` (new)

SwiftData model storing why Aurora assigned each color:

```swift
@Model
final class EventColorReason {
    var eventId: UUID
    var colorHex: String
    var urgencyScore: Double
    var primaryFactor: String // "deadline", "overdue", "energy", etc.
    var secondaryFactors: [String]
    var explanation: String // Human-readable
    var computedAt: Date
    var factors: [String: Double] // Factor name → weight
}
```

**Usage:** Display in hover tooltips and event detail drawers.

## 2. Event Categorization

### 2.1 EventCategoryDetector

**File:** `FocusOS/Services/EventCategoryDetector.swift` (new)

Detects event type from context:

**Categories:**

- `deepWork` - Linked to FocusSession, high effort, >30min duration
- `lightAdmin` - Short duration, low effort, no focus session
- `personal` - Ritual-linked, break, recovery time
- `highUrgency` - Deadline < 24h, overdue tasks linked
- `negotiable` - No deadline, low CPS, flexible timing
- `nonNegotiable` - External meeting, fixed time, high priority
- `blocker` - Has dependencies, blocks other tasks
- `independent` - No dependencies, standalone

**Method:**

- `categorizeEvent(_:modelContext:) -> EventCategory` - Returns category enum

## 3. Planned vs Actual Tracking

### 3.1 CalendarEvent Extensions

**File:** `FocusOS/Models/CalendarEvent+Tracking.swift` (new)

Add computed properties to CalendarEvent:

- `plannedDuration: TimeInterval` - From endDate - startDate
- `actualDuration: TimeInterval?` - From linked FocusSession.actualDuration
- `slippageRatio: Double` - actualDuration / plannedDuration (1.0 = on time)
- `wasCompleted: Bool` - Linked FocusSession.completed
- `wasIgnored: Bool` - No FocusSession, no completion, past endDate

**Integration:**

- When FocusSession completes, update CalendarEvent tracking
- When event passes without FocusSession, mark as ignored
- Use slippageRatio in color computation

## 4. Dynamic Updates

### 4.1 ColorUpdateScheduler

**File:** `FocusOS/Services/ColorUpdateScheduler.swift` (new)

Timer-based service that:

- Runs every 15 minutes
- Checks for events that need re-coloring (deadline approaching, task completed, etc.)
- Triggers AuroraCalendarCognitionService.analyzeAndColorizeEvents()
- Respects user's "reduce motion" preference for update frequency

**Triggers:**

- Time-based (every 15 min)
- Task completion (NotificationCenter)
- Deadline approaching (< 1 hour remaining)
- FocusSession status change
- Project phase change

## 5. Triage & Recommendations

### 5.1 TriageAnalyzer

**File:** `FocusOS/Services/TriageAnalyzer.swift` (new)

Detects overloaded days and suggests optimizations:

**Triage Detection:**

- Count red/orange events per day
- If > 3 high-urgency blocks → trigger triage
- Calculate daily workload density (events per hour)
- Check for scheduling conflicts

**Recommendations:**

- Create triage window (dedicated time block for urgent items)
- Surface high ROI tasks (CPS × urgency)
- Suggest rescheduling (move negotiable items)
- Suggest splitting (break large tasks)
- Suggest dropping (low-value items)

**Model:**

```swift
struct TriageRecommendation {
    var date: Date
    var urgencyCount: Int
    var suggestedActions: [TriageAction]
    var highROITasks: [UUID]
    var rescheduleCandidates: [UUID]
}
```

### 5.2 Light Day Optimizer

**File:** `FocusOS/Services/LightDayOptimizer.swift` (new)

Suggests optimizations when day is too light:

**Detection:**

- < 3 events scheduled
- Low workload density (< 2 hours of events)
- No high-priority items

**Suggestions:**

- Pull tasks forward (from tomorrow/next week)
- Accelerate project arcs (start next phase early)
- Rest opportunities (schedule recovery time)
- Pre-prep for tomorrow (plan ahead)

## 6. Visual Enhancements

### 6.1 CalendarEventCard Updates

**File:** `FocusOS/Views/Calendar/Components/CalendarEventCard.swift` (new)

Enhanced event card with:

- Dynamic color from `event.colorHex` (fallback to cyan if nil)
- Hover tooltip showing `EventColorReason.explanation`
- Glow animation when urgency increases (subtle pulse)
- Fade animation when urgency decreases
- Color intensity based on urgency score

**Glow States:**

- Red events: Pulsing red glow (2s cycle) when < 1 hour to deadline
- Orange events: Subtle orange glow when < 3 hours
- Blue events: Calm blue glow for deep work
- Green events: Soft fade when completed early

### 6.2 CalendarDayCellV2 Updates

**File:** `FocusOS/Views/Calendar/Components/CalendarDayCellV2.swift` (modify)

Update day cell to:

- Show dominant color indicator (most urgent event color)
- Display urgency count badge (red/orange events)
- Animate color changes smoothly

### 6.3 Event Color Tooltip

**File:** `FocusOS/Views/Calendar/Components/EventColorTooltip.swift` (new)

Hover/click tooltip showing:

- Current color and urgency score
- Primary factor (e.g., "Deadline in 2 hours")
- Secondary factors (bullet list)
- Full explanation text
- "Override color" button (with learning)

## 7. User Overrides & Learning

### 7.1 Color Override System

**File:** `FocusOS/Services/ColorOverrideManager.swift` (new)

Handles user color overrides:

- Store override in CalendarEvent.colorHex (user-set)
- Track override in EventColorReason (flag: `isUserOverride`)
- Learn from overrides (adjust weights if user consistently overrides)
- Show "Aurora's suggestion" vs "Your override" in UI

**Learning:**

- If user overrides red → green frequently, reduce deadline weight
- If user overrides blue → red, increase effort weight
- Adaptive weight adjustment (10% conservative shifts)

## 8. Insights Integration

### 8.1 Calendar Insights Card

**File:** `FocusOS/Views/Insights/Components/CalendarInsightsCard.swift` (new)

New card in Insights → Overview showing:

- "Your afternoon blocks tend to overrun by 25%"
- "You consistently complete deep work fastest between 9–11am"
- "This week has 3 red blocks; consider redistributing"
- Color distribution chart (pie/bar)
- Urgency trend over time (line chart)

### 8.2 AnalyticsEngine Extension

**File:** `FocusOS/Services/AnalyticsEngine+Calendar.swift` (new)

Add calendar metrics to AnalyticsSnapshot:

- Average urgency score per day
- Color distribution (red/orange/yellow/blue/green/purple counts)
- Slippage patterns (average actualDuration / plannedDuration)
- Best time windows (from FocusSession completion data)
- Triage frequency (overload days per week)

## 9. Auto-Scheduling Suggestions

### 9.1 CalendarSuggestionEngine

**File:** `FocusOS/Services/CalendarSuggestionEngine.swift` (new)

Integrates with AdaptiveScheduler to suggest:

- Optimal placement for tasks (based on energy patterns)
- Best time windows (from CognitionPredictor)
- Conflict resolution (move negotiable items)
- Buffer time insertion (between high-urgency blocks)

**Method:**

- `suggestOptimalTime(for:modelContext:) -> Date?` - Returns best time slot
- `recommendReschedule(_:modelContext:) -> Date?` - Suggests new time

## 10. Integration Points

### 10.1 UnifiedCalendarView Updates

**File:** `FocusOS/Views/Calendar/UnifiedCalendarView.swift` (modify)

- Initialize AuroraCalendarCognitionService on appear
- Subscribe to color update notifications
- Refresh event colors when tasks/projects update
- Display triage recommendations banner when needed
- Show light-day suggestions in sidebar

### 10.2 CalendarEventDrawer Updates

**File:** `FocusOS/Views/Calendar/Components/CalendarEventDrawer.swift` (modify)

- Display current Aurora-assigned color
- Show color explanation tooltip
- Allow color override with "Use Aurora's suggestion" toggle
- Show linked task/project urgency indicators

### 10.3 FocusOSApp Integration

**File:** `FocusOS/FocusOSApp.swift` (modify)

- Start AuroraCalendarCognitionService on app launch
- Register EventColorReason in ModelContainer
- Set up notification observers for color updates

## 11. Settings & Configuration

### 11.1 Calendar Cognition Settings

**File:** `FocusOS/Views/Settings/CalendarCognitionSettingsView.swift` (new)

Settings panel for:

- Enable/disable auto-coloring
- Color sensitivity (how aggressive urgency detection)
- Update frequency (15min, 30min, 1hr)
- Triage threshold (how many red blocks trigger triage)
- Override learning (enable/disable adaptive weights)
- Reset color history

## 12. Data Models

### 12.1 EventColor Enum

**File:** `FocusOS/Models/EventColor.swift` (new)

```swift
enum EventColor: String, CaseIterable {
    case red, orange, yellow, blue, green, purple
    
    var hex: String {
        switch self {
        case .red: return "#FF3B30"
        case .orange: return "#FF9500"
        case .yellow: return "#FFCC00"
        case .blue: return "#007AFF"
        case .green: return "#34C759"
        case .purple: return "#AF52DE"
        }
    }
    
    var description: String {
        switch self {
        case .red: return "Critical urgency"
        case .orange: return "High priority"
        case .yellow: return "Mild time pressure"
        case .blue: return "Deep focus work"
        case .green: return "Calm & flexible"
        case .purple: return "Personal & recovery"
        }
    }
}
```

## Implementation Order

1. **Phase 1:** Core service layer (AuroraCalendarCognitionService, CalendarColorEngine, EventColorReason)
2. **Phase 2:** Event categorization & planned vs actual tracking
3. **Phase 3:** Dynamic updates & color scheduler
4. **Phase 4:** Visual enhancements (cards, tooltips, glow states)
5. **Phase 5:** Triage & recommendations
6. **Phase 6:** Insights integration & analytics
7. **Phase 7:** User overrides & learning
8. **Phase 8:** Auto-scheduling suggestions
9. **Phase 9:** Settings & polish

## Testing Considerations

- Unit tests for color assignment logic
- Integration tests with PriorityEngine, CognitionPredictor
- UI tests for color updates and animations
- Performance tests for 100+ events
- Edge cases: all-day events, recurring events, external calendar sync

## Performance

- Color analysis runs async on background queue
- Cache color results for 15 minutes
- Batch updates (analyze all events, then update UI once)
- Lazy loading of linked entities (tasks, projects)
- Debounce rapid updates (task completion → color change)

### To-dos

- [ ] Create AuroraCalendarCognitionService and CalendarColorEngine with weighted urgency scoring and color assignment logic
- [ ] Implement EventColorReason model to store color explanations and factors for each event
- [ ] Build EventCategoryDetector to classify events (deep work, admin, personal, etc.)
- [ ] Add planned vs actual duration tracking to CalendarEvent with slippage detection
- [ ] Implement ColorUpdateScheduler to refresh colors every 15 minutes and on event changes
- [ ] Update CalendarEventCard and CalendarDayCellV2 with dynamic colors, glow animations, and hover tooltips
- [ ] Build TriageAnalyzer and LightDayOptimizer for overload detection and optimization suggestions
- [ ] Add calendar insights card to Insights dashboard with urgency trends and color distribution
- [ ] Implement ColorOverrideManager for user color overrides with adaptive learning from patterns
- [ ] Create CalendarSuggestionEngine integrated with AdaptiveScheduler for optimal time placement
- [ ] Build CalendarCognitionSettingsView for configuration (sensitivity, update frequency, triage threshold)
- [ ] Integrate all components into UnifiedCalendarView, CalendarEventDrawer, and FocusOSApp startup