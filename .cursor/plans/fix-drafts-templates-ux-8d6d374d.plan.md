<!-- 8d6d374d-d465-4975-a137-9e722f19ca93 3264e6a6-74fc-4115-90e3-0a6ec2efd461 -->
# Fix Drafts & Templates UX Issues

## Problems Identified

1. **Copy Template Icon**: Non-functional button that shows unreadable sheet
2. **Split View**: Right panel is collapsed and unreadable by default
3. **New Draft UX**: Lacks modern iOS 18+ polish and clear editing guidance
4. **Draft List**: Minimal functionality, no inline actions
5. **Terminology**: Uses Instagram-specific term "Caption"

## Implementation Plan

### 1. Add Copy Template to Draft Functionality

**File**: `DraftsView.swift`

Add a proper template selector that:

- Shows a popover/menu to select from available templates
- Only enables when a draft is selected
- Applies template content to the selected draft
- Provides visual feedback on successful copy

Replace the unreadable sheet with a clean menu picker in the toolbar.

### 2. Fix Split View Sizing Issues

**Files**: `DraftsView.swift`, `TemplateManagementView.swift`

- Set proper `frame(minWidth:)` constraints on both sides of `HSplitView`
- Add default column widths to ensure right panel is visible
- Ensure editor content is readable without manual resizing
- Apply same fixes to `NavigationSplitView` in TemplateManagementView

### 3. Update Terminology Throughout

**Files**: `DraftEditor.swift`, `TemplateManagementView.swift`, `CreateTemplateSheet.swift`, `Draft.swift`, `Template.swift`

Replace "Caption" with "Content":

- UI labels and section headers
- Form fields
- Character count labels
- Model property names (breaking change - requires careful migration)
- Comments and documentation

### 4. Enhance Draft List with Inline Actions

**File**: `DraftsView.swift`

Modernize `DraftRow` with:

- **Swipe actions**: Delete, duplicate, convert to post
- **Context menu**: Right-click actions
- **Visual polish**: Card-style design with hover effects
- **Better preview**: Show more metadata (tags, character count)
- **Status indicators**: Visual cues for empty vs populated drafts

### 5. Modernize New Draft Experience

**Files**: `DraftsView.swift`, `DraftEditor.swift`

When creating a new draft:

- Automatically focus the content field
- Show a modern placeholder with helpful hints
- Add subtle animations for state transitions
- Display a welcome message for first-time users
- Use iOS 18+ design patterns (rounded corners, materials, shadows)

### 6. Improve DraftEditor Visual Design

**File**: `DraftEditor.swift`

Apply modern iOS 18+ styling:

- Replace basic `TextEditor` backgrounds with material effects
- Add proper form styling with grouped sections
- Improve button hierarchy and prominence
- Better spacing and typography
- Add visual separators between sections

## Files to Modify

- `FocusOS/Views/Drafts/DraftsView.swift` - Main fixes for layout, copy functionality, draft list
- `FocusOS/Views/Drafts/DraftEditor.swift` - Terminology, modern styling, UX improvements
- `FocusOS/Views/Drafts/TemplateManagementView.swift` - Split view sizing, terminology
- `FocusOS/Models/Draft.swift` - Rename caption → content property
- `FocusOS/Models/Template.swift` - Rename caption → content property

## Key Technical Decisions

1. Use `Menu` instead of sheet for template selection (better UX)
2. Set explicit split view widths to prevent collapse issues
3. Keep model property renaming minimal to avoid data migration issues
4. Use SwiftUI's native swipe actions and context menus for draft actions
5. Apply modern design with `.background(.thinMaterial)` and proper corner radius

### To-dos

- [ ] Implement working copy template button with menu picker
- [ ] Fix HSplitView and NavigationSplitView default widths
- [ ] Replace 'Caption' terminology with 'Content' throughout codebase
- [ ] Add swipe actions, context menu, and modern card design to draft rows
- [ ] Improve new draft creation flow with auto-focus and modern styling
- [ ] Apply modern iOS 18+ design patterns throughout draft editor