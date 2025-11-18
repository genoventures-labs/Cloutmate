<!-- 1bbe82ca-321c-4f93-987b-f6c325b6102b ed7089aa-31bf-439f-8cf7-52878391b4eb -->
# Emoji Picker System for FocusOS

## Overview

Implement a full-featured emoji picker system integrated into the Aurora chat interface, matching existing drawer patterns (MentionDrawerView, SlashCommandDrawerView) with native Apple Unicode emoji support, fuzzy search, and autocomplete.

## Phase 1: Core Files & New Components

### 1.1 Create EmojiButton.swift

**File:** `FocusOS/Views/AIAssistant/Components/EmojiButton.swift`

- Circular 26×26pt button matching AttachmentMenuView/ActionMenuView pattern
- Gradient background (kosmicBlue → kosmicPurple)
- SF Symbol: "face.smiling" (size 12, semibold)
- Hover effects and press animations
- Positioned between AttachmentMenuView and ActionMenuView in toolbar
- Callback: `onToggle: () -> Void`

### 1.2 Create EmojiService.swift

**File:** `FocusOS/Services/EmojiService.swift`

**Responsibilities:**

- Provide emoji categories using native Apple Unicode sets (CharacterProperties)
- Recent emoji storage (UserDefaults, key: "RecentEmojis", capped at 50)
- Fuzzy search (name, alias, keyword matching)
- Category lists via Apple's CharacterProperties

**APIs:**

```swift
struct EmojiCategory {
    let name: String
    let icon: String
    let emojis: [String]
}

static var shared: EmojiService
var allCategories: [EmojiCategory] { get }
var recentEmojis: [String] { get }
func recordEmojiUse(_ emoji: String)
func search(_ query: String) -> [String]
func emojis(forKeyword: String) -> [String]
```

**Implementation Notes:**

- Use `Character.properties.contains(.isEmoji)` for detection
- Use Unicode.Scalar.Properties for category detection
- Store recent emojis as [String] array in UserDefaults
- Search through emoji names/aliases (use CLDR data or built-in Unicode names)

### 1.3 Create EmojiDrawerView.swift

**File:** `FocusOS/Views/AIAssistant/Components/EmojiDrawerView.swift`

**Visual Style:**

- Match MentionDrawerView glassmorphic design
- Aurora shimmer overlay in header
- Same header pattern (icon + title)
- Search field at top (TextField with rounded background)
- Horizontal tab bar for categories:
  - Recent (clock icon)
  - Smileys (face.smiling)
  - Animals (pawprint)
  - Food (fork.knife)
  - Travel (airplane)
  - Activities (sportscourt)
  - Objects (lightbulb)
  - Symbols (number)
  - Flags (flag)

**Layout:**

- LazyVGrid: 8-10 emojis per row (adaptive)
- 36×36pt emoji cells
- Hover highlight (scale 1.1, opacity change)
- Emoji magnification preview on hover (macOS-style pop effect)
  - 0.16s spring animation
  - Scale to 1.5x, centered above emoji
  - Optional label underneath

**Props:**

```swift
let filteredKeyword: String?
let searchQuery: String
let onSelect: (String) -> Void
let arteGradientColors: [Color]
```

**Behavior:**

- Click → immediately fires `onSelect(emoji)`
- Hover → show magnifier bubble
- Search → filters emojis dynamically with debounce
- Uses filtered list if `filteredKeyword` provided, otherwise shows category list

**Search Debounce Implementation:**

- Add `@State private var debounceSearch = PassthroughSubject<String, Never>()`
- Use Combine debounce (e.g., `.debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)`)
- Add `.onChange(of: searchQuery) { newValue in debounceSearch.send(newValue) }`
- Subscribe to debounceSearch to perform actual search

## Phase 2: Chat Input Integration

### 2.1 Modify AuroraChatInputBar.swift

**File:** `FocusOS/Views/AIAssistant/Components/AuroraChatInputBar.swift`

**Changes:**

- Add `onToggleEmoji: (() -> Void)?` callback parameter
- Add `EmojiButton` to toolbar HStack (between AttachmentMenuView and ActionMenuView, line ~167)
- Ensure layout doesn't shift on show/hide

### 2.2 Modify AuroraChatContainer.swift

**File:** `FocusOS/Views/AIAssistant/AuroraChatContainer.swift`

**Add State:**

```swift
@State private var showEmojiDrawer = false
@State private var emojiFilterKeyword: String? = nil
@State private var filteredEmojis: [String] = []
@State private var emojiSearchQuery: String = ""
```

**Behavior:**

- Tapping EmojiButton toggles `showEmojiDrawer`
- **CRITICAL**: When toggling drawer, set `focusedField = .input` to prevent macOS from unfocusing the input field
- Opening EmojiDrawer closes:
  - Slash drawer (`showSlashAutocomplete = false`)
  - Mention drawer (`showMentionAutocomplete = false`)
  - Hashtag drawer (`showHashtagAutocomplete = false`)

**Rendering:**

