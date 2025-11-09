<!-- 8c910fab-e222-4718-a808-a95be62db313 9f463253-159e-441e-8973-e5a97772001d -->
# Insights V2 Redesign Implementation Plan

## Overview

Redesign Insights from tab-based navigation to a unified cognitive dashboard with adaptive three-column layout, integrating Focus Gravity, ARTE emotional states, Rituals, and Predictive Cognition into living visualizations.

---

## Phase 1: Unified Header Component

**File:** `Cloutmate/Views/Insights/Components/InsightsHeaderView.swift`

### Implementation Details

- **Title Section:**
- "Insights" using `.system(.title3, design: .rounded)`
- Subline: "Aurora's reflection of your patterns and focus"
- Gradient accent: kosmicBlue → kosmicPurple

- **Filter Controls:**
- Timeframe buttons: "Today • 7 Days • 30 Days • All Time"
- View type buttons: "Focus • Emotion • Habits • Cognition"
- Use GlassButton with `.standard` style
- Active state uses gradient background

- **Search Bar:**
- Inline TextField with placeholder: "Search focus trends, reflections…"
- `.glassPanel(tier: .contentCard)` container
- Search icon (magnifyingglass) on leading edge

- **Quick Export:**
- GlassButton with icon `square.and.arrow.up`
- Export summary as PDF or Markdown
- Menu for format selection

- **Design:**
- `.glassPanel(tier: .overlay)` container
- Smooth fade on scroll using `.opacity` transitions
- `.GlassMotion.spring` for filter button interactions

---

## Phase 2: Unified Dashboard Layout

**File:** `Cloutmate/Views/Insights/UnifiedInsightsView.swift`

### Implementation Details

- **Three-Column Adaptive Layout:**
- Use `LazyHGrid` or `HStack` with flexible columns
- Column 1: Focus & Energy (FocusAnalyticsView)
- Column 2: Emotional & Reflective (EmotionAnalyticsView)
- Column 3: Predictive & Cognitive (CognitiveForecastView)
- Each column scrolls independently with `.scrollContentBackground(.hidden)`

- **Parallax Effect:**
- Use `GeometryReader` to track scroll position
- Apply `.offset(y: scrollOffset * GlassMotion.Parallax.content)` to background layers
- Different parallax multipliers per column

- **Visual Foundation:**
- `.glassPanel(tier: .background)` backdrop
- Section titles with gradient headers:
- Focus: kosmicBlue → kosmicPurple
- Emotion: kosmicPurple → kosmicGreen
- Cognitive: kosmicBlue → kosmicPurple
- Subtle blur separation lines using `.ultraThinMaterial`

- **Integration:**
- Replace current `InsightsView` body with `UnifiedInsightsView`
- Keep existing data loading logic (`loadAnalytics()`, `currentSnapshot`)
- Pass `AnalyticsSnapshot` and `timeRange` to child components

---

## Phase 3: Focus Analytics Panel

**File:** `Cloutmate/Views/Insights/Components/FocusAnalyticsView.swift`

### Implementation Details

- **Focus Gravity Trendline:**
- Mini chart showing last 7 days
- Pull from `ProjectFocusGravityService.shared.weeklyFocusTrend()`
- Combine with `FocusSession` data from `AnalyticsSnapshot`
- Use SwiftUI `Chart` with `LineMark` and `AreaMark`
- Gradient: kosmicBlue → kosmicPurple

- **Key Metrics:**
- Average Session Duration: `FocusSessionStats.averageSessionDuration`
- Top 3 Focus Windows: Calculate from `FocusSession.startTime` hour distribution
- Display in metric cards with `.glassPanel(tier: .contentCard)`

- **Flow Heatmap:**
- Grid visualization (24 hours × 7 days)
- Color intensity based on `FocusSession` concentration per hour
- Use `heatmapColor(for:)` helper (similar to ReflectionChartView)
- Interactive: `.ripple(color: .kosmicBlue)` on tap

- **Visual:**
- GlassCard chart container with motion shadows
- `.GlassMotion.ripple` when interacting with graph nodes
- Hover effects using `.floatLift()`

- **Data Sources:**
- `AnalyticsSnapshot.focusSessionsCount`
- `FocusSessionService` for session queries
- `ProjectFocusGravityService` for gravity metrics

