<!-- 50482cc2-f191-48e2-9a83-88e13ea873d8 3f76a60f-5cc3-4d6c-8d20-33f58eff141a -->
# Notes V2 Redesign Implementation Plan

## Overview

Transform the Notes view from a table-based interface to a modern card-based system with glass design, contextual organization, and Aurora AI integration. The redesign includes a unified header, note cards, detail drawer, grouping, and Focus Gravity visualization.

## Phase 1: Unified Header Zone

**File:** `FocusOS/Views/Notes/Components/NotesHeaderView.swift` (NEW)

Create header component with:

- Title: "Notes" with `.title3` rounded font, kosmic gradient foreground
- Subline: Display total active notes count and tagged count (e.g., "128 notes • 14 tagged")
- Search bar: Inline glass search with placeholder "Search thoughts or tags"
- Filter chips: Horizontal FilterChipGroup for quick filters ("All", "Tagged", "Recent", "AI Summaries", "Archived")
- Quick Add: "+" button using GlassButton spec matching Tasks view
- Background: `.glassPanel(tier: .overlay)` with scroll fade effect
- Padding: `.horizontal(20)`, `.vertical(16)`
- Motion: `.transition(.opacity.combined(with: .move(edge: .top)))`

**Dependencies:**

- Create `FilterChipGroup` component (if not exists) - wrapper around horizontal ScrollView of FilterChip components
- Ensure FilterChip supports glass styling (currently basic, may need enhancement)

## Phase 2: Note Card System

**File:** `FocusOS/Views/Notes/Components/NoteCardV2.swift` (NEW)

Create card component with:

- Base: `.glassPanel(tier: .contentCard, cornerRadius: 12)`
- Content structure:
- Title: bold `.body` font with kosmic gradient highlight if pinned
- Preview: first 3 lines of note body with blurred fade-out edge (use `.mask` with gradient)
- Metadata row: tags, last modified date, optional linked project/task icon
- Accent border: kosmicBlue gradient when active/selected (4pt width)
- Hover state: `.floatLift()` modifier with soft shadow (radius: 4)
- Pinned notes: Visual indicator (pin icon + gradient highlight)
- Interactions:
- Click → opens NoteDetailDrawer
- Right-click → context menu (Edit, Pin/Unpin, Archive, Delete)
- Hover actions: Quick edit ✎ and link 🔗 buttons fade in

**Model Update Required:**

- Add `isPinned: Bool` property to `FocusOSShared/FocusOSShared/FocusOSShared/Models/Note.swift`
- Add `pinnedAt: Date?` property for sorting

## Phase 3: Note Detail Drawer

**File:** `FocusOS/Views/Notes/Components/NoteDetailDrawer.swift` (NEW)

Create drawer component (similar to DailySnapshotDrawer pattern):

- Appears from right side (width: 400px)
- Background: `.ultraThinMaterial` with frosted glass effect
- Opens on note tap; closes on outside tap or Esc key
- Header: Note title editable inline (TextField)
- Body: Rich text editor (Markdown-compatible TextEditor)
- Footer: Tag editor + linked items section (Tasks, Projects, Artifacts)
- AI Summary Section:
- Collapsible summary card
- Uses `OllamaBridgeService.analyzeDocument()` for on-demand contextual summary
- "Regenerate" button to refresh summary
- Display emotional tone from Aurora's emotional continuity system
- Focus Gravity Sidebar:
- Small vertical gradient bar (4pt width) on left edge
- Color blend: kosmicBlue → kosmicPurple
- Indicates engagement weight (calculate from access count, update frequency)
- "Ask Aurora" button: Opens mini chat overlay contextual to this note

**Integration:**

- Connect to Aurora's Recall Layer for summary generation
- Update Memory Graph on note save (via existing MemoryNode system)

## Phase 4: Organization & Grouping

**File:** `FocusOS/Views/Notes/UnifiedNotesView.swift` (NEW - replaces NotesView.swift)

Create unified view with:

- Structure:
- NotesHeaderView at top
- Group notes by tag or creation date (toggle in header)
- Section headers: gradient text labels (kosmicBlue → kosmicPurple)
- Collapse/expand groups with smooth `.spring(duration: 0.35)` animation
- LazyVStack layout, spacing 12pt between cards
- Pinned notes appear first, separated with gradient divider
- Large empty-state card: "No notes yet — start capturing your ideas."
- Filtering logic:
- Filter by selected tags, search text, archive status
- Support "Tagged", "Recent", "AI Summaries", "Archived" quick filters

**Note Sorting:**

- Pinned notes first (by pinnedAt date)
- Then by updatedAt (most recent first)
- Within groups, maintain sort order

## Phase 5: Quick Add & Capture Flow

**File:** `FocusOS/Views/Components/ContextualCreateSheet.swift` (MODIFY)

- Ensure "New Note" action opens blank editor modal (uses same drawer UI as NoteDetailDrawer)
- Autofocus cursor to body field
- Light confetti shimmer when note is saved (use existing shimmer effect)
- Haptic pulse feedback on creation (NSHapticFeedbackManager)

