<!-- 94ea74e1-6c66-407c-bb9c-61032e6115d4 85ed613f-64ff-4842-8407-17eb3b69d0cc -->
# Image Paste and Screenshot Features for Aurora Chat

## Overview

Enhance Aurora's chat input with image paste support, screenshot capture functionality, thumbnail previews, and proper input clearing on message send.

## Implementation Steps

### 1. Verify and Enhance Image Paste Support

**File**: `FocusOS/Views/AIAssistant/UnifiedAIAssistantView.swift`

The image paste handler already exists (lines 774-799) and correctly attaches without sending. No changes needed, but verify it works as expected.

### 2. Add Screenshot Capture Service

**File**: `FocusOS/Services/ScreenshotService.swift` (NEW)

Create a new service to handle window listing and screenshot capture:

- Use `CGWindowListCopyWindowInfo` to get list of windows
- Filter to show only windowed applications (exclude desktop, dock, etc.)
- Use `CGWindowListCreateImageFromArray` to capture selected window
- Convert captured image to `NSImage` for attachment

### 3. Add Window Selection View

**File**: `FocusOS/Views/AIAssistant/Components/WindowSelectionView.swift` (NEW)

Create a SwiftUI view that:

- Displays list of available windows with app icons and window titles
- Shows window preview thumbnails if possible
- Allows user to select a window for screenshot
- Returns selected window ID for capture

### 4. Update Attachment Menu

**File**: `FocusOS/Views/AIAssistant/Components/AttachmentMenuView.swift`

Add "Take Screenshot" menu option below "Upload Image":

- Add new callback `onSelectScreenshot: () -> Void`
- Add menu button for screenshot option
- Wire up to show window selection view

### 5. Update Attachment Menu Integration

**File**: `FocusOS/Views/AIAssistant/Components/AuroraChatInputBar.swift`

Pass screenshot handler to `AttachmentMenuView`:

- Add `onAttachScreenshot: () -> Void` parameter
- Pass to `AttachmentMenuView` component

### 6. Implement Screenshot Handler

**File**: `FocusOS/Views/AIAssistant/UnifiedAIAssistantView.swift`

Add screenshot capture functionality:

- Create `attachScreenshotFromWindow()` function
- Show window selection sheet
- Capture selected window using `ScreenshotService`
- Attach screenshot using `viewModel.attachImage()` (without auto-sending)
- Handle errors gracefully

### 7. Add Screenshot Handler to Composer

**File**: `FocusOS/Views/AIAssistant/UnifiedAIAssistantView.swift`

Update `composerHandlers` to include screenshot handler:

- Add `onAttachScreenshot` callback
- Wire to `attachScreenshotFromWindow()`

### 8. Update Container to Pass Screenshot Handler

**File**: `FocusOS/Views/AIAssistant/AuroraChatContainer.swift`

Add screenshot handler parameter:

- Add `onAttachScreenshot` to `ComposerHandlers` struct
- Pass through to `AuroraChatInputBar`

### 9. Enhance Image Thumbnail Preview

**File**: `FocusOS/Views/AIAssistant/Components/AuroraChatInputBar.swift`

Update `attachmentPreview` function (lines 474-504) to show actual image thumbnail:

- Check if attachment is image type
- Display `NSImage` thumbnail instead of just icon
- Show thumbnail in same style as context attachments
- Maintain existing clear button functionality

### 10. Verify Input Clearing on Send

**File**: `FocusOS/ViewModels/AIAssistantViewModel.swift`

Verify `sendMessage` clears input immediately:

- Check that `inputText = ""` is set early in `sendMessage` (not just in async completion)
- Ensure input clears even if message sending fails

## Key Implementation Details

### Screenshot Capture

- Use `CGWindowListCopyWindowInfo` with option `.optionOnScreenOnly`
- Filter windows: exclude desktop, dock, and windows with `kCGWindowLayer` > 0
- Use `CGWindowListCreateImageFromArray` with window IDs for capture
- Convert `CGImage` to `NSImage` for attachment

### Window Selection UI

- Show window list in a sheet or popover
- Display app icon, window title, and optional preview
- Handle window selection and dismiss sheet
- Show loading state during capture

### Thumbnail Display

- Use `ImageAttachment.preview` property (already available in `ImageAttachmentService.ImageAttachment`)
- Display thumbnail at fixed size (e.g., 80x80) with corner radius
- Show alongside or replace icon in attachment preview
- Maintain existing layout and styling

## Files to Modify

1. `FocusOS/Services/ScreenshotService.swift` (NEW)
2. `FocusOS/Views/AIAssistant/Components/WindowSelectionView.swift` (NEW)
3. `FocusOS/Views/AIAssistant/Components/AttachmentMenuView.swift`
4. `FocusOS/Views/AIAssistant/Components/AuroraChatInputBar.swift`
5. `FocusOS/Views/AIAssistant/UnifiedAIAssistantView.swift`
6. `FocusOS/Views/AIAssistant/AuroraChatContainer.swift`
7. `FocusOS/ViewModels/AIAssistantViewModel.swift` (verify only)