---

## Phase 4: Emotional Continuity Panel

**File:** `Cloutmate/Views/Insights/Components/EmotionAnalyticsView.swift`

### Implementation Details

- **Mood Distribution Wheel:**
- Visualize ARTE tone weights (Calm, Curious, Creative, Fatigued, Restless)
- Map ARTE states: Calm, Reflective (Curious), Energized (Creative), Fatigued, Focused (Restless)
- Use `PieChart` or custom `Shape` with `AngularGradient`
- Pull weights from `ToneProfileCache` or calculate from `StateTransitionHistory`

- **Weekly Sentiment Arc:**
- Gradient waveform showing daily mood evolution
- Use `AnalyticsSnapshot.emotionalSnapshot` for valence over time
- Create daily data points from `EmotionalStateDetector` history
- Animated arc transitions using `GlassMotion.spring`

- **Reflection Frequency:**
- Count Journal + Ritual entries
- Query `RitualCompletion` and `Journal` entries (if Journal model exists)
- Display as metric card

- **Aurora's Comment Card:**
- Generate contextual insights using **emotion + focus pairing logic**
- Analyze both emotional consistency and focus patterns together
- Examples:
- "You've been consistent in focus but drifting emotionally—schedule a short ritual this evening."
- "Focus sessions are strong, but emotional state is restless—try a reflective journal entry."
- "Emotional stability improved while focus dipped—consider blocking time for deep work tomorrow."
- Pairing logic:
- Compare `AnalyticsSnapshot.completionRate` (focus consistency) vs `AnalyticsSnapshot.emotionalSnapshot.valence` stability
- Detect drift: focus stable but emotion volatile → suggest ritual/reflection
- Detect imbalance: high focus + low emotion → suggest emotional grounding
- Detect alignment: both improving → celebrate momentum
- Use `AuroraInsightGenerator.shared.generateEmotionFocusInsight()` helper
- Use `AnalyticsSnapshot.emotionalTrend`, `FocusSessionStats`, and `StateTransitionHistory`

- **Visual:**
- kosmicPurple → kosmicGreen palette
- `.ultraThinMaterial` base with floating color indicators
- Animated transitions

- **Data Sources:**
- `ReactiveThemeManager.shared.currentState`
- `StateTransitionHistory` for historical states
- `AnalyticsSnapshot.emotionalSnapshot`

---

## Phase 5: Habit & Completion Panel

**File:** `Cloutmate/Views/Insights/Components/HabitMetricsView.swift`

### Implementation Details

- **Task Completion Rate:**
- Circular ring chart (progress ring)
- Use `AnalyticsSnapshot.completionRate`
- Custom `Shape` with `trim(from:to:)` for ring
- Gradient: kosmicGreen

- **Ritual Consistency:**
- Bar chart of morning/evening completion
- Use `AnalyticsSnapshot.morningRitualStreak` and `eveningRitualStreak`
- Query `RitualCompletion` for detailed breakdown
- Display as horizontal bar chart

- **Project Momentum:**
- Pulse dots showing active progress
- Query active `Project` entities with recent `Task` completions
- Visualize as animated dots with `.pulse()` effect

- **Streak Tracker:**
- Calm gradient meter
- Fades green when continuing streak
- Use `AnalyticsSnapshot.ritualCompletionRate`

- **"Good Day" Summary Banner:**
- Conditional display when both rituals and tasks complete
- Message: "Routine balanced, focus grounded."
- `.glassPanel(tier: .overlay)` with kosmicGreen accent

- **Visual:**
- kosmicGreen base gradient
- `.floatLift()` hover effect for cards
- Animated progress rings

- **Data Sources:**
- `AnalyticsSnapshot` (ritualCompletionRate, morningRitualStreak, eveningRitualStreak)
- `RitualCompletion` queries
- `Task` completion queries

---

## Phase 6: Cognitive Forecast Panel

**File:** `Cloutmate/Views/Insights/Components/CognitiveForecastView.swift`

### Implementation Details

- **Next Focus Peak:**
- Display: "Predicted tomorrow at 9:40 AM"
- Pull from `FocusForecast.nextFocusWindowStart`
- Query latest forecast: `CognitionPredictor.shared` or direct SwiftData query
- Format time using `DateFormatter`