**File:** `FocusOS/Extensions/Notification+Names.swift` (MODIFY)

- Add `.openNoteDetail` notification name for drawer opening

## Phase 6: Accessibility & Calm Mode

**File:** `FocusOS/Views/Notes/Components/NoteCardV2.swift` (MODIFY)

- Large tap targets (min 56pt height)
- Reduce motion → fade-only transitions (check `@Environment(\.accessibilityReduceMotion)`)
- VoiceOver labels for titles, tags, and action buttons
- Dynamic Type scaling support
- Calm mode → desaturate gradient backgrounds, reduce animation intensity (check ARTE emotional state)

**File:** `FocusOS/Views/Notes/UnifiedNotesView.swift` (MODIFY)

- Keyboard navigation:
- ↑↓ for cards
- Enter to open drawer
- ⎋ (Escape) to close drawer
- Tab for filter chips

## Phase 7: Aurora Integration

**File:** `FocusOS/Views/Notes/Components/NoteDetailDrawer.swift` (MODIFY)

- AI Summary drawer section connects to Aurora's Recall Layer
- Display emotional tone (from emotional continuity phase)
- "Ask Aurora" button opens mini chat overlay contextual to this note
- Each note entry updates Memory Graph on save:
- Create/update MemoryNode for note
- Link to related concepts/themes via tags
- Update access count and lastAccessedAt

**File:** `FocusOS/Services/OllamaBridgeService.swift` (USE EXISTING)

- Use `analyzeDocument()` method for note summarization
- Pass note content + context (linked tasks/projects) as appContext

## Implementation Order

1. **Model Updates** - Add `isPinned` and `pinnedAt` to Note model
2. **FilterChipGroup** - Create wrapper component if needed
3. **NotesHeaderView** - Build header with search and filters
4. **NoteCardV2** - Create card component with hover states
5. **NoteDetailDrawer** - Build drawer with AI summary section
6. **UnifiedNotesView** - Assemble main view with grouping
7. **ContextualCreateSheet** - Integrate new note creation
8. **Aurora Integration** - Connect AI summary and Memory Graph
9. **Accessibility** - Add keyboard nav and VoiceOver support
10. **Testing** - Verify all interactions and animations

## Design Tokens Reference

- Corner radius: 12pt
- Colors: `.kosmicBlue`, `.kosmicPurple`, `.kosmicGreen`
- Font: SF Pro Rounded / Inter (system defaults)
- Shadow: radius 2–4pt, low opacity
- Blur: `.ultraThinMaterial`
- Animation: `GlassMotion.Easing.spring`

## Files to Create

- `FocusOS/Views/Notes/Components/NotesHeaderView.swift`
- `FocusOS/Views/Notes/Components/NoteCardV2.swift`
- `FocusOS/Views/Notes/Components/NoteDetailDrawer.swift`
- `FocusOS/Views/Notes/UnifiedNotesView.swift`
- `FocusOS/Views/Components/FilterChipGroup.swift` (if needed)

## Files to Modify

- `FocusOSShared/FocusOSShared/FocusOSShared/Models/Note.swift` - Add isPinned, pinnedAt
- `FocusOS/Views/Components/ContextualCreateSheet.swift` - Integrate note creation
- `FocusOS/Extensions/Notification+Names.swift` - Add .openNoteDetail
- `FocusOS/Views/MainWindowView.swift` - Update to use UnifiedNotesView instead of NotesView

## Testing Checklist

- [ ] Header fade and search bar animation
- [ ] Card hover, selection, and context menu
- [ ] Drawer open/close transitions
- [ ] AI summary and regenerate workflow
- [ ] Focus Gravity bar visualization
- [ ] Group expand/collapse behavior
- [ ] Keyboard nav (↑↓ for cards, Enter to open, ⎋ to close drawer)
- [ ] Reduce motion compliance
- [ ] VoiceOver and Dynamic Type support
- [ ] Pinned notes sorting and display
- [ ] Memory Graph updates on note save

### To-dos

- [ ] Add isPinned and pinnedAt properties to Note model in FocusOSShared
- [ ] Create FilterChipGroup component wrapper for horizontal filter chips
- [ ] Build NotesHeaderView with title, subline, search bar, filter chips, and quick add button
- [ ] Create NoteCardV2 component with glass panel, preview, metadata, hover states, and context menu
- [ ] Build NoteDetailDrawer with editable title/body, tag editor, AI summary section, and Focus Gravity sidebar
- [ ] Create UnifiedNotesView with grouping, sorting, pinned notes separation, and empty state
- [ ] Integrate new note creation in ContextualCreateSheet with drawer UI and haptic feedback
- [ ] Connect AI summary generation, Memory Graph updates, and Ask Aurora button
- [ ] Add keyboard navigation, VoiceOver labels, Dynamic Type support, and reduce motion compliance
- [ ] Update MainWindowView to use UnifiedNotesView instead of NotesView