# FocusOSShared Framework Contents

This framework contains code shared between the main app, widget, and menu bar app.

## What Should Be in This Framework

### ✅ Included (Current)

**Models:**
- `Post.swift` - Main post model
- `Draft.swift` - Draft model
- `Template.swift` - Template model
- `Platform.swift` - Platform enum
- `PlatformAccount.swift` - Account info
- `InsightSnapshot.swift` - Cached insights
- `APIModels.swift` - API response models

**Services:**
- `Logger.swift` - Logging utilities
- `KeychainService.swift` - Secure token storage
- `XPCService.swift` - XPC communication
- `XPCProtocol.swift` - XPC protocol definitions
- `PublishingService.swift` - Stub (delegates to main app)
- `SharedDataManager.swift` - SwiftData container with app group

**UI Components:**
- `GlassPanel.swift` - Glassmorphic panel component
- `GlassMaterialTiers.swift` - Material tier system
- `GlassMotion.swift` - Animation constants
- `GlassColorSystem.swift` - Color system
- `AccessibilityGlassManager.swift` - Accessibility support

### ❌ NOT Included (Must Stay in Main App)

These services depend on app-specific resources and cannot be in a framework:

- `MetaAPIService.swift` - Needs AuthenticationServices framework and Info.plist access
- `ThreadsService.swift` - Depends on MetaAPIService
- `FacebookService.swift` - Depends on MetaAPIService
- `LoginItemService.swift` - Needs app-specific functionality
- `OAuthCallbackServer.swift` - Server implementation

### How Widget/MenuBar Publish

**For Scheduled Posts:**
1. Widget/MenuBar saves post to SwiftData (shared container)
2. Calls `XPCService.shared.schedulePost()` to notify background service
3. Main app's background service publishes at scheduled time

**For Immediate Posts:**
- Widget/MenuBar can save the post
- User must use main app to actually publish
- Or: Widget/MenuBar can show "Use main app to publish" message

## Dependencies

**Required Frameworks:**
- SwiftUI
- SwiftData
- Foundation
- Combine (for some components)

**Required Entitlements:**
- None (this is a framework)
- App group is configured on the app targets

## Usage in Other Targets

### In Main App
```swift
import FocusOSShared

// Use shared models
let post = Post(...)

// Access shared container
let container = SharedDataManager.createSharedModelContainer()
```

### In Widget/MenuBar
```swift
import FocusOSShared

// Read shared data
let scheduledPosts = try context.fetch(descriptor)

// Schedule via XPC
XPCService.shared.schedulePost(...)
```

## Build Settings

- **Deployment Target:** macOS 14.0
- **Swift Language Version:** Swift 5
- **Code Signing:** Automatically managed by Xcode
- **Packaging:** Framework bundle