- **Fatigue Risk Meter:**
- Traffic-light style color bar
- Use `FocusForecast.fatigueRisk` (0-1)
- Color mapping: Green (<0.3), Yellow (0.3-0.6), Red (>0.6)
- Animated progress bar

- **Drift Alerts:**
- Number of recent deviations from baseline
- Query `DriftEvent` model (if exists) or calculate from forecast accuracy
- Display count with severity indicator

- **Aurora's Advice Card:**
- Generate contextual advice from forecast data
- Example: "Your creative drive peaks at night; try shifting reflection earlier."
- Use `FocusForecast.toneRecommendation` and `energyTrend`
- `.glassPanel(tier: .contentCard)` with micro-animations

- **Forecast Confidence Graph:**
- Rolling accuracy of predictions
- Use `FocusForecast.predictionAccuracy` over time
- Line chart showing confidence trend
- Ripple effect when forecast updates live

- **Visual:**
- Blue → Purple gradient background
- `.glassPanel(tier: .contentCard)` containers
- Ripple effect on forecast updates using `.transition(.opacity)`

- **Data Sources:**
- `CognitionPredictor.shared.forecastPublisher`
- `FocusForecast` SwiftData queries
- `CognitionAnalytics` for accuracy metrics

---

## Phase 7: Intelligence Layer Integration

### Implementation Details

- **Dynamic Data Feeds:**
- Pull from `FocusSessionService`, `RitualAnalytics`, `AnalyticsEngine`
- Subscribe to `CognitionPredictor.forecastPublisher` for live updates
- Use `ReactiveThemeManager` for ARTE state

- **Daily Summaries:**
- Generate contextual summaries in `UnifiedInsightsView`
- Example: "You completed 84% of focus sessions this week. Emotional consistency improved by 12%."
- Calculate from `AnalyticsSnapshot` deltas

- **Weekly Auto-Insight:**
- Create "Reflection Capsule" entry in Journal
- Trigger on weekly review completion or manual export
- Format as Markdown summary

- **Aurora Comment Generation:**
- Helper function to generate contextual insights
- Analyze trends from `AnalyticsSnapshot`
- Return conversational, human tone

---

## Phase 8: Accessibility & Calm Mode

### Implementation Details

- **Reduce Motion:**
- Check `UIAccessibility.isReduceMotionEnabled`
- Disable parallax, keep fade transitions
- Use `.animation(nil)` when motion reduced

- **Large Data Visualizations:**
- Collapse charts into lists for easier reading
- Use `@Environment(\.accessibilityReduceMotion)` to toggle
- Provide alternative text descriptions

- **VoiceOver:**
- Add `.accessibilityLabel()` to all metrics
- Format: "Focus Gravity Trendline, showing 7 days of data"
- Group related metrics with `.accessibilityElement(children: .combine)`

- **Calm Mode:**
- Check user preference (add to Settings if needed)
- Softer color grading: reduce saturation by 30%
- Low-saturation gradients: use `.opacity(0.6)` on gradients
- Apply to all gradient backgrounds

---

## Phase 9: Motion System Integration

### Implementation Details

- **Charts:**
- Apply `.ripple(color: .kosmicBlue)` to interactive chart nodes
- Use `GlassMotion.Easing.spring` for chart animations
- Hover effects with `.floatLift()`

- **Cards:**
- All metric cards use `.floatLift()` modifier
- Shadow depth increases on hover

- **Forecast Updates:**
- Use `.transition(.opacity.combined(with: .scale(scale: 0.95)))`
- Animate with `GlassMotion.Easing.spring`

- **Section Switch:**
- Use `.transition(.move(edge: .trailing))` for view changes
- Smooth flow between filter views

---

## Design Tokens

### Implementation

- **Corner Radius:** 12pt (consistent with `GlassPanel`)
- **Primary Gradient:** `LinearGradient(colors: [.kosmicBlue, .kosmicPurple], startPoint: .leading, endPoint: .trailing)`
- **Secondary Gradient:** `LinearGradient(colors: [.kosmicGreen, .kosmicPurple], startPoint: .leading, endPoint: .trailing)`
- **Blur:** `.ultraThinMaterial` (from SwiftUI)
- **Shadow:** `Color.kosmicPurple.opacity(0.15), radius: 3`
- **Font:** `.system(.title3, design: .rounded)` for titles, `.system(.body)` for content
- **Animation:** `GlassMotion.Easing.spring` for all transitions

