# FocusOS Setup Guide

## Overview

This project uses **Xcode 16's File System Synchronized Root Groups** (objectVersion 77), which means Xcode automatically detects files in folders and adds them to targets. The helper app files are already in the `FocusOSHelper` folder but need proper target configuration.

## Quick Start

1. Open `FocusOS.xcodeproj` in Xcode 16+
2. Add the helper target (see step 2 below)
3. Configure the helper target settings
4. Add Meta API credentials
5. Build and run

## Detailed Setup Steps

### 1. Open Project in Xcode

Open `FocusOS.xcodeproj` in Xcode 16 or later. Files are automatically synchronized from the file system.

### 2. Add FocusOSHelper Target

The helper folder exists but needs a proper target:

**Option A: Use App Template (Recommended)**
1. In Xcode, click the **"+"** button at the bottom of the project navigator (or File → New → Target)
2. Select **"macOS"** → **"App"**
3. Click **"Next"**
4. Fill in the details:
   - **Product Name:** `FocusOSHelper`
   - **Team:** Your development team
   - **Organization Identifier:** `com.kosmicapps`
   - **Bundle Identifier:** `com.kosmicapps.FocusOS.Helper`
   - **Language:** Swift
   - **Interface:** None (or SwiftUI)
5. Click **"Finish"**

**Option B: Create Empty Target Manually**
1. File → New → Target
2. Select **"macOS"** → **"App"** or **"XPC Service"**
3. Configure as above
4. After creation, delete the template files Xcode creates
5. The existing files in `FocusOSHelper` folder will be detected automatically

### 3. Configure Helper Target Info

1. Select the **FocusOSHelper** target in the project navigator
2. Go to the **Info** tab
3. Under "Custom macOS Application Target Properties", add:
   - Key: `LSUIElement` → Type: Boolean → Value: `YES`
   - Key: `LSBackgroundOnly` → Type: Boolean → Value: `YES`

### 4. Assign Files to Helper Target

With Xcode 16's auto-sync, files should be included automatically. Verify:

1. Select `FocusOSHelper/FocusOSHelperApp.swift`
2. Open the File Inspector (right panel)
3. Under **Target Membership**, ensure **FocusOSHelper** is checked

Repeat for all helper files:
- `FocusOSHelperApp.swift`
- `HelperXPCService.swift`
- `BackgroundScheduler.swift`
- `PostPublisher.swift`
- `InsightsPoller.swift`
- `NotificationManager.swift`
- `FocusOSHelper.entitlements`

### 5. Add Shared Files to Both Targets

These files need to be in **both** targets:

1. Select each file below
2. In File Inspector → Target Membership, check **both** FocusOS and FocusOSHelper

**Files to share:**
- `FocusOS/Shared/XPCProtocol.swift`
- `FocusOS/Models/Platform.swift`
- `FocusOS/Models/APIModels.swift`
- `FocusOS/Services/MetaAPIService.swift`
- `FocusOS/Services/ThreadsService.swift`
- `FocusOS/Services/FacebookService.swift`
- `FocusOS/Services/KeychainService.swift`
- `FocusOS/Utilities/Logger.swift`

### 6. Configure Signing & Capabilities (Helper Target)

1. Select **FocusOSHelper** target
2. Go to **Signing & Capabilities** tab
3. Check "Automatically manage signing"
4. Select your development team
5. Add capabilities:
   - **App Sandbox**
   - **App Groups** → Add `group.com.kosmicapps.FocusOS`
   - **Keychain Sharing** → Match the main app's access group

**Important:** Both FocusOS and FocusOSHelper must use the same App Group ID.

### 7. Verify Main App Entitlements

Ensure the main app (`FocusOS` target) has:

1. **App Sandbox** enabled
2. **App Groups:** `group.com.kosmicapps.FocusOS`
3. **CloudKit:** `iCloud.com.kosmicapps.FocusOS`
4. **Keychain Access Groups:** Properly configured

### 8. Configure Meta API Credentials

**Important:** Never hardcode credentials in source code. Add them to Info.plist.

#### Method 1: Add to Info.plist in Xcode (Recommended)

1. In Xcode, select the **FocusOS** target
2. Go to the **Info** tab
3. Under "Custom macOS Application Target Properties", click the **+** button
4. Add these entries:
   - Key: `MetaAppID` → Type: String → Value: `YOUR_META_APP_ID`
   - Key: `MetaAppSecret` → Type: String → Value: `YOUR_META_APP_SECRET`
   - Key: `MetaRedirectURI` → Type: String → Value: `focusos://oauth/callback`

#### Method 2: Use Environment Variables (For Development)

1. Edit scheme → Run → Arguments → Environment Variables
2. Add these environment variables:
   - `MetaAppID` = `YOUR_META_APP_ID`
   - `MetaAppSecret` = `YOUR_META_APP_SECRET`
   - `MetaRedirectURI` = `focusos://oauth/callback`

**Note:** Environment variables take precedence over Info.plist if both are set.

### 9. Build and Test

1. Select the **FocusOS** scheme in the toolbar
2. Build (Cmd+B)
3. Run (Cmd+R)
4. Test OAuth authentication in Settings
5. Test background posting toggle

## Troubleshooting

### Files Not Detected by Helper Target

If files aren't showing up:
1. Clean build folder (Cmd+Shift+K)
2. Close and reopen Xcode
3. Manually add files to target via File Inspector

### Helper App Not Starting

- Verify `LSBackgroundOnly` = `YES` in Info tab
- Check Console.app for XPC errors
- Ensure XPC service name matches: `com.kosmicapps.FocusOS.Helper`

### OAuth Not Working

- Verify redirect URI matches Meta App settings
- Check sandbox allows network connections
- Test in Console.app for network errors

### Build Errors About Missing Files

- Ensure shared files have correct target membership
- Check that imports match actual file locations
- Verify File System Synchronization is working

### CloudKit Sync Issues

- Ensure iCloud capabilities are enabled for main app
- Check CloudKit container exists in developer portal
- Verify bundle identifier matches container

## Next Steps

After setup:
1. Test OAuth flow with Threads
2. Test OAuth flow with Facebook
3. Create and schedule a test post
4. Enable background posting and verify helper runs
5. Test insights fetching

## File Structure

```
FocusOS/
├── Models/          # SwiftData models
├── Views/           # SwiftUI views
├── Services/        # Business logic
├── Utilities/       # Helpers and utilities
├── Shared/          # Shared between targets
└── FocusOSHelper/ # Background helper app
```

Both targets share common files via target membership, which is the modern Xcode 16 approach.
