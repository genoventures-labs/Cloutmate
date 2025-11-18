<!-- dff843f9-785a-492b-a6cc-859048ad8df0 8e7c8a66-587a-4263-97a7-dfcca0969c75 -->
# Resources V2 Redesign Plan

## Overview

Transform Resources into a visual knowledge vault with gallery-driven card layout, AI-powered categorization, elegant detail drawers, and seamless Aurora integration for semantic linking and smart suggestions.

## Implementation Structure

### Phase 1: Unified Header Zone

**File:** `FocusOS/Views/Resources/Components/ResourcesHeaderView.swift` (NEW)

- Title: "Resources" with `.system(.title3, design: .rounded)`
- Subline: "Your library of saved knowledge and media"
- Filter chips: "All • Documents • Media • Templates • Articles • Archived" (reuse existing `FilterChip` component)
- Inline glass search bar with placeholder "Search by title, type, or tag…"
- Quick Add "+" `GlassButton` that opens `ResourceImportSheet`
- Visual: `.glassPanel(tier: .overlay)` with kosmicBlue → kosmicPurple gradient accent
- Header fade on scroll using `.opacity` animation
- Entrance motion: `.spring(duration: 0.35)` from `GlassMotion.Easing.spring`

### Phase 2: Resource Card System

**File:** `FocusOS/Views/Resources/Components/ResourceCardV2.swift` (NEW)

- Base: `.glassPanel(tier: .contentCard, cornerRadius: 12)`
- Cover: Thumbnail image or gradient placeholder (120×120pt minimum)
- Left edge gradient bar (4pt width) based on `ResourceType`:
- Blue = Document (note, reference)
- Purple = Media (video, podcast)
- Green = Template
- Yellow = External Article (article, link)
- Body:
- Title: bold rounded font (`.headline`)
- Subtitle: file type + size or source (e.g., "PDF • 1.2 MB" or "Saved from Medium")
- Tags row: up to 3 category chips (AI-generated: Study, Branding, Technical, etc.)
- Footer:
- Date added (relative time)
- Aurora category prediction badge (e.g., "Recommended for Project: FocusOS")
- Hover: `.floatLift()` modifier + kosmicBlue edge glow (using `GlassMotion`)
- Tap: Opens `ResourceDetailDrawer`

### Phase 3: Resource Detail Drawer

**File:** `FocusOS/Views/Resources/Components/ResourceDetailDrawer.swift` (NEW)

- Width: 450px fixed
- Background: `.ultraThinMaterial` overlay
- Header:
- Editable title (TextField)
- File type badge + date added
- Close button
- Body sections:
- File preview: Image viewer, document viewer, or metadata summary based on type
- AI Summary: Aurora-generated quick description (from `OllamaBridgeService`)
- Tags editor: Add/remove tags with autocomplete
- Related items: Linked Notes, Drafts, Projects (semantic matches)
- Sidebar (right):
- Related Resources: Semantic matches using Aurora knowledge graph
- Linked Notes/Drafts/Projects: Cross-references via `Note.backlinks`
- Aurora recommendation panel: "Use this in your next Task?" with action button
- Behavior:
- Opens from right with `.transition(.move(edge: .trailing))`
- Dimmed backdrop (tap to close)
- Haptic feedback on open/close (`NSHapticFeedbackManager`)

### Phase 4: Resource Import Sheet

**File:** `FocusOS/Views/Resources/Components/ResourceImportSheet.swift` (NEW)

- Visual: `.glassPanel(tier: .overlay)` with tab navigation
- Input methods (tabs with icon pills):

1. **Upload File:** Drag-and-drop or file picker (`NSSavePanel` / `NSOpenPanel`)
2. **Save Link:** URL paste → auto-fetch metadata + summary (web scraping)
3. **Capture Text:** Quick snippet entry (TextEditor)
4. **From AI Assistant:** Import response directly from chat (link to `AIAssistantViewModel`)

- Processing:
- Aurora classification via `OllamaBridgeService.generateResponseWithAppContext()`
- Auto-assign tags (Study, Branding, Technical, etc.)
- Option to mark as "Reference" (non-editable flag)
- Visual: Active tab highlighted with kosmicBlue
- Integration: Add "Import Resource" action to `ContextualCreateSheet` for `.resources` tab

### Phase 5: Unified Resources View

**File:** `FocusOS/Views/Resources/UnifiedResourcesView.swift` (NEW)

- Replaces existing `ResourcesView.swift` table implementation
- Layout:
- `ResourcesHeaderView` at top
- LazyVGrid gallery: `[GridItem(.adaptive(minimum: 280, maximum: 320))]`
- Cards: `ResourceCardV2` for each filtered resource
- Filtering logic:
- Reuse existing `filteredNotes` logic from `ResourcesView.swift`
- Add filter for "Archived" resources
- Type filters: Documents, Media, Templates, Articles
- Empty state: Elegant placeholder with "Add your first resource" CTA
- Scroll behavior: Header fade on scroll using `ScrollViewReader`

### Phase 6: Aurora Integration

**Files:**

