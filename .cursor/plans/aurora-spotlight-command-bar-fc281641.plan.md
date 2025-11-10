<!-- fc281641-84e5-4aa3-bdb7-a146151711fa 38aa70b1-3cc8-42a8-a25c-ed36f4822053 -->
# Aurora Spotlight — Quick Access Overlay Implementation Plan

## Overview

Transform the existing `AuroraSpotlightView.swift` from a chat interface into a command bar overlay that interprets user input as commands, questions, or searches and routes them instantly to appropriate services.

## Key Changes

### 1. Core View Transformation (`AuroraSpotlightView.swift`)

- Replace chat message area with command-focused UI
- Add header with "Aurora Spotlight" label and kosmic gradient underline
- Implement main search field (rounded capsule, `.ultraThinMaterial` background)
- Add suggestions list below input field
- Remove chat bubbles, keep only execution confirmations
- Add backdrop overlay (dimmed kosmic overlay with opacity transition)

### 2. Intent Parsing & Routing (`SpotlightCommandParser.swift` - NEW)

Create new service to parse user input and determine intent type:

- **Execution**: "Create a task", "Start Focus Mode", "Open Calendar" → `AIActionRouter`
- **Reflection**: "What's my current focus energy?", "How was this week?" → `AIReflectionService`
- **Navigation**: "Go to Projects", "Open Insights tab" → Tab switching via NotificationCenter
- **Data Search**: "Find all rituals this week" → `WorkspaceObjectSearchService`
- **Memory Query**: "When did I last mention CalmCash?" → `MemoryGraphService`

Leverage existing `CoreResponseService.detectExecutionIntent()` and `detectReflectionIntent()` methods.

### 3. Suggestions System (`SpotlightSuggestionsList.swift` - NEW)

Real-time adaptive suggestions pulling from:

- Recent tasks (`TaskService` / SwiftData queries)
- Common Aurora commands ("start ritual", "focus session", "reflect today")
- Global navigation routes (TabIdentifier cases)
- AI query templates ("summarize my week", "how's my focus?")

Sort by confidence using simple text matching initially (can enhance with `AIIntentRankingEngine` later).

### 4. Result Feedback (`SpotlightResultToast.swift` - NEW)

Glass blur toast component displaying execution confirmations:

- Shows inline confirmation ("Created task", "Scheduled event", "Found insight")
- Uses kosmicGreen accent with fade-out (2.5s)
- Positioned above input field

### 5. State Management Updates

Add to `AuroraSpotlightView`:

- `@State isVisible` - Controls overlay visibility
- `@State query` - Current user input
- `@State suggestions` - Live predictions array
- `@State feedbackMessage` - Last command result
- `@FocusState` - Spotlight input field focus on open

### 6. Visual Design Implementation

- Background: `kosmicBlack.opacity(0.45)` blur overlay
- Field: Glass capsule with kosmicGradient border (blue/purple gradient)
- Text: `.system(.title3, design: .rounded)`
- Animations: `.easeInOut(duration: 0.25)` for open/close
- Entry pulse: kosmicGradient shimmer on wake
- ARTE-tone glow on focus (adapts to emotional state from `GlassColorSystem`)

### 7. Keyboard Shortcut Integration

- Already exists in `CloutmateApp.swift` (Cmd+Shift+A) - verify it works
- Add ESC handler to close Spotlight (already exists in current view)
- Ensure input field auto-focuses on open

### 8. Integration Points

**Modified Files:**

- `AuroraSpotlightView.swift` - Complete redesign
- `AuroraSpotlightWindowController.swift` - May need size adjustments for new layout
- `MainWindowView.swift` - No changes needed (overlay handled by window controller)

**New Files:**

- `SpotlightCommandParser.swift` - Intent detection and routing
- `SpotlightResultToast.swift` - Feedback toast component
- `SpotlightSuggestionsList.swift` - Suggestions UI component

**Service Integration:**

- `AIActionRouter.swift` - Already handles execution actions
- `AIReflectionService.swift` - Already handles reflection queries
- `WorkspaceObjectSearchService.swift` - Already handles data search
- `MemoryGraphService.swift` - Already handles memory queries
- `FocusRitualManager.swift` - For ritual commands

### 9. Action Persistence

Actions executed via Spotlight automatically log to AI Assistant tab:

- Use existing `AIAssistantViewModel` to append messages
- Create user message with command text
- Create assistant message with execution confirmation

### 10. Example Flow Implementation

1. User presses Cmd+Shift+A → Overlay appears, input focused
2. User types "Start morning ritual"
3. `SpotlightCommandParser` detects Ritual Command
4. Routes to `FocusRitualManager.startRitual()`
5. Shows toast: "☀️ Morning Ritual started"
6. Closes Spotlight automatically
7. Logs action to AI Assistant conversation

## Implementation Order

1. Create `SpotlightCommandParser.swift` with intent detection
2. Create `SpotlightResultToast.swift` component
3. Create `SpotlightSuggestionsList.swift` component
4. Redesign `AuroraSpotlightView.swift` with new layout
5. Integrate routing to existing services
6. Add ARTE emotional state gradient adaptation
7. Test keyboard shortcuts and focus behavior
8. Verify action persistence to AI Assistant

## Notes

- NavigationFlowCoordinator doesn't exist - use NotificationCenter `.switchTab` notifications instead
- AIIntentRankingEngine doesn't exist - use simple text matching for suggestions initially
- Keep existing window controller approach (floating panel)
- Maintain existing conversation persistence mechanism

### To-dos

- [ ] Create SpotlightCommandParser.swift with intent detection (execution, reflection, navigation, search, memory)
- [ ] Create SpotlightResultToast.swift component with glass blur style and kosmicGreen accent
- [ ] Create SpotlightSuggestionsList.swift component pulling from tasks, commands, navigation routes, and AI queries
- [ ] Redesign AuroraSpotlightView.swift with command bar layout, header, input field, suggestions, and backdrop
- [ ] Integrate command parser routing to AIActionRouter, AIReflectionService, WorkspaceObjectSearchService, MemoryGraphService, and FocusRitualManager
- [ ] Add ARTE emotional state gradient adaptation to input field glow based on GlassColorSystem emotional state
- [ ] Ensure actions executed via Spotlight log to AI Assistant tab automatically
- [ ] Verify Cmd+Shift+A opens Spotlight, ESC closes it, and input field auto-focuses