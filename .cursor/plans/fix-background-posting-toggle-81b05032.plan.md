<!-- 81b05032-0092-4366-81ea-78296ed8c1e1 cf7402cc-9a02-4382-9436-861904d08acd -->
# Fix Background Posting Functionality

## Root Causes

The background posting feature is broken due to multiple configuration issues:

1. **Wrong Helper Target**: The Xcode project has a target called `CloudmateHelper` (typo) pointing to a template SwiftUI app folder, while the actual helper implementation is in `FocusOSHelper` folder
2. **Missing SMLoginItemIdentifiers**: Main app's Info.plist lacks the required key for macOS 13+ login item registration
3. **Helper Not Embedded**: The helper app needs to be embedded in the main app bundle at `Contents/Library/LoginItems/`
4. **State Management Issue**: Toggle state doesn't persist because `onAppear` re-reads failed status when switching tabs

## Implementation Plan

### 1. Update Xcode Project Configuration

- Fix the target to point to the correct `FocusOSHelper` folder (not `CloudmateHelper`)
- Update the file system synchronized root group to use the correct path
- Verify the bundle identifier is `com.kosmicapps.FocusOS.Helper`

### 2. Add Login Item Configuration

- Add `SMLoginItemIdentifiers` key to `FocusOS/Info.plist` with value `["com.kosmicapps.FocusOS.Helper"]`
- This tells macOS which helper app can be registered as a login item

### 3. Embed Helper in Main App

- Add a "Copy Files" build phase to the FocusOS target
- Configure it to copy `FocusOSHelper.app` to `Contents/Library/LoginItems/`
- Add helper target as a dependency of the main app

### 4. Fix State Management in SettingsView

- Remove the `.onAppear` block that re-reads login item status when switching tabs
- Only read the initial state once when the view is first created
- The toggle state should be the source of truth, controlled by `@AppStorage`

### 5. Improve Error Handling in LoginItemService

- Add better error messages that distinguish between "helper not built" vs "permission denied" vs "already registered"
- Update the service to handle the async nature of login item registration on macOS 13+

## Files to Modify

- `FocusOS.xcodeproj/project.pbxproj` - Fix target configuration and add embed phase
- `FocusOS/Info.plist` - Add SMLoginItemIdentifiers key
- `FocusOS/Views/Settings/SettingsView.swift` - Remove problematic onAppear
- `FocusOS/Services/LoginItemService.swift` - Improve error handling (optional)

### To-dos

- [ ] Update Xcode project to point CloudmateHelper target to the correct FocusOSHelper folder
- [ ] Add SMLoginItemIdentifiers key to main app Info.plist
- [ ] Add Copy Files build phase to embed helper app in main app bundle
- [ ] Remove onAppear from SettingsView that causes toggle to flip back
- [ ] Verify background posting toggle works and persists across tab switches