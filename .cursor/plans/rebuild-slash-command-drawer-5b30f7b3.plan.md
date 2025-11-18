<!-- 5b30f7b3-e533-49e5-9a2d-88a45b664e18 dd5e834a-54f8-482a-a7b1-013a9e7874cc -->
# Hashtag Topic Linking Drawer Implementation

## Overview

Create a "#" drawer that shows content items (Posts, Notes, Projects, Artifacts) tagged with matching hashtags. When user types "#", the drawer displays content items with matching tags. Selecting an item links it for Aurora context (like @mentions).

## Phase 1: Extend WorkspaceObjectSearchService

**File**: `FocusOS/Services/WorkspaceObjectSearchService.swift`

Add `searchByHashtag` method that:

- Searches Posts, Notes, Projects, and Artifacts by their `.tags: [String]` arrays
- Matches hashtag query against tag arrays (case-insensitive, partial match)
- Returns `[WorkspaceObjectResult]` with content items that have matching tags
- Includes match score based on tag match quality
- Searches all four content types: Posts, Notes, Projects, Artifacts

**Implementation Pattern**:

- Similar to existing `search` method but filters by `.tags.contains()` instead of title/text
- Check `project.tags`, `note.tags`, `post.tags`, `artifact.tags` arrays
- Match score: exact tag match = 1.0, partial match = 0.7, contains = 0.5

## Phase 2: Create HashtagDrawerView Component

**File**: `FocusOS/Views/AIAssistant/Components/HashtagDrawerView.swift` (NEW)

Create component matching `MentionDrawerView` design:

- Header: "#" icon + "Topic Linking" title (subtle, V2 polished)
- Content: Scrollable list of `WorkspaceObjectResult` items
- Row design: Same compact style as MentionDrawerView (28x28 icon circle, 14pt title, 11pt subtitle, type badge, chevron)
- Grouping: Group by ObjectType with collapsible sections (like MentionDrawerView when no tab filter)
- Styling: Uses `GlassColorSystem`, Aurora shimmer header, same padding/spacing as other drawers
- Height: Fixed 400px, edge-to-edge width

**Parameters**:

- `results: [WorkspaceObjectResult]`
- `selectedIndex: Int`
- `onSelect: (WorkspaceObjectResult) -> Void`
- `arteGradientColors: [Color]`

## Phase 3: Add "#" Detection to MentionInputField

**File**: `FocusOS/Views/Components/MentionInputField.swift`

Add hashtag detection logic (similar to "/" and "@" detection):

- In `handleTextChange`, check for "#" after checking for "/" but before "@"
- Track `currentHashtag: String?` and `currentHashtagRange: NSRange?`
- Track `showHashtagAutocomplete: Bool` and `hashtagSelectedIndex: Int`
- Track `hashtagResults: [WorkspaceObjectResult]`
- When "#" is detected:
  - Extract text after "#" (until space/newline)
  - Call `WorkspaceObjectSearchService.shared.searchByHashtag(query:afterHash, modelContext:)`
  - Show/hide drawer based on results
  - Hide mention autocomplete when hashtag autocomplete is active
- Add debounced search (200ms) like mentions
- Handle keyboard navigation (arrows, Enter, Esc)

**State Variables**:

```swift
@State private var showHashtagAutocomplete = false
@State private var hashtagResults: [WorkspaceObjectResult] = []
@State private var hashtagSelectedIndex = 0
@State private var currentHashtag: String? = nil
@State private var currentHashtagRange: NSRange? = nil
```

**Update `onAutocompleteVisibilityChanged` callback** to include hashtag state:

- Add `Bool` parameter for `showHashtagAutocomplete`
- Add `[WorkspaceObjectResult]` parameter for `hashtagResults`
- Add `Int` parameter for `hashtagSelectedIndex`

## Phase 4: Add Hashtag State to AuroraChatContainer

**File**: `FocusOS/Views/AIAssistant/AuroraChatContainer.swift`

Add hashtag autocomplete state:

```swift
@State private var showHashtagAutocomplete = false
@State private var hashtagResults: [WorkspaceObjectResult] = []
@State private var hashtagSelectedIndex = 0
```

**Update `AuroraChatInputBar` callback** in `composer` section:

- Extend `onAutocompleteVisibilityChanged` to receive hashtag parameters
- Update state when hashtag autocomplete visibility changes

**Handle hashtag selection**:

- When hashtag result is selected, link it for Aurora context
- Similar to how mention results are handled (add to context labels or linked context)
- Post notification: `NSNotification.Name("HashtagAutocompleteSelect")`

## Phase 5: Integrate HashtagDrawerView

**File**: `FocusOS/Views/AIAssistant/AuroraChatContainer.swift`

In `conversationScroll` view:

- Add `HashtagDrawerView` docked to bottom (edge-to-edge), same as MentionDrawerView and SlashCommandDrawerView
- Position: After mention drawer, before slash drawer (priority order: Mention > Hashtag > Slash)
- Show when `showHashtagAutocomplete && !hashtagResults.isEmpty`
- Use same transition: `.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95))`
- Use same animation: `.spring(response: 0.3, dampingFraction: 0.8)`
- Welcome view fades when hashtag drawer is visible

**Order of drawer priority** (only one shows at a time):

1. Mention drawer (if `showMentionAutocomplete`)
2. Hashtag drawer (if `showHashtagAutocomplete`)
3. Slash drawer (if `showSlashAutocomplete`)

## Phase 6: Handle Hashtag Selection & Context Linking

**File**: `FocusOS/Views/AIAssistant/AuroraChatContainer.swift`

**When hashtag result is selected**:

- Post notification: `NSNotification.Name("HashtagAutocompleteSelect")` with `WorkspaceObjectResult`
- Remove "#hashtag" text from input (similar to slash command removal)
- Link the selected content item for Aurora context:
  - Add to `attachedContextLabels` or use existing context linking mechanism
  - Store linked content ID in appropriate array (`attachedProjects`, `attachedTasks`, etc. based on ObjectType)
- Hide hashtag drawer
- Show toast notification: "Linked to [content title]"

**Object Type Handling**:

- `.project` → add to `attachedProjects`
- `.task` → add to `attachedTasks`
- `.note` → handle via context labels
- `.post` → handle via context labels
- `.artifact` → handle via context labels

## Implementation Notes

- Reuse existing patterns from SlashCommandDrawerView and MentionDrawerView
- Follow same V2 design system (glass colors, typography, spacing)
- Edge-to-edge width, docked to bottom, fixed 400px height
- Keyboard navigation support (arrow keys, Enter, Esc)
- Debounced search for performance (200ms)
- Only show one drawer at a time (priority order above)

### To-dos

- [ ] Update AuroraChatContainer.swift anchor logic: position drawer 10-12px above input field container, anchored to left edge of text field where `/` appears, width matches input bar (max 600px)
- [ ] Verify SlashCommandAutocompleteView.swift matches exact ARTE V2 specs: gradient background, 16px radius, blur(20px), row height 52px, hover glow rgba(93,137,255,0.4), SF Pro Rounded 14pt semibold for command, Inter 12pt 60% opacity for description
- [ ] Update SlashDrawerAnimationModifier: appear = 100ms ease-out fade + 4px upward slide, disappear = 75ms ease-in fade reverse
- [ ] Verify SlashCommand enum has all 5 commands: /tab, /project, /task, /think, /web with correct descriptions
- [ ] Ensure drawer z-index is 9999 in AuroraChatContainer.swift autocompleteDrawer view
- [ ] Test keyboard navigation (arrows, enter, esc), click outside to close, command execution replaces text and closes drawer