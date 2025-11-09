<!-- 9e1c01b7-6e35-42ee-975d-52f79ba007fb 577c9c0a-e3f4-4689-9c70-9524796d0909 -->
# Focus Mode V2 Build Plan

## Overview

Transform the existing Focus Mode into `FocusModeViewV2` - an adaptive, minimal, emotionally aware workspace that integrates directly with CPS, ARTE, and Predictive Cognition. The design follows the same Apple-grade glass and gradient aesthetic as Tasks and Insights views.

## Architecture

**Main View:** `Cloutmate/Views/FocusMode/UnifiedFocusModeView.swift` (new)
**Components:** Modular components in `Cloutmate/Views/FocusMode/Components/`
**Services:** Extend existing `FocusSessionService`, integrate with `ReactiveThemeManager`, `CognitionPredictor`, `MemoryGraphService`

---

## Phase 1: Unified Header Zone

**File:** `Cloutmate/Views/FocusMode/Components/FocusHeaderView.swift` (new)

### Implementation Details

- **Layout Structure:**
- Title: "Focus Mode" (`.system(.title3, design: .rounded)`, `.semibold`)
- Subline: "Deep work, simplified." (`.subheadline`, `.secondary`)
- Controls row:
- Timer toggle button (Start/Pause/End states)
- "Set Objective" button (opens drawer)
- Filter pills: `Session`, `Streak`, `Stats` (horizontal scroll, similar to InsightsHeaderView)
- Aurora insight button (opens sidebar)

- **Visual Design:**
- `.glassPanel(tier: .overlay)` wrapper
- Gradient accent: `LinearGradient(colors: [.kosmicBlue.opacity(0.1), .kosmicPurple.opacity(0.05)], startPoint: .leading, endPoint: .trailing)`
- Header slides up with scroll (opacity + move edge top, similar to UnifiedTasksView header)
- Calm breathing animation when session active (subtle pulse using `GlassMotion.Duration.auroraPulse`)

- **Reference Pattern:** Follow `InsightsHeaderView.swift` and `TasksHeaderView.swift` structure

---

## Phase 2: Core Session Panel

**File:** `Cloutmate/Views/FocusMode/Components/FocusSessionPanel.swift` (new)

### Implementation Details

- **Central Timer Display:**
- Large rounded typography (`.system(size: 64, weight: .bold, design: .rounded)`)
- Responsive scaling based on window size
- Monospaced for time display (MM:SS format)
- Color shifts: kosmicBlue (normal) → kosmicPurple (active) → kosmicGreen (complete)

- **Objective Label:**
- Positioned under timer
- Format: "Current Focus: [Project / Task / Area]" or just objective text
- Links to entity if `targetObjectId` exists

- **Mini-Stats Row:**
- Elapsed Time (from `session.elapsedTime`)
- Focus Gravity % (from CPS score if linked)
- Streak Count (from `FocusSessionService.getStreakCount()`)
- Session Mood (ARTE tone from `ReactiveThemeManager.shared.currentState`)

- **Interactions:**
- Start → smooth fade into "Active" theme (`.opacity` transition, `GlassMotion.Easing.spring`)
- Pause → subtle desaturation (`.saturation(0.6)`)
- End → gradient pulse + haptic tick (`NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)`)

- **Duration Mode Toggle:**
- Quick switch between "Pomodoro" (25min) / "Custom Duration" (user-set)
- Segmented picker style

---

## Phase 3: Session Sidebar (Aurora Companion)

**File:** `Cloutmate/Views/FocusMode/Components/FocusSidebar.swift` (new)

### Implementation Details

- **Sections:**

1. **Live ARTE Monitor:**

- Current tone display (`ReactiveThemeManager.shared.currentState`)
- Adaptive gradient bar (color from `GlassColorSystem.emotionalAccent()`)
- Confidence indicator (`ReactiveThemeManager.shared.confidence`)

2. **Session Reflection:**

- Prompt: "How are you feeling right now?"
- Tap to log tone (opens quick picker: calm, focused, energized, reflective, fatigued)
- Syncs to Journal + Insights via `AdaptiveJournalService`

3. **Predictive Cognition Tips:**

- Display latest `FocusForecast` from `CognitionPredictor`
- Format: "Peak cognitive energy expected at [time]."
- Show fatigue risk if > 0.65

4. **Linked Entities:**

- Tasks, Notes, or Projects tied to this session (`session.targetObjectId`, `session.targetObjectType`)
- Display as compact cards with quick navigation

5. **End-of-Session Summary:**

- Auto-appears after 60s of inactivity (timer-based)
- Shows session stats, completion status, linked items

- **Visual:**
- `.glassPanel(tier: .contentCard)` wrapper
- kosmicGreen pulse when tone improves (subtle animation)
- Collapsible sections with chevron indicators

---

## Phase 4: Objective Drawer