- `FocusOS/Services/OllamaBridgeService.swift` (MODIFY)
- `FocusOS/ViewModels/AIAssistantViewModel.swift` (MODIFY)

- **Auto-Categorization:**
- On import, call Aurora with resource content
- Identify type, context, potential linked items
- Return structured tags and category predictions
- **Knowledge Graph:**
- Each resource becomes a `MemoryNode` (if not already)
- Auto-create `MemoryEdge` links if title/keywords overlap Notes/Drafts
- Use existing `MemoryGraph` infrastructure
- **Smart Suggestions:**
- "This resource aligns with your Journal reflection on Nov 3."
- "You might want to link this to Project: FocusOS Marketing."
- Display in `ResourceDetailDrawer` sidebar
- **Predictive Recall:**
- When opening related Note/Project, Aurora surfaces connected resources
- Add to `AIAssistantViewModel` payload context

### Phase 7: Motion & Feedback

**File:** `FocusOS/Views/Resources/Components/ResourceCardV2.swift` (MODIFY)

- Card hover: `.floatLift()` (already implemented in `GlassMotion.swift`)
- Drawer open: `.transition(.move(edge: .trailing))` with `GlassMotion.Easing.modalOpen`
- File upload: Shimmer gradient sweep using `ShimmerEffect` from `GlassMotion.swift`
- Tag assignment: `.ripple(color: .kosmicBlue)` modifier
- Filter switch: `.opacity` fade with `GlassMotion.Easing.tabSwitch`

### Phase 8: Accessibility & Calm Mode

**Files:**

- `FocusOS/Views/Resources/Components/ResourceCardV2.swift` (MODIFY)
- `FocusOS/Views/Resources/UnifiedResourcesView.swift` (MODIFY)

- Large clickable thumbnails (min 120×120pt)
- Keyboard nav: ← → scroll between cards, Enter to open drawer
- Reduce motion: Disable hover lift and shimmer (check `accessibilityReduceMotion`)
- High contrast fallback: Solid kosmicBlue borders instead of gradients
- VoiceOver: Reads title, type, and summary (add `.accessibilityLabel`)

### Phase 9: Integration Points

**Files to Modify:**

1. **`FocusOS/Extensions/Notification+Names.swift`:**

- Add `.openResourceDetail` notification
- Add `.showResourceImport` notification

2. **`FocusOS/Views/Components/ContextualCreateSheet.swift`:**

- Add `.resources` case to `actionsForTab`
- Add "Import Resource" action with icon "square.and.arrow.down"

3. **`FocusOS/Views/MainWindowView.swift`:**

- Handle `.openResourceDetail` notification
- Handle `.showResourceImport` notification
- Update Resources tab to use `UnifiedResourcesView`

4. **`FocusOS/ViewModels/AIAssistantViewModel.swift`:**

- Add export/import link for resources
- Include resource context in payload when relevant

## Design Tokens

- Corner radius: 12pt (consistent with `GlassPanel`)
- Blur: `.ultraThinMaterial` for drawers
- Colors: `kosmicBlue`, `kosmicPurple`, `kosmicGreen`, `kosmicYellow` (from `ColorExtensions.swift`)
- Typography: SF Pro Rounded (`.system(.title3, design: .rounded)`)
- Shadow: `kosmicPurple.opacity(0.15)`, radius: 3
- Animation: `GlassMotion.spring` (response: 0.3, dampingFraction: 0.7)
- Gradient: Blue → Purple primary, tone adaptive

## Testing Checklist

- [ ] Upload, link, and text capture work smoothly
- [ ] AI summaries generate reliably via Aurora
- [ ] Tag suggestions accurate
- [ ] Hover states and motion consistent
- [ ] Drawer links Notes, Drafts, Projects correctly
- [ ] Calm mode visuals respected (reduce motion)
- [ ] Accessibility tests pass (VoiceOver, keyboard nav)
- [ ] Empty state displays correctly
- [ ] Filter chips update gallery correctly
- [ ] Cross-linking to Notes/Projects works

## Migration Strategy

1. Create new component files alongside existing `ResourcesView.swift`
2. Test new `UnifiedResourcesView` in parallel
3. Update `MainWindowView` to use new view
4. Deprecate old table-based implementation after validation
5. Keep `Note` model unchanged (already supports resources via `ResourceType`)

### To-dos

- [ ] Create ResourcesHeaderView with title, subline, filters, search bar, and Quick Add button
- [ ] Create ResourceCardV2 with cover, left edge gradient, body, footer, and hover effects
- [ ] Create ResourceDetailDrawer with header, preview, AI summary, tags, and sidebar recommendations
- [ ] Create ResourceImportSheet with upload, link, text capture, and AI import tabs
- [ ] Create UnifiedResourcesView replacing table with gallery layout using LazyVGrid
- [ ] Integrate Aurora auto-categorization, knowledge graph linking, and smart suggestions
- [ ] Add motion effects: hover lift, drawer transitions, shimmer, ripple, filter fades
- [ ] Implement accessibility: large thumbnails, keyboard nav, reduce motion, VoiceOver labels
- [ ] Update Notification+Names, ContextualCreateSheet, MainWindowView, and AIAssistantViewModel