- Add EmojiDrawerView to ZStack in `conversationScroll` (after slash drawer, line ~530)
- Same transition pattern as other drawers:
  ```swift
  .transition(.asymmetric(
      insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
      removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95))
  ))
  ```

- Frame: `width: geometry.size.width, height: drawerHeight` (same as other drawers)

**Wire Callback:**

- Pass `onToggleEmoji` to AuroraChatInputBar (line ~605)
- Implement toggle logic in container

## Phase 3: Text Input Logic

### 3.1 Modify MentionInputField.swift

**File:** `FocusOS/Views/Components/MentionInputField.swift`

**Add State:**

```swift
@State private var showEmojiAutocomplete = false
@State private var emojiResults: [String] = []
@State private var currentEmojiKeyword: String? = nil
@State private var currentEmojiRange: NSRange? = nil
```

**Add Callback:**

```swift
var onEmojiAutocompleteVisibilityChanged: ((Bool, [String], String?) -> Void)? = nil
```

**Detection Logic (in `handleTextChange`):**

- After slash/hashtag detection, before mention detection
- Pattern: `:` followed by word characters
- Cases:
  - `:` + word → open emoji autocomplete drawer
  - `:` + space → close drawer
  - When selecting emoji:
    - If `:keyword` exists → replace whole range
    - Else → insert at cursor

**Add Observer:**

```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EmojiSelected"))) { notification in
    if let emoji = notification.object as? String {
        insertEmoji(emoji)
    }
}
```

**Helper Function:**

```swift
private func insertEmoji(_ emoji: String) {
    if let range = currentEmojiRange {
        // Replace :keyword with emoji
        // Use UTF-16 safe insertion (similar to mention insertion)
    } else {
        // Insert at cursor position
    }
}
```

### 3.2 Modify MentionNSTextView.Coordinator

**File:** `FocusOS/Views/Components/MentionInputField.swift` (Coordinator class)

- Add emoji keyword detection in `textDidChange`
- Update `notifyAutocompleteVisibility` to include emoji state
- Handle emoji insertion with UTF-16 safe methods

## Phase 4: Autocomplete & Search Flow

### 4.1 Wire Emoji Autocomplete in AuroraChatContainer

**File:** `FocusOS/Views/AIAssistant/AuroraChatContainer.swift`

**On Callback (from MentionInputField):**

```swift
onEmojiAutocompleteVisibilityChanged: { visible, matchedEmojis, keyword in
    showEmojiDrawer = visible
    emojiFilterKeyword = keyword
    filteredEmojis = matchedEmojis
    // Close other drawers
    showMentionAutocomplete = false
    showHashtagAutocomplete = false
    showSlashAutocomplete = false
}
```

**EmojiDrawerView Props:**

- `filteredKeyword: emojiFilterKeyword`
- `searchQuery: emojiSearchQuery`
- `onSelect: { emoji in

NotificationCenter.default.post(

name: NSNotification.Name("EmojiSelected"),

object: emoji

)

EmojiService.shared.recordEmojiUse(emoji)

showEmojiDrawer = false

}`

## Phase 5: Final Polish

### 5.1 Close Other Drawers When Emoji Drawer Opens

- Ensure slash/mention/hashtag drawers close when emoji drawer opens
- Add logic in `onToggleEmoji` callback

### 5.2 Add Magnifier Animation

**File:** `FocusOS/Views/AIAssistant/Components/EmojiDrawerView.swift`

- Create `EmojiMagnifierView` component
- 0.16s spring scale-up animation
- Centered above emoji cell
- Optional label underneath (emoji name)

### 5.3 Performance Check

- Test with 1000+ emojis
- Verify search performance (debounce if needed)
- Test insert/replace speed
- Verify UTF-16 correctness for multi-byte emojis

## File Summary

**New Files:**

- `FocusOS/Views/AIAssistant/Components/EmojiButton.swift`
- `FocusOS/Services/EmojiService.swift`
- `FocusOS/Views/AIAssistant/Components/EmojiDrawerView.swift`

**Modified Files:**

- `FocusOS/Views/AIAssistant/Components/AuroraChatInputBar.swift`
- `FocusOS/Views/AIAssistant/AuroraChatContainer.swift`
- `FocusOS/Views/Components/MentionInputField.swift`

## Implementation Notes

1. **Emoji Detection**: Use `Character.properties.contains(.isEmoji)` for native detection
2. **Categories**: Use Unicode.Scalar.Properties or CLDR data for categorization
3. **Recent Storage**: UserDefaults array, maintain order (most recent first), cap at 50
4. **Search**: Fuzzy matching on emoji names/aliases (case-insensitive, prefix matching)
5. **UTF-16 Safety**: All text insertion must use UTF-16 safe methods (similar to mention insertion)
6. **Visual Consistency**: Match MentionDrawerView styling exactly (glassmorphic, Aurora shimmer, transitions)
7. **Drawer Priority**: Emoji drawer closes other drawers (same as slash/mention/hashtag behavior)