<!-- e5793c5d-9850-4d97-9ff3-3320e787000f 2c93910b-3622-47fd-b1b5-5436d550268c -->
# AI Assistant V2 Redesign Plan

## Overview

Transform the AI Assistant view to match the V2 design language used in Tasks, Calendar, and Projects while preserving all existing functionality. The redesign emphasizes calm hierarchy, smooth animations, and the glass design system.

## Current State Analysis

**AIAssistantView.swift** (current):

- HSplitView with conversations sidebar + main chat area
- Toolbar with voice input, save to draft, new conversation
- Core capabilities toolbar (create task, project, note, etc.)
- Platform selector in input area
- Voice recording UI with waveform indicator
- Message composer with attachments
- Conversation management (rename, delete, pin, export)

**UnifiedAIAssistantView.swift** (exists but may be incomplete):

- Component-based architecture
- ARTE integration
- Uses GlassPanel components

**V2 Design Patterns** (from Tasks/Calendar/Projects):

- Header zones with GlassPanel(.overlay) backgrounds
- Scroll fade effects
- GlassCard components
- Smooth spring animations
- Pill-style controls
- Clean typography with `.system(.title3, design: .rounded)`

## Phase 1: Header Zone Redesign

### 1.1 Create AIAssistantHeaderView Component

**File:** `FocusOS/Views/AIAssistant/Components/AIAssistantHeaderView.swift` (new)

**Header Structure:**

- Left: "Aurora" title with `.system(.title3, design: .rounded)` bold font
- Center: Status indicator (optional - shows current activity)
- Right: Action buttons:
- Search button (GlassButton, iconOnly style) - opens spotlight
- New conversation button (GlassButton, iconOnly style)
- Settings button (GlassButton, iconOnly style) - opens preferences

**Visual Design:**

- Background: `GlassPanel(tier: .overlay)` with soft blur
- Padding: `.horizontal(20)` and `.vertical(16)` matching Calendar/Tasks headers
- Smooth fade on scroll: `.move(edge: .top).combined(with: .opacity)` transition
- Gradient title text: kosmicBlue → kosmicPurple (matching Calendar)

**Integration:**

- Replace current toolbar placement with header zone
- Add scroll detection for fade effect
- Use `@State private var headerOpacity: Double = 1.0`

### 1.2 Update Main View Structure

**File:** `FocusOS/Views/AIAssistant/AIAssistantView.swift`

- Add header zone at top of main chat area
- Move toolbar actions to header
- Keep voice input, save to draft in header (or move to toolbar below)
- Add scroll offset tracking for header fade

## Phase 2: Sidebar Redesign

### 2.1 Enhance Conversations Sidebar

**File:** `FocusOS/Views/AIAssistant/Components/AIAssistantSidebar.swift` (create or enhance)

**Header Section:**

- "Conversations" title with `.system(.headline, design: .rounded)`
- Filter/search bar with GlassPanel background
- Reflection panel (if 5+ conversations) with GlassCard styling

**Conversation Cards:**

- Replace current ConversationRow with GlassCard-based design
- Use `GlassPanel(tier: .contentCard, cornerRadius: 12)`
- Hover effects: `.floatLift()` modifier
- Selected state: kosmicBlue accent border
- Pinned conversations: subtle kosmicBlue background tint

**Visual Enhancements:**

- Smooth transitions: `GlassMotion.Easing.spring`
- Card spacing: 12pt between cards
- Empty state: ContentUnavailableView with calm messaging

### 2.2 Add Scroll Fade to Sidebar Header

- Implement scroll detection
- Fade header on scroll (matching main header pattern)
- Use `.opacity(headerOpacity)` modifier

## Phase 3: Core Capabilities Toolbar Redesign

### 3.1 Redesign Toolbar as Glass Panel

**File:** `FocusOS/Views/AIAssistant/Components/AIAssistantToolbar.swift` (create or enhance)

**Current Location:** Between conversation pane and input area

**New Design:**

- Background: `GlassPanel(tier: .overlay)` with `.ultraThinMaterial`
- Pill-style buttons using GlassButton with iconOnly style
- Smooth hover animations: scale + opacity changes
- Usage-based ordering (already implemented via ToolbarUsageTracker)
- Micro-feedback animations: `.symbolEffect(.pulse)` on action

