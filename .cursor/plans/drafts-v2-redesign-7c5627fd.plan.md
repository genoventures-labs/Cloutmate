<!-- 7c5627fd-8bef-4530-8795-23ba7acb20fa bd383838-1507-4948-936f-ccf2b7d57d2a -->
# Drafts V2 Redesign Plan

## Overview

Transform the Drafts tab into a smart creative workspace that syncs with AI Assistant and other tabs. The design follows Notes V2 patterns with glass panels, card layouts, and Aurora intelligence integration.

## Phase 1: Unified Header Zone

**File: `Cloutmate/Views/Drafts/Components/DraftsHeaderView.swift`** (NEW)

- Create header component following `NotesHeaderView.swift` pattern
- Title: "Drafts" using `.system(.title3, design: .rounded)` with kosmicBlue → kosmicPurple gradient
- Subline: "Ideas in progress • Synced with AI Assistant"
- Inline glass search bar: "Search drafts by title or tags..."
- Filter chips: "All", "Unfinished", "AI-Generated", "User-Created", "Archived"
- Quick Add "+" GlassButton → opens Draft Editor Drawer
- Use `GlassPanel(tier: .overlay, cornerRadius: 12)` wrapper
- `.spring(duration: 0.35)` entry animation

## Phase 2: Draft Card System

**File: `Cloutmate/Views/Drafts/Components/DraftCardV2.swift`** (NEW)

- Create card component following `NoteCardV2.swift` pattern
- Base: `GlassPanel(tier: .contentCard, cornerRadius: 12)`
- Top Row: Title + tag chips (AI / Manual / Shared badges)
- Body: 3-5 line preview (markdown snippet or text body) with fade-out mask
- Footer: Last modified date, source badge (AI Assistant, Notes, Journal), word count
- Hover: `.floatLift()` + kosmicPurple border glow
- Active Indicator: Thin gradient strip (kosmicBlue → kosmicGreen) for "Active Draft"
- Tap → opens Draft Editor Drawer
- Right-click context menu: Edit, Export, Duplicate, Archive, Delete
- Hover buttons: "Open", "Share", "Publish" (fade in on hover)

## Phase 3: Draft Editor Drawer

**File: `Cloutmate/Views/Drafts/Components/DraftEditorDrawer.swift`** (NEW)

- Slide-in panel (400-500px width) following `NoteDetailDrawer.swift` pattern
- `.ultraThinMaterial` background with frosted glass
- Header: Editable title field + tag chips
- Body: Rich text editor with Markdown support
- Footer: "Save", "Export", "Publish", "Delete" buttons
- AI Enhancement Mode:
- Button: "Ask Aurora to improve"
- Opens side overlay for AI suggestions (uses `OllamaBridgeService`)
- Aurora suggests phrasing, tone, or structure improvements inline
- Version History:
- Tap "History" → popover listing save timestamps
- Select to revert or duplicate version
- Auto-Save: every 15 seconds or on blur
- Aurora Summary: appears below editor after each save ("Here's what this draft expresses most strongly...")

## Phase 4: Draft Model Extensions

**File: `Cloutmate/Models/Draft+Extensions.swift`** (NEW)

Add new attributes to `Draft` model:

- `@Attribute var source: String?` // e.g., "AI Assistant", "Notes", "Journal"
- `@Attribute var tagsData: Data?` // Encoded [String] (if not already using tags array)
- `@Attribute var isPublished: Bool = false`
- `@Attribute var lastEditedAt: Date`
- `@Attribute var wordCount: Int`
- `@Attribute var versionHistoryData: Data?` // Encoded [DraftVersion]

Behavior:

- Auto-tagging: When exported from AI Assistant, adds "AI" + conversation title tag
- Smart detection: If text includes "#hashtags" or links → marks as "Post-type Draft"
- Aurora-aware: Links emotional tone from Journal entries written the same day

**Migration Note:** Existing drafts will need default values for new attributes.

## Phase 5: Publishing Flow

**File: `Cloutmate/Views/Drafts/Components/DraftPublishingSheet.swift`** (NEW)

- Options: Export to Notes, Resources, AI Assistant, or External (Markdown/PDF)
- Optional caption generator for social posts
- Aurora auto-suggests title variants using `OllamaBridgeService`
- Confirms "Published Successfully" with gradient toast
- Calls `DraftPublisherService.publish(draft:)` (NEW service)
- If published to Notes or Resources, moves draft to "Archived" state

**File: `Cloutmate/Services/DraftPublisherService.swift`** (NEW)

- `publish(draft: Draft, to: PublishingDestination, modelContext: ModelContext) async throws`
- Handles conversion to Note, Artifact, or external export
- Updates draft status and metadata

## Phase 6: Unified Drafts View