---

## File Structure

### New Files

1. `Cloutmate/Views/Insights/Components/InsightsHeaderView.swift`
2. `Cloutmate/Views/Insights/Components/FocusAnalyticsView.swift`
3. `Cloutmate/Views/Insights/Components/EmotionAnalyticsView.swift`
4. `Cloutmate/Views/Insights/Components/HabitMetricsView.swift`
5. `Cloutmate/Views/Insights/Components/CognitiveForecastView.swift`
6. `Cloutmate/Views/Insights/UnifiedInsightsView.swift`

### Modified Files

1. `Cloutmate/Views/Insights/InsightsView.swift` - Replace body with `UnifiedInsightsView`, keep data loading
2. `Cloutmate/Services/CognitionPredictor.swift` - Ensure `forecastPublisher` is accessible
3. `Cloutmate/Services/MemoryGraphService.swift` - Add correlation stats helper if needed

---

## Testing Checklist

- [ ] Data feeds pulling from all layers (Focus, Rituals, Journal, Projects)
- [ ] Forecast timing accurate (next focus peak displays correctly)
- [ ] Charts animate smoothly with GlassMotion
- [ ] Aurora comment cards generate properly
- [ ] Calm mode gradients render correctly (reduced saturation)
- [ ] Accessibility and VoiceOver labels verified
- [ ] Export summary (PDF/Markdown) functional
- [ ] Parallax effects work on scroll
- [ ] Filter buttons update views correctly
- [ ] Search functionality filters metrics

---

## Implementation Order

1. **Phase 1:** Create `InsightsHeaderView` with filters and search
2. **Phase 2:** Create `UnifiedInsightsView` with three-column layout
3. **Phase 3:** Implement `FocusAnalyticsView` with charts
4. **Phase 4:** Implement `EmotionAnalyticsView` with ARTE integration
5. **Phase 5:** Implement `HabitMetricsView` with ritual metrics
6. **Phase 6:** Implement `CognitiveForecastView` with predictions
7. **Phase 7:** Integrate intelligence layer and data feeds
8. **Phase 8:** Add accessibility and Calm Mode support
9. **Phase 9:** Polish motion system and animations

---

## Key Integration Points

- **AnalyticsSnapshot:** Primary data source for all metrics
- **FocusSessionService:** Focus session queries and stats
- **CognitionPredictor:** Forecast data and live updates
- **ReactiveThemeManager:** ARTE emotional state
- **RitualAnalytics:** Ritual completion metrics
- **ProjectFocusGravityService:** Focus gravity trends
- **GlassMotion:** Animation system
- **GlassPanel:** Visual foundation

### To-dos

- [ ] Create InsightsHeaderView with title, filters (timeframe/view), search bar, and export button using GlassPanel and GlassButton
- [ ] Create UnifiedInsightsView with three-column adaptive layout (Focus, Emotion, Cognitive) with parallax scrolling
- [ ] Implement FocusAnalyticsView with Focus Gravity trendline, session duration metrics, Flow Heatmap, and interactive charts
- [ ] Implement EmotionAnalyticsView with Mood Distribution Wheel, Weekly Sentiment Arc, Reflection Frequency, and Aurora comment cards
- [ ] Implement HabitMetricsView with Task Completion Rate ring, Ritual Consistency bars, Project Momentum dots, and Streak Tracker
- [ ] Implement CognitiveForecastView with Next Focus Peak, Fatigue Risk Meter, Drift Alerts, Aurora Advice Card, and Forecast Confidence Graph
- [ ] Integrate Aurora intelligence layer: dynamic data feeds, daily summaries, weekly auto-insight to Journal, and contextual comment generation
- [ ] Add accessibility support (reduce motion, VoiceOver labels, list alternatives) and Calm Mode (reduced saturation gradients)
- [ ] Apply GlassMotion animations (ripple, floatLift, spring transitions) to all interactive elements and polish motion system
- [ ] Implement export summary as PDF/Markdown with weekly reflection data, charts, and Aurora insights