**Visual Details:**

- Button size: 32x32pt (matching Calendar arrow buttons)
- Spacing: 12pt between buttons
- Tint color: Dynamic based on current activity (via ArteTintManager)
- Padding: `.horizontal(16)` and `.vertical(12)`

### 3.2 Platform Selector Redesign

**Current:** Segmented control in input area

**New Design:**

- Move to toolbar area (above or below core capabilities)
- Pill-style toggle matching CalendarViewToggle pattern
- Use GlassPanel background with `.overlay` tier
- Selected state: kosmicBlue accent glow
- Smooth transitions between selections

**Alternative:** Keep in input area but style as pill toggle

## Phase 4: Message Composer Enhancement

### 4.1 Redesign Input Area

**File:** `FocusOS/Views/AIAssistant/Components/AIMessageComposer.swift` (create or enhance)

**Visual Design:**

- Background: `GlassPanel(tier: .contentCard)` for input container
- Text field: Clean border with kosmicBlue accent on focus
- Attachment button: GlassButton with iconOnly style
- Send button: GlassButton with kosmicBlue tint when enabled

**Voice Recording Indicator:**

- Red background with GlassPanel styling
- Animated waveform icon
- Cancel/Done buttons as GlassButton components
- Smooth slide-in animation

**Platform Selector:**

- If kept in input area, style as pill toggle
- Use GlassPanel background
- Match Calendar toggle design

### 4.2 Add Contextual Hints

**Current:** "You can @mention a project or attach a doc"

**Enhancement:**

- Style as subtle caption text
- Fade in/out based on input state
- Use `.transition(.opacity)` for smooth appearance

## Phase 5: Conversation Pane Enhancements

### 5.1 Message Bubbles

**File:** `FocusOS/Views/AIAssistant/Components/MessageBubble.swift` (enhance if needed)

**Visual Enhancements:**

- Use GlassPanel for message containers (optional - may be too heavy)
- Smooth fade-in animations for new messages
- Hover effects on action buttons
- Clean spacing and typography

### 5.2 Welcome View

**Current:** Simple VStack with sparkles icon

**Enhancement:**

- Add GlassPanel background (subtle)
- Enhance gradient on icon
- Add subtle animation to sparkles icon
- Match typography to header style

### 5.3 Thinking Indicator & Idle Indicator

**Enhancement:**

- Ensure smooth animations
- Use GlassMotion spring animations
- Match ARTE tint colors

## Phase 6: Animation & Motion Polish

### 6.1 Scroll Animations

**Implementation:**

- Add `@State private var scrollOffset: CGFloat = 0`
- Track scroll position using `ScrollViewReader` or `GeometryReader`
- Fade header: `headerOpacity = max(0, 1 - scrollOffset / 100)`
- Smooth transitions: `GlassMotion.Easing.spring`

### 6.2 State Transitions

**Conversation Loading:**

- Smooth fade when switching conversations
- Loading indicator with spring animation

**Message Sending:**

- Smooth scroll to bottom
- Subtle scale animation on send button press

**Voice Recording:**

- Smooth slide-in for recording indicator
- Animated waveform icon

### 6.3 Hover Effects

**Apply to:**

- Conversation cards: `.floatLift()`
- Toolbar buttons: Scale + opacity
- Action buttons: Subtle scale

## Phase 7: Accessibility & Integration

### 7.1 Keyboard Navigation

**Shortcuts:**

- `⌘K` or `⌘⇧A`: Open spotlight (already implemented)
- `⌘N`: New conversation
- `⌘S`: Save to draft
- `⌘R`: Toggle voice recording
- Arrow keys: Navigate conversations (future)

### 7.2 Reduce Motion Support

**Implementation:**

- Check `@Environment(\.accessibilityReduceMotion)`
- Use fade-only transitions when enabled
- Disable hover scale effects in calm mode

### 7.3 ARTE Integration

**Current:** UnifiedAIAssistantView has ARTE gradient backgrounds

**Enhancement:**

