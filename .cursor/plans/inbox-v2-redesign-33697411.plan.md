<!-- 33697411-605a-49ad-b16e-bf4e8584e082 a8dac4cb-70bf-45fb-a667-305e6bcdec93 -->
# Inbox V2 Redesign Implementation Plan

## Overview

Transform Inbox from a table-based list into a modern card system matching Tasks V2's design language, with Aurora-powered auto-routing and intelligent capture capabilities.

## Architecture

**New Components:**

- `InboxHeaderView.swift` - Unified header with filters, search, quick add
- `InboxCardV2.swift` - Modern card component with hover states and actions
- `InboxCaptureDrawer.swift` - Slide-in drawer for viewing/editing entries
- `QuickCaptureSheet.swift` - Multi-mode capture (text, voice, link, AI snippet)
- `UnifiedInboxView.swift` - Main view orchestrating all components

**Modified Files:**

- `InboxView.swift` - Replace table with card grid, integrate new components
- `ContextualCreateSheet.swift` - Add Inbox quick capture actions
- `Notification+Names.swift` - Add `.openInboxCapture` notification
- `InboxItem.swift` - Add optional fields: `isFlagged`, `isArchived`, `aiImported`

## Phase 1: Unified Header Zone

**File:** `FocusOS/Views/Inbox/Components/InboxHeaderView.swift`

**Implementation:**

- Title: "Inbox" using `.system(.title3, design: .rounded)`
- Subline: "Captured thoughts and inputs awaiting action"
- Filter pills: "All • Unsorted • Flagged • AI Imports • Archived" (horizontal scroll)
- Glass inline search field: "Search ideas or entries..."
- Quick Add "+" GlassButton → triggers QuickCaptureSheet
- `.glassPanel(tier: .overlay)` background
- Gradient accent: `LinearGradient(colors: [.kosmicBlue, .kosmicPurple], ...)`
- Scroll fade animation using `GeometryReader` + `offset`
- Padding: `.horizontal(20)` `.vertical(16)`

**Filter State Management:**

```swift
enum InboxFilter: String {
    case all, unsorted, flagged, aiImports, archived
}
@Binding var selectedFilter: InboxFilter
```

## Phase 2: Capture Card System

**File:** `FocusOS/Views/Inbox/Components/InboxCardV2.swift`

**Card Structure:**

- Base: `.glassPanel(tier: .contentCard, cornerRadius: 12)`
- Header: Entry type icon + timestamp
  - Icons: 📝 "text.alignleft" (Note), ✅ "checkmark.circle" (Task), 🧠 "brain.head.profile" (Idea), 🔗 "link" (Link), 🎤 "mic.fill" (Voice)
- Body: Content snippet (2-3 lines max, truncate with "...")
- Footer: Action buttons
  - "Convert →" dropdown menu (Task / Note / Draft / Project)
  - Archive button (archivebox icon)
  - Pin button (pin.fill icon, only if not pinned)

**Interactions:**

- Tap → Opens `InboxCaptureDrawer`
- Swipe left → Archive (using `DragGesture`)
- Swipe right → Quick convert menu
- Right-click → Context menu (Convert, Edit, Archive, Delete)
- Hover: `.floatLift()` + kosmicBlue glow shadow

**Visual States:**

- Active: Blue accent border
- Converted: Green accent border
- Archived: Gray, reduced opacity
- Flagged: Yellow accent dot indicator

## Phase 3: Capture Drawer

**File:** `FocusOS/Views/Inbox/Components/InboxCaptureDrawer.swift`

**Drawer Behavior:**

- Slide-in from trailing edge (350-400px width)
- `.ultraThinMaterial` background
- Backdrop overlay (tap to dismiss)
- Transition: `.move(edge: .trailing)` with `GlassMotion.Easing.modalOpen`

**Layout:**

- Header: Editable title field + Type badge (color-coded pill)
- Body: Markdown editor (for text) or transcript viewer (for voice)
- Footer: Convert action buttons + Archive button

**Aurora Integration:**

- On open, call `CoreResponseService` to analyze content
- Prompt: "Analyze this inbox entry and suggest destination: Task, Note, Draft, or Project. Return JSON: {suggestion: 'task|note|draft|project', confidence: 0.0-1.0, reasoning: 'brief explanation'}"
- Display suggestion banner: "This looks like a Task idea → Want to send to Tasks?" with confidence percentage
- Tone insight: "Creative • 80% confidence" tagline

**Auto-linking:**

- Search workspace for matching Project/Task titles (fuzzy match)
- Display "Linked Context" section if matches found
- Show related items with tap-to-navigate

## Phase 4: Quick Capture Sheet

**File:** `FocusOS/Views/Inbox/Components/QuickCaptureSheet.swift`

**Entry Modes (Tabbed Interface):**

1. **Text** - Inline TextField for instant note
2. **Voice** - Record button using `VoiceTranscriptionService.shared`

   - Visual waveform indicator
   - Start/Stop/Pause controls
   - Real-time transcript preview

3. **Link** - URL paste field

   - Auto-fetch title + preview using URL metadata
   - Display preview card

4. **AI Snippet** - Save current AI Assistant response

   - Requires active AI conversation context
   - Button: "Save to Inbox"

**UI:**

- `.glassPanel(tier: .overlay)` container
- Tab pills with icon + label
- Haptic pulse on save (`NSHapticFeedbackManager`)
- Shimmer toast: "Captured to Inbox!" (using `ShimmerEffect` modifier)
- Auto-dismiss after 2 seconds

**Save Logic:**

- Create `InboxItem` with appropriate `itemType`
- For voice: Store transcript in `content`, set `itemType = "voice"`
- For link: Store URL in `fileURL`, title in `content`, set `itemType = "url"`
- For AI snippet: Store response text in `content`, set `itemType = "text"`, mark `aiImported = true`

