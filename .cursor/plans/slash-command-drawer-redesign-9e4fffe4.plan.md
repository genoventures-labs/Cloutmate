<!-- 9e4fffe4-b46a-471e-abc6-fd4eaedcfc3c deb02b5f-a2de-4a0a-9a0b-8b30d19b656b -->
# Slash Command Drawer Redesign

## Overview

Redesign the `SlashCommandAutocompleteView` to match Image 2's large white panel container style (the white panel showing "Create Image", "Deep Research", etc.) while keeping our existing slash commands (/tab, /think, /web, /project, /task) with their icons and descriptions.

## Changes Required

### 1. Update SlashCommandAutocompleteView.swift

- **Dimensions & Layout**: Match Image 2's panel dimensions exactly
- Large panel container matching Image 2's size (similar to panel showing "Create Image", "Deep Research", etc.)
- Match Image 2's panel width (appears to be ~600-700px or match input container)
- Match Image 2's panel height (large content area, appears ~400-500px)
- Use V2/UnifiedView theme via GlassColorSystem (theme-aware background, not forced white)

- **Positioning**: Match Image 2's placement
- Position above input bar with spacing matching Image 2's gap
- Align with input container (centered or left-aligned as shown in Image 2)
- Adjust offset in `AuroraChatContainer.swift` to match Image 2's spacing

- **Content Structure**: Keep our slash commands but layout like Image 2
- Vertical list layout matching Image 2's structure
- Each item: Icon + Bold Title (command name like "/tab") + Subtitle (description)
- Match Image 2's text hierarchy: bold titles with lighter subtitle text
- Match Image 2's spacing between items
- Keep all 5 commands: `/tab`, `/think`, `/web`, `/project`, `/task`

- **Styling**: Use V2/UnifiedView theme while matching Image 2's layout
- Theme-aware background using GlassColorSystem (not forced white - respects dark/light mode)
- Rounded corners matching Image 2 (appears ~16-20px)
- Proper vertical padding and spacing between command items
- Subtle shadow/elevation using theme-appropriate styling
- Theme-appropriate scrollbar if content overflows

### 2. Update AuroraChatContainer.swift

- Adjust drawer positioning (lines 233-263)
- Match Image 2's spacing from input bar
- Ensure width matches Image 2's panel width
- Update `maxHeight` if needed to match Image 2's large content area
- Verify alignment matches Image 2's placement

## Files to Modify

1. `Cloutmate/Views/Components/SlashCommandAutocompleteView.swift` - Main drawer redesign
2. `Cloutmate/Views/AIAssistant/AuroraChatContainer.swift` - Positioning adjustments (if needed)

## Design Specifications

- **Background**: White/light theme-aware background
- **Width**: Match input container width or ~600-700px
- **Height**: ~400-500px (large content area like Image 2)
- **Spacing from input**: Match Image 2's gap (approximately 8-12px)
- **Content**: Vertical list with icons, bold command names, subtitle descriptions
- **Corner radius**: 16-20px
- **Shadow**: Subtle elevation shadow