- Apply subtle ARTE gradient to conversation pane background
- Match emotional state colors
- Use `ReactiveThemeManager.shared` for state

## Phase 8: Component Extraction

### 8.1 Extract Reusable Components

**Create:**

- `AIAssistantHeaderView.swift` - Header zone
- `AIAssistantSidebar.swift` - Conversations sidebar (may already exist)
- `AIAssistantToolbar.swift` - Core capabilities toolbar (may already exist)
- `AIMessageComposer.swift` - Input area (may already exist)
- `ConversationCardV2.swift` - Redesigned conversation row

**Benefits:**

- Cleaner code organization
- Easier to test
- Matches V2 component pattern

## Implementation Details

### Key Files to Create/Modify

**New Components:**

- `FocusOS/Views/AIAssistant/Components/AIAssistantHeaderView.swift`
- `FocusOS/Views/AIAssistant/Components/ConversationCardV2.swift`
- `FocusOS/Views/AIAssistant/Components/PlatformToggle.swift` (if moving platform selector)

**Modify:**

- `FocusOS/Views/AIAssistant/AIAssistantView.swift` - Main view structure
- `FocusOS/Views/AIAssistant/Components/AIAssistantSidebar.swift` - Enhance styling
- `FocusOS/Views/AIAssistant/Components/AIAssistantToolbar.swift` - Enhance styling
- `FocusOS/Views/AIAssistant/Components/AIMessageComposer.swift` - Enhance styling

### Design System Integration

**Use:**

- `GlassPanel` for all card/panel backgrounds
- `GlassButton` for all interactive buttons
- `GlassMotion.Easing.spring` for all animations
- `.kosmicBlue`, `.kosmicPurple` for accents
- `.system(.title3, design: .rounded)` for headers
- `.floatLift()` modifier for hover effects

### Color & Typography

**Headers:**

- Font: `.system(.title3, design: .rounded)` bold
- Color: Gradient (kosmicBlue → kosmicPurple)

**Body Text:**

- Font: `.system(.body, design: .rounded)`
- Color: `.primary` / `.secondary`

**Captions:**

- Font: `.caption`
- Color: `.secondary` with opacity

## Testing Checklist

- [ ] Header scroll fade works correctly
- [ ] All toolbar buttons functional
- [ ] Voice recording UI appears/disappears smoothly
- [ ] Platform selector works and looks good
- [ ] Conversation cards display correctly
- [ ] Hover effects work on all interactive elements
- [ ] Keyboard shortcuts work
- [ ] Reduce motion is respected
- [ ] ARTE gradients apply correctly
- [ ] All existing functionality preserved

## Migration Strategy

1. **Phase 1-2:** Create new header and sidebar components alongside existing code
2. **Phase 3-4:** Enhance toolbar and composer incrementally
3. **Phase 5-6:** Polish animations and visual details
4. **Phase 7-8:** Add accessibility and extract components
5. **Final:** Replace old code with new components, test thoroughly

## Notes

- Preserve all existing functionality (voice input, draft export, conversation management)
- Maintain backward compatibility with existing conversations
- Use existing services (VoiceTranscriptionService, ToolbarUsageTracker, ArteTintManager)
- Follow V2 design patterns but adapt to AI Assistant's unique needs
- Consider keeping UnifiedAIAssistantView as alternative or merging best parts

### To-dos

- [ ] Create AIAssistantHeaderView component with GlassPanel background, gradient title, and action buttons (search, new chat, settings)
- [ ] Enhance conversations sidebar with GlassCard-based conversation rows, scroll fade effect, and improved hover states
- [ ] Redesign core capabilities toolbar with GlassPanel background, pill-style buttons, and smooth animations
- [ ] Create PlatformToggle component matching Calendar toggle style, move to appropriate location
- [ ] Redesign message composer with GlassPanel styling, improved voice recording UI, and clean input field design
- [ ] Implement scroll offset tracking and header fade effects matching Calendar/Tasks V2 patterns
- [ ] Apply GlassMotion spring animations to all state transitions, hover effects, and interactions
- [ ] Add keyboard shortcuts, reduce motion support, and VoiceOver labels for all new components