**File:** `Cloutmate/Views/FocusMode/Components/FocusObjectiveDrawer.swift` (new)

### Implementation Details

- **Layout:**
- Title: "Set Focus Objective"
- Fields:
- Objective Title (TextField, required)
- Linked Project/Task (Picker with search, optional)
- Expected Duration (Picker: 15min, 30min, 45min, 1hr, 2hr, Custom)
- Priority (auto-filled via CPS if linked to object, display-only)

- **Optional Toggle:**
- "Reflect After Session" (default: true)

- **Behavior:**
- Save → calls `FocusSessionService.shared.startSession(...)`
- Aurora auto-summarizes objective for later Insight logs (via `AuroraInsightGenerator`)

- **Presentation:**
- Sheet presentation (`.sheet(isPresented:)`)
- `.spring(response: 0.5)` animation

---

## Phase 5: Analytics & Review Drawer

**File:** `Cloutmate/Views/FocusMode/Components/FocusAnalyticsDrawer.swift` (new)

### Implementation Details

- **Metrics Display:**

1. **Total Sessions:**

- Daily / Weekly counts (from `FocusSessionService.getSessionStats()`)

2. **Avg Duration per Session:**

- Calculated from completed sessions

3. **Top Focus Domains:**

- From CPS (group by `targetObjectType`)

4. **Calm vs Chaos Ratio:**

- ARTE-based (calm sessions vs fatigued/energized)

5. **Streak Timeline Graph:**

- Chart view showing streak over time (similar to Insights ritual trend chart)

6. **Predictive Drift Score:**

- From `CognitionPredictor` latest forecast
- Display `focusStability` and `fatigueRisk`

- **Integration:**
- Feeds Insights Dashboard (via `AnalyticsSnapshot`)
- Links to Focus Gravity visual (navigation to `FocusGravityView`)

- **Presentation:**
- Drawer/sheet with scrollable content
- Export option (PDF/Markdown)

---

## Phase 6: ARTE & Cognition Integration

### ARTE Tone Sync

**Files Modified:** `FocusSessionPanel.swift`, `FocusSidebar.swift`

- **Real-time Tone Influence:**
- Background color shift based on `ReactiveThemeManager.shared.currentState`
- Use `GlassColorSystem.emotionalAccent()` for gradient colors
- Smooth transitions via `ThemeInterpolator` (already handles transitions)

- **Mood Log Prompts:**
- Sync to Journal via `AdaptiveJournalService.logTone(...)`
- Update Insights via `AnalyticsSnapshot` emotional data

### Predictive Cognition Integration

**Files Modified:** `FocusSessionPanel.swift`, `FocusSidebar.swift`

- **Next Optimal Session Time:**
- Display `FocusForecast.nextFocusWindowStart` if available
- Format: "Peak cognitive energy expected at [time]"

- **Fatigue/Fatigue Forecast:**
- Show `FocusForecast.fatigueRisk` as warning indicator
- Display `FocusForecast.focusStability` as confidence meter

### Focus Gravity Hook

**Files Modified:** `FocusSessionService.swift`

- **Live Priority Score Updates:**
- Adjust CPS scores based on session engagement
- Update `PriorityEngine` when session completes
- Link session to CPS via `targetObjectId`

---

## Phase 7: Accessibility & Calm Mode

**Files Modified:** All component files

### Accessibility Features

- **Large Readable Fonts:**
- Use `.dynamicTypeSize(...)` for timer display
- Minimum font size: 24pt for timer

- **Reduce Motion:**
- Disable timer pulse when `accessibilityReduceMotion` is true
- Keep fade transitions (less jarring)
- Check `@Environment(\.accessibilityReduceMotion)`

- **VoiceOver:**
- "Session active for X minutes" announcements
- Timer updates announced every minute (not every second)
- Use `.accessibilityLabel()` and `.accessibilityValue()`

### Calm Mode

- **Visual:**
- Mutes colors (reduce saturation to 0.4)
- Adds breathing dot indicator (animated circle, 3s pulse)
- Removes gradient overlays

- **Toggle:**
- Settings preference: `UserDefaults.standard.bool(forKey: "focusCalmModeEnabled")`

---

## Phase 8: Motion & Feedback

### Animation Specifications

| Action | Animation | Feedback |
|--------|-----------|----------|
| Start Session | `.GlassMotion.Easing.spring` + `.opacity` fade | Gentle pulse + haptic tick |
| Pause | `.opacity(0.6)` fade | Soft dim |
| End | Gradient sweep (`.linearGradient` animation) | "Session Complete" toast |
| Drawer open | `.spring(response: 0.5)` | Smooth slide |
| Tone log | `.floatLift()` modifier | Minor depth shift |

### Haptic Feedback

- Use `NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)`
- Trigger on: Start, Pause, End, Tone log

---

## Phase 9: Design Tokens

### Token Values