**File: `Cloutmate/Views/Drafts/UnifiedDraftsView.swift`** (NEW)

- Replace current `DraftsView.swift` table layout with card grid
- Use `DraftsHeaderView` at top
- ScrollView with LazyVGrid (2 columns) showing `DraftCardV2` components
- Filter logic: filter by selected filter chip, search text, and tags
- Empty state: ContentUnavailableView with "No drafts" message
- Selection mode: Multi-select with SelectionActionBar (following Notes pattern)

## Phase 7: Aurora & Intelligence Integration

**File: `Cloutmate/Services/DraftEnhancementService.swift`** (NEW)

- AI Enhancements: Aurora provides "Improve / Rephrase / Expand" actions inline
- Uses `OllamaBridgeService.generateResponse()` with draft context
- Auto-Summaries: Aurora generates concise summaries for long drafts
- Mood Context: Aurora detects tone (Calm / Motivated / Analytical) via `EmotionAnalyzer`
- Visualize tone via gradient shift on card
- Draft Recall: Integrated with `AIRecallService` Memory Graph
- Related drafts appear under "Connected Ideas" section

## Phase 8: Integration Points

**File: `Cloutmate/Views/Components/ContextualCreateSheet.swift`** (MODIFY)

- Add Drafts quick actions when `currentTab == .drafts`
- Actions: "New Draft", "From AI Conversation", "From Note"

**File: `Cloutmate/ViewModels/AIAssistantViewModel.swift`** (MODIFY)

- Enhance `exportToDraft()` method:
- Set `draft.source = "AI Assistant"`
- Add conversation title as tag
- Set `draft.lastEditedAt = Date()`
- Calculate `draft.wordCount`

**File: `Cloutmate/Extensions/Notification+Names.swift`** (MODIFY)

- Add `.openDraftEditor` notification name
- Add `.draftPublished` notification name

## Phase 9: Accessibility & Calm Mode

- Calm Mode → desaturates gradients, disables shimmer
- Large text mode → reflows preview text
- Reduce motion → disables hover lifts and ripple feedback
- VoiceOver → announces title, status, and tags
- Keyboard Nav → ↑↓ between cards, Enter = open editor, Esc = close

## Phase 10: Visual & Motion System

- Card hover: `.floatLift()` depth + soft glow
- Drawer entry: `.transition(.move(edge: .trailing))` smooth open
- Button press: `.GlassMotion.ripple` tactile feedback
- Save event: shimmer gradient sweep confirmation
- Filter change: `.opacity` fade instant feedback

## Design Tokens

- Corner radius: 12pt
- Color system: kosmicBlue, kosmicPurple, kosmicGreen
- Typography: SF Pro Rounded, Inter
- Blur: `.ultraThinMaterial`
- Shadows: kosmicPurple.opacity(0.15), radius: 3
- Animation: `GlassMotion.spring`

## Implementation Order

1. Create Draft model extensions (Phase 4)
2. Create DraftsHeaderView (Phase 1)
3. Create DraftCardV2 (Phase 2)
4. Create UnifiedDraftsView (Phase 6)
5. Create DraftEditorDrawer (Phase 3)
6. Create DraftPublishingSheet and DraftPublisherService (Phase 5)
7. Create DraftEnhancementService (Phase 7)
8. Update integration points (Phase 8)
9. Add accessibility features (Phase 9)

## Testing Checklist

- Filter chips and search bar functionality
- Hover actions and card layout
- Drawer open/close and auto-save
- Aurora AI improvement overlay working
- Publish sheet exports correctly
- Version history accuracy
- Aurora summaries generated on save
- Reduce motion + calm mode compliance
- Keyboard navigation smooth
- Migration of existing drafts with new attributes

### To-dos

- [ ] Add new attributes to Draft model: source, tagsData, isPublished, lastEditedAt, wordCount, versionHistoryData
- [ ] Create DraftsHeaderView component with title, subline, search bar, filter chips, and quick add button
- [ ] Create DraftCardV2 component with glass panel, preview text, metadata, hover effects, and context menu
- [ ] Create UnifiedDraftsView replacing table layout with card grid, integrating DraftsHeaderView and DraftCardV2
- [ ] Create DraftEditorDrawer with rich text editor, AI enhancement mode, version history, and auto-save
- [ ] Create DraftPublishingSheet with export options and Aurora title suggestions
- [ ] Create DraftPublisherService to handle publishing to Notes, Resources, or external formats
- [ ] Create DraftEnhancementService for Aurora AI improvements, summaries, and mood detection
- [ ] Update ContextualCreateSheet, AIAssistantViewModel.exportToDraft(), and Notification+Names
- [ ] Add calm mode, reduce motion, VoiceOver, and keyboard navigation support