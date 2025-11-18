<!-- e258dab8-4116-4c1a-a23d-6298ac0b4e66 f8796299-82f0-46d9-98fa-0d9ecda5b422 -->
# Phase 9 - Adaptive Temporal Intelligence

Extends existing CognitionPredictor/DriftMonitor stack with actionable temporal intelligence: dynamic scheduling, momentum tracking, and context-aware guards.

## 1. Adaptive Scheduling Engine

### 1.1 Dynamic Reflow Service

**File:** `FocusOS/Services/AdaptiveScheduler.swift` (new)

Create service that reschedules missed/skipped focus sessions based on:

- Task urgency (CPS priority × deadline proximity)
- Energy patterns (from ARTE + CognitionPredictor forecasts)
- Calendar availability (from CalendarAvailabilityService)

Key methods:

- `reflowSchedule(skippedSession: FocusSession, modelContext: ModelContext) async -> Date?`
  - Fetches latest FocusForecast to identify next energy peak
  - Gets CPS scores for task priority
  - Finds available time slots via CalendarAvailabilityService
  - Returns optimal reschedule time with reasoning
- `notifyReflow(originalTime: Date, newTime: Date, reason: String)`
  - Triggers Smart Nudge with explanation
  - Updates FocusSession scheduledTime property (add to model)

### 1.2 EventKit Calendar Sync

**File:** `FocusOS/Services/CalendarSyncService.swift` (new)

Bi-directional sync between FocusOS focus sessions and macOS Calendar:

- Request EventKit permissions on first use
- Write FocusSessions as EKEvents to selected calendar
- Monitor calendar for external edits (EKEventStoreChangedNotification)
- Reflow internal schedule when calendar events change

Key methods:

- `requestCalendarAccess() async -> Bool`
- `syncSessionToCalendar(session: FocusSession) async throws`
- `observeCalendarChanges()` - watch for external edits
- `handleExternalEdit(event: EKEvent)` - trigger AdaptiveScheduler reflow

**Model changes:** Add `calendarEventId: String?` to FocusSession model

### 1.3 Energy Window Prediction

**File:** Extend `FocusOS/Services/CognitionPredictor.swift`

Add rolling energy pattern prediction:

- Analyze historical FocusSession completion rates by hour
- Cross-reference with ARTE state transitions
- Generate `EnergyWindow` records predicting optimal focus times

New method:

- `predictEnergyWindows(daysAhead: Int, modelContext: ModelContext) -> [EnergyWindow]`
  - Returns array of time slots with predicted energy scores (0-1)
  - Feeds into AdaptiveScheduler for reflow decisions

**New model:** `FocusOS/Models/EnergyWindow.swift`

```swift
@Model
final class EnergyWindow {
    var windowStart: Date
    var windowEnd: Date
    var predictedEnergyScore: Double // 0-1
    var confidence: Double
    var generatedAt: Date
}
```

## 2. Context Switching Guard

### 2.1 Tab Switch Interceptor

**File:** `FocusOS/Services/ContextSwitchGuard.swift` (new)

Intercepts tab switches in MainWindowView with graduated resistance:

- Monitor active FocusSession state
- Check current momentum (from DriftMonitor)
- Query ARTE emotional state
- Apply delay + prompt based on severity

Key methods:

- `shouldInterceptSwitch(from: TabIdentifier, to: TabIdentifier, session: FocusSession?) -> InterceptDecision`
  - Returns: `.allow`, `.softPrompt(delay: 1.5)`, `.strongPrompt(delay: 3.0)`
- `generatePromptMessage(context: SwitchContext) -> String`
  - ARTE-aware tone: gentle if energized, firm if fatigued

**Enum:**

```swift
enum InterceptDecision {
    case allow
    case softPrompt(delay: TimeInterval, message: String)
    case strongPrompt(delay: TimeInterval, message: String)
}
```

### 2.2 UI Integration

**File:** Modify `FocusOS/Views/MainWindowView.swift`

Hook into tab switching logic:

- Add `@State private var showSwitchGuard = false`
- Add `@State private var guardMessage = ""`
- Intercept `onChange(of: selectedTab)` to check ContextSwitchGuard
- Show overlay prompt with countdown timer if interception triggered
- Log overrides to DriftMonitor for learning

**New component:** `FocusOS/Views/Components/ContextSwitchPrompt.swift`

```swift
struct ContextSwitchPrompt: View {
    let message: String
    let delay: TimeInterval
    let onConfirm: () -> Void
    let onCancel: () -> Void
}
```

## 3. Momentum Tracker

### 3.1 Extend DriftMonitor

**File:** Modify `FocusOS/Services/DriftMonitor.swift`

Add momentum metrics as behavioral layer:

- Track session streak consistency
- Calculate completion velocity (tasks completed per focus block)
- Measure recovery rate (time between flow drops and rebounds)

New properties:

```swift
private var momentumMetrics: MomentumMetrics?
private let momentumSubject = PassthroughSubject<MomentumMetrics, Never>()

var momentumPublisher: AnyPublisher<MomentumMetrics, Never> {
    momentumSubject.eraseToAnyPublisher()
}
```

New methods:

- `calculateMomentum(modelContext: ModelContext) -> MomentumMetrics`
  - Analyzes last 7 days of FocusSessions
  - Computes streak, velocity, recovery rate
- `detectFlowDrop(currentVelocity: Double) -> Bool`
  - Returns true if velocity drops >20% from baseline
- `triggerRecoveryNudge(modelContext: ModelContext)`
  - Sends nudge via SmartNudgeService for micro-break

**New model:** `FocusOS/Models/MomentumMetrics.swift`