| Token | Value |
|-------|-------|
| Corner Radius | 12pt (consistent with existing) |
| Font | SF Pro Rounded / Inter (`.system(..., design: .rounded)`) |
| Primary Gradient | kosmicBlue → kosmicPurple |
| Secondary Gradient | kosmicGreen → kosmicPurple |
| Blur | `.ultraThinMaterial` (via GlassPanel) |
| Animation | `GlassMotion.Easing.spring` |
| Color System | ARTE adaptive palette (via `GlassColorSystem`) |

---

## Phase 10: Implementation Files

### New Files

1. `Cloutmate/Views/FocusMode/UnifiedFocusModeView.swift`

- Main container view
- Orchestrates header, panel, sidebar
- Manages session state

2. `Cloutmate/Views/FocusMode/Components/FocusHeaderView.swift`

- Header component with title, controls, filters

3. `Cloutmate/Views/FocusMode/Components/FocusSessionPanel.swift`

- Central timer and session display

4. `Cloutmate/Views/FocusMode/Components/FocusSidebar.swift`

- Aurora companion sidebar

5. `Cloutmate/Views/FocusMode/Components/FocusObjectiveDrawer.swift`

- Objective setting drawer

6. `Cloutmate/Views/FocusMode/Components/FocusAnalyticsDrawer.swift`

- Analytics and review drawer

### Modified Files

1. `Cloutmate/Services/FocusSessionService.swift`

- Add `getStreakCount()` method
- Add predictive + ARTE hooks
- Update CPS scores on session completion

2. `Cloutmate/Services/CognitionPredictor.swift`

- Ensure `FocusForecast` includes session context
- Add method to get latest forecast for display

3. `Cloutmate/Services/MemoryGraphService.swift`

- Add method to link FocusSession to MemoryNode
- Store session relationships

4. `Cloutmate/Extensions/Notification+Names.swift`

- Add `.focusSessionStarted`
- Add `.focusSessionEnded`

5. `Cloutmate/Views/MainWindowView.swift`

- Update tab routing to use `UnifiedFocusModeView` instead of `FocusModeView`

---

## Testing Checklist

- [ ] Session start/pause/resume accuracy
- [ ] Objective linkage to Projects/Tasks
- [ ] ARTE tone and gradient sync (real-time updates)
- [ ] Predictive fatigue forecast updates
- [ ] Streak + analytics data accuracy
- [ ] Calm Mode rendering (muted colors, breathing dot)
- [ ] Reduce Motion compliance (no pulse, fade only)
- [ ] VoiceOver and keyboard navigation verified
- [ ] Memory graph linking works
- [ ] Drawer animations smooth
- [ ] Haptic feedback triggers correctly

---

## Integration Points

1. **CPS Integration:** Link sessions to priority items, update scores
2. **ARTE Integration:** Real-time emotional state display, mood logging
3. **Predictive Cognition:** Display forecasts, fatigue warnings
4. **Memory Graph:** Store session links for later recall
5. **Insights Dashboard:** Feed session data to analytics
6. **Focus Gravity:** Update priority scores based on engagement

---

## Emotional Identity

Focus Mode V2 should feel like entering silence — clarity through calm light. No clutter, no friction, only intention.

> "Begin. Stay. Finish — softly."

### To-dos

- [ ] Create FocusHeaderView component with title, subline, timer controls, filter pills, and Aurora insight button. Implement scroll-based header fade/slide animation.
- [ ] Create FocusSessionPanel component with central timer display, objective label, mini-stats row, and session state interactions (start/pause/end animations).
- [ ] Create FocusSidebar component with Live ARTE Monitor, Session Reflection, Predictive Cognition Tips, Linked Entities, and End-of-Session Summary sections.
- [ ] Create FocusObjectiveDrawer component with objective title field, linked project/task picker, duration selector, and priority display. Integrate with FocusSessionService.
- [ ] Create FocusAnalyticsDrawer component displaying total sessions, avg duration, top focus domains, calm vs chaos ratio, streak timeline graph, and predictive drift score.
- [ ] Create UnifiedFocusModeView as main container orchestrating header, panel, and sidebar. Manage session state and coordinate component interactions.
- [ ] Extend FocusSessionService with getStreakCount(), ARTE integration hooks, and CPS score update methods. Add predictive cognition hooks.
- [ ] Add .focusSessionStarted and .focusSessionEnded notification names to Notification+Names.swift. Update FocusSessionService to post these notifications.
- [ ] Add MemoryGraphService method to link FocusSession to MemoryNode. Store session relationships for later recall.
- [ ] Implement accessibility features (large fonts, reduce motion support, VoiceOver) and Calm Mode (muted colors, breathing dot indicator).
- [ ] Update MainWindowView to route Focus Mode tab to UnifiedFocusModeView instead of FocusModeView.
- [ ] Test all functionality: session lifecycle, ARTE sync, predictive forecasts, analytics accuracy, accessibility, and calm mode rendering.