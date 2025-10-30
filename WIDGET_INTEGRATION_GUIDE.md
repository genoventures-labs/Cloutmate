# Widget & Menu Bar Integration Guide

This guide explains how to complete the integration of the WidgetKit widget and menu bar app for Cloutmate.

## Overview

The integration consists of three components:
1. **CloutmateShared** - Shared framework containing models, services, and UI components
2. **CloutmateWidget** - WidgetKit extension for desktop widgets
3. **CloutmateMenuBar** - Menu bar application

## Current Status

Core files have been created in the following directories:
- `/CloutmateShared/` - Shared framework components
- `/CloutmateWidget/` - Widget extension files
- `/CloutmateMenuBar/` - Menu bar app files

## Xcode Project Setup Required

### Step 1: Create Framework Targets

You need to add three new targets to your Xcode project:

1. **CloutmateShared Framework**
   - Target Type: Framework
   - Deployment Target: macOS 14.0
   - Signing: Use your team and app group `group.kosmicapps.cloutmate`
   - Frameworks: SwiftUI, SwiftData, Foundation

2. **CloutmateWidget Extension**
   - Target Type: Widget Extension
   - Deployment Target: macOS 14.0
   - Signing: Use your team and app group
   - Frameworks: SwiftUI, WidgetKit, SwiftData, Foundation

3. **CloutmateMenuBar App**
   - Target Type: Application
   - Bundle ID: `com.kosmicapps.CloutmateMenuBar`
   - Deployment Target: macOS 14.0
   - Signing: Use your team and app group
   - Frameworks: SwiftUI, SwiftData, AppKit, Foundation
   - Info.plist: `LSUIElement = YES` (to hide from Dock)

### Step 2: Add Files to Targets

For **CloutmateShared**:
- Add all files from `/CloutmateShared/CloutmateShared/` to the framework target
- Ensure Models, Services, and UI folders are included

For **CloutmateWidget**:
- Add all files from `/CloutmateWidget/` to the widget extension
- Add Info.plist with `NSSupportsAutomaticWidgetGraphicModification = true`

For **CloutmateMenuBar**:
- Add all files from `/CloutmateMenuBar/` to the menu bar app
- Create Info.plist with `LSUIElement = YES`
- Create Assets.xcassets with menu bar icons

### Step 3: Configure App Group Entitlements

Add to all three targets (main app, widget, menu bar):

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.kosmicapps.cloutmate</string>
</array>
```

### Step 4: Configure Keychain Access Group

Update `KeychainService.swift` in CloutmateShared:

```swift
private let accessGroup = "group.kosmicapps.cloutmate"
```

### Step 5: Add Shared Services

Move these services to CloutmateShared framework:
- `ThreadsService.swift`
- `FacebookService.swift`
- `MetaAPIService.swift`
- `LoginItemService.swift`

These require platform-specific API implementations.

### Step 6: Update Imports

In your main app, update all imports from:
```swift
import Foundation
```
to:
```swift
import Foundation
import CloutmateShared
```

For any files that use Post, Draft, Platform, etc.

### Step 7: Configure SwiftData Container

Update `CloutmateApp.swift` to use the shared container:

```swift
var sharedModelContainer: ModelContainer = SharedDataManager.createSharedModelContainer()
```

### Step 8: Add URL Scheme

In the main app's Info.plist, add:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>cloutmate</string>
        </array>
    </dict>
</array>
```

Handle deep links in `CloutmateApp.swift`:

```swift
.onOpenURL { url in
    if url.scheme == "cloutmate" {
        // Handle deep links
    }
}
```

## Features Implemented

### Widget
- Small widget showing scheduled post count
- Next post date/time display
- Glassmorphic design
- 15-minute refresh timeline

### Menu Bar App
- Quick composer for fast post scheduling
- Platform selection (Threads/Facebook)
- Schedule for later or post now
- Upcoming posts list view
- Link to open main app
- Widget refresh button

## Testing

1. Build and run each target separately
2. Test data sync between main app and menu bar
3. Test scheduling from menu bar
4. Add widget to desktop
5. Verify UI consistency across all three apps

## Known Limitations

- ThreadsService and FacebookService need to be moved to shared framework
- PublishingService needs platform service dependencies
- Some SwiftData queries may need adjustment for app group context
- Menu bar icon assets need to be created

## Next Steps

1. Create the Xcode targets as described
2. Move remaining services to shared framework
3. Fix import statements
4. Test end-to-end publishing flow
5. Create app icons and menu bar icons
6. Add widget configuration UI (optional)

## File Structure

```
Cloutmate/
├── Cloutmate/               # Main app
├── CloutmateShared/          # Shared framework
│   └── CloutmateShared/
│       ├── Models/
│       ├── Services/
│       └── UI/
├── CloutmateWidget/          # Widget extension
│   ├── CloutmateWidget.swift
│   ├── WidgetTimelineProvider.swift
│   └── CloutmateWidgetView.swift
└── CloutmateMenuBar/         # Menu bar app
    ├── MenuBarApp.swift
    ├── MenuBarPopoverView.swift
    ├── QuickComposerView.swift
    ├── UpcomingPostsView.swift
    └── MenuBarSettingsView.swift
```