## Phase 5: Aurora Integration

**Auto-Routing Service:**

- Create `InboxRoutingService.swift` (or extend existing `AIActionRouter`)
- Analyze entry content using `CoreResponseService.generateResponse()`
- Classification prompt: "Classify this inbox entry. Return JSON: {type: 'task|note|draft|project', confidence: 0.0-1.0, actionVerbs: [...], emotionalTone: '...', reasoning: '...'}"
- Rules:
  - Action verbs → Task
  - Long paragraph → Note
  - Emotional tone → Journal/Note
  - Social content keywords → Draft

**Memory Graph Sync:**

- On inbox item creation, create `MemoryNode` with label "Unsorted"
- On conversion, update node label to destination type
- Link to converted item via `MemoryEdge`

**Predictive Prompts:**

- Batch analysis: If 3+ items share keywords/themes, show banner
- "Merge 3 ideas into one Draft?" with preview
- Use `MemoryGraphService` to detect semantic clusters

## Phase 6: Accessibility & Calm Mode

**Accessibility:**

- Large touch targets: 56pt minimum
- Dynamic Type support: Use `.system(.body)` with `.dynamicTypeSize(...)`
- VoiceOver labels: "Inbox entry, [type], created [time]"
- Keyboard navigation: Tab through cards, Enter to open drawer

**Calm Mode:**

- Check `UIAccessibility.isReduceMotionEnabled`
- If enabled: Use `.opacity` fade instead of `.move(edge:)` slide
- Reduce hover animations: Scale 1.0 instead of 1.01
- High contrast fallback: Use `kosmicBlue` borders instead of gradients

## Phase 7: Motion & Visual Harmony

**Animation Mapping:**

- Hover Card: `.floatLift()` modifier (already exists)
- Drawer Open: `.transition(.move(edge: .trailing))` with `GlassMotion.Easing.modalOpen`
- Save Event: `ShimmerEffect` modifier sweep
- Convert: `.ripple(color: .kosmicBlue)` modifier
- Filter Switch: `.opacity` fade with `GlassMotion.Easing.spring`

**Visual Tokens:**

- Corner Radius: 12pt (consistent with `GlassPanel`)
- Primary Gradient: `LinearGradient(colors: [.kosmicBlue, .kosmicPurple], startPoint: .leading, endPoint: .trailing)`
- Card Accent Colors:
  - Blue = active (`.kosmicBlue`)
  - Green = converted (`.kosmicGreen`)
  - Gray = archived (`.gray`)
- Typography: SF Pro Rounded (via `.system(..., design: .rounded)`)
- Shadow: `Color.kosmicPurple.opacity(0.15)`, radius 3
- Blur: `.ultraThinMaterial`
- Animation: `GlassMotion.Easing.spring`

## Integration Points

**MainWindowView.swift:**

- Add `.sheet(isPresented: $showQuickCapture)` for QuickCaptureSheet
- Add `.onReceive(.openInboxCapture)` handler

**InboxView.swift:**

- Replace `tableSection` with `LazyVGrid` of `InboxCardV2`
- Integrate `InboxHeaderView` at top
- Add drawer state: `@State private var selectedDrawerItem: InboxItem?`
- Filter logic: Extend `filteredItems` to handle new filter types

**ContextualCreateSheet.swift:**

- Add "Quick Capture" action for `.inbox` tab
- Post `.openInboxCapture` notification

**Notification+Names.swift:**

- Add: `static let openInboxCapture = Notification.Name("openInboxCapture")`

**InboxItem Model:**

- Add optional properties:
  ```swift
  var isFlagged: Bool = false
  var isArchived: Bool = false
  var aiImported: Bool = false
  ```


## Testing Checklist

- [ ] Quick Capture flows (text, voice, link, AI snippet)
- [ ] Card hover and convert actions
- [ ] Aurora auto-routing accuracy (test with sample entries)
- [ ] Drawer open/close and tone display
- [ ] Filter and search behavior
- [ ] Calm mode and reduce motion compliance
- [ ] VoiceOver labeling
- [ ] Batch conversion prompt (3+ related items)
- [ ] Swipe gestures (left = archive, right = convert)
- [ ] Memory Graph sync on create/convert

## File Structure

```
FocusOS/Views/Inbox/
├── InboxView.swift (modified)
└── Components/
    ├── InboxHeaderView.swift (new)
    ├── InboxCardV2.swift (new)
    ├── InboxCaptureDrawer.swift (new)
    ├── QuickCaptureSheet.swift (new)
    └── UnifiedInboxView.swift (new, optional wrapper)
```

## Dependencies

- Existing: `GlassPanel`, `GlassButton`, `GlassMotion`, `VoiceTranscriptionService`
- Existing: `CoreResponseService` for Aurora analysis
- Existing: `MemoryGraphService` for graph sync
- Existing: `AIActionRouter` for conversion logic

### To-dos

- [ ] Create InboxHeaderView with title, subline, filters, search bar, and quick add button
- [ ] Create InboxCardV2 component with glass panel, hover states, swipe gestures, and action buttons
- [ ] Create InboxCaptureDrawer with slide-in animation, markdown editor, and Aurora suggestion banner
- [ ] Create QuickCaptureSheet with text, voice, link, and AI snippet modes
- [ ] Implement Aurora auto-routing service and integrate with drawer and cards
- [ ] Add accessibility labels, Dynamic Type support, and Calm Mode animations
- [ ] Implement all motion effects: floatLift, ripple, shimmer, drawer transitions
- [ ] Modify InboxView to use new card grid system and integrate all components
- [ ] Add openInboxCapture notification and wire up ContextualCreateSheet
- [ ] Add isFlagged, isArchived, aiImported fields to InboxItem model