```swift
struct MomentumMetrics: Codable {
    let streakDays: Int
    let completionVelocity: Double // tasks per hour
    let averageRecoveryTime: TimeInterval // seconds
    let flowState: FlowState
    let calculatedAt: Date
}

enum FlowState: String, Codable {
    case highFlow      // velocity >80% of baseline
    case steadyFlow    // 50-80%
    case slowingFlow   // 20-50%
    case stalled       // <20%
}
```

### 3.2 Integration with ARTE

**File:** Modify `FocusOS/Services/ReactiveThemeManager.swift`

Feed momentum data into ARTE state detection:

- Subscribe to DriftMonitor.momentumPublisher
- Adjust emotional state based on flow state
- High momentum → bias toward "energized" state
- Stalled flow → bias toward "fatigued" state

Add method:

- `adjustStateWithMomentum(metrics: MomentumMetrics)`

### 3.3 Integration with CPS

**File:** Modify `FocusOS/Services/PriorityEngine.swift`

Use momentum to adjust priority weights:

- High momentum → boost lower-priority tasks (maintain flow)
- Stalled flow → boost high-priority tasks (reset focus)

Add method:

- `applyMomentumModifier(metrics: MomentumMetrics, modelContext: ModelContext)`

### 3.4 Momentum Dashboard

**File:** `FocusOS/Views/Insights/MomentumDashboard.swift` (new)

Visual momentum tracking in Insights tab:

- Weekly momentum curve (line chart)
- Current flow state indicator
- Streak counter
- Recovery time trends

Integrate into `FocusOS/Views/Insights/InsightsView.swift` as new card

## 4. Cross-System Orchestration

### 4.1 Startup Integration

**File:** Modify `FocusOS/FocusOSApp.swift`

Start new services in `startRitualSystemsIfNeeded()`:

```swift
if UserDefaults.standard.bool(forKey: "predictiveModeEnabled") {
    await AdaptiveScheduler.shared.start(modelContext: context)
    await CalendarSyncService.shared.start(modelContext: context)
    await ContextSwitchGuard.shared.start(modelContext: context)
}
```

### 4.2 Settings Panel

**File:** `FocusOS/Views/Settings/TemporalIntelligenceSettingsView.swift` (new)

User controls for:

- Enable/disable dynamic reflow
- Calendar sync toggle + calendar selection
- Context switch sensitivity slider (0-3 sec delay)
- Momentum tracking enable/disable

Link from `SettingsView.swift` as new section

### 4.3 Update Aurora's System Prompt

**File:** Modify `FocusOS/Services/GeminiService.swift`

Add Phase 9 temporal intelligence to system prompts:

- Adaptive scheduling capabilities
- Momentum-aware suggestions
- Context switch awareness
- Calendar sync status

## 5. Schema Updates

**File:** Modify `FocusOS/FocusOSApp.swift`

Add new models to Schema:

- `EnergyWindow.self`
- `MomentumMetrics` (if persisted as @Model instead of struct)

Add properties to existing models:

- FocusSession: `scheduledTime: Date?`, `calendarEventId: String?`, `wasRescheduled: Bool`

## File Summary

**New files (11):**

- Services/AdaptiveScheduler.swift
- Services/CalendarSyncService.swift
- Services/ContextSwitchGuard.swift
- Models/EnergyWindow.swift
- Models/MomentumMetrics.swift
- Views/Components/ContextSwitchPrompt.swift
- Views/Insights/MomentumDashboard.swift
- Views/Settings/TemporalIntelligenceSettingsView.swift

**Modified files (9):**

- Services/CognitionPredictor.swift
- Services/DriftMonitor.swift
- Services/ReactiveThemeManager.swift
- Services/PriorityEngine.swift
- Services/GeminiService.swift
- Models/FocusSession.swift
- Views/MainWindowView.swift
- Views/Insights/InsightsView.swift
- FocusOSApp.swift

## Testing Criteria

1. Skip a focus session → verify AdaptiveScheduler reschedules to next energy peak
2. Edit calendar event externally → verify FocusOS detects and reflows
3. Switch tabs during active session → verify context guard prompts with ARTE tone
4. Complete 3+ sessions in a day → verify momentum metrics calculate correctly
5. Momentum drops → verify recovery nudge triggers
6. High momentum → verify lower-priority tasks get CPS boost

### To-dos

- [ ] Create AdaptiveScheduler service with dynamic reflow logic based on CPS priority, energy forecasts, and calendar availability
- [ ] Implement CalendarSyncService with EventKit integration for bi-directional sync between FocusSessions and macOS Calendar
- [ ] Extend CognitionPredictor with energy window prediction analyzing historical completion patterns and ARTE transitions
- [ ] Create ContextSwitchGuard service to intercept tab switches with graduated resistance based on momentum and ARTE state
- [ ] Add ContextSwitchPrompt UI component and integrate into MainWindowView tab switching logic
- [ ] Extend DriftMonitor with momentum tracking: streak consistency, completion velocity, and recovery rate calculations
- [ ] Integrate momentum metrics into ReactiveThemeManager for flow-aware emotional state adjustments
- [ ] Feed momentum data into PriorityEngine to dynamically adjust task priority weights
- [ ] Create MomentumDashboard view with weekly curves, flow state indicator, and trends
- [ ] Add EnergyWindow model to schema and extend FocusSession with scheduledTime, calendarEventId, wasRescheduled properties
- [ ] Create TemporalIntelligenceSettingsView with controls for reflow, calendar sync, context guard sensitivity, and momentum tracking
- [ ] Start new services in FocusOSApp startup flow when predictiveModeEnabled
- [ ] Update Aurora's system prompts in GeminiService with temporal intelligence capabilities