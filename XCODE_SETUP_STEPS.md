# Xcode Setup Steps - Widget & Menu Bar Integration

This guide walks you through setting up the Widget and Menu Bar integration in Xcode.

## Quick Reference

**App Group ID:** `group.kosmicapps.cloutmate`

**Bundle IDs:**
- Main App: `com.kosmicapps.Cloutmate`
- Shared: `com.kosmicapps.Cloutmate.CloutmateShared`
- Widget: `com.kosmicapps.Cloutmate.CloutmateWidget`
- Menu Bar: `com.kosmicapps.Cloutmate.CloutmateMenuBar`

---

## Step 1: Open Project in Xcode

```bash
open "/Users/kosmicapps/Desktop/Kosmic Apps/Projects/Cloutmate/Cloutmate.xcodeproj"
```

Or simply double-click the `Cloutmate.xcodeproj` file.

---

## Step 2: Create Shared Framework Target

1. **File > New > Target**
2. Select **macOS > Framework** 
3. Click **Next**
4. Configure:
   - **Product Name:** `CloutmateShared`
   - **Bundle Identifier:** `com.kosmicapps.Cloutmate.CloutmateShared`
   - **Team:** Your development team
   - **Language:** Swift
5. Click **Finish**
6. **Don't activate** the CloutmateShared scheme when prompted

### Add Files to CloutmateShared Target

1. In the Project Navigator, select these files:
   - `CloutmateShared/CloutmateShared/Models/` (all .swift files)
   - `CloutmateShared/CloutmateShared/Services/` (all .swift files)  
   - `CloutmateShared/CloutmateShared/UI/` (all .swift files)
   - `CloutmateShared/CloutmateShared/SharedDataManager.swift`

2. **Right-click > Add Files to "Cloutmate"...**

3. In the dialog:
   - ✅ Check "CloutmateShared" under "Add to targets"
   - Select "Create groups"
   - Click "Add"

### Configure CloutmateShared

**Note:** Frameworks don't need entitlements. The app group will be configured on the app targets that use this framework.

---

## Step 3: Create Widget Extension Target

1. **File > New > Target**
2. Select **macOS > Widget Extension**
3. Click **Next**
4. Configure:
   - **Product Name:** `CloutmateWidget`
   - **Bundle Identifier:** `com.kosmicapps.Cloutmate.CloutmateWidget`
   - **Team:** Your development team
   - **Widget Extension Language:** Swift
   - **Include Configuration Intent:** ❌ No
5. Click **Finish**
6. **Don't activate** the CloutmateWidget scheme

### Add Files to CloutmateWidget Target

1. Select these files:
   - `CloutmateWidget/CloutmateWidget.swift`
   - `CloutmateWidget/WidgetTimelineProvider.swift`
   - `CloutmateWidget/CloutmateWidgetView.swift`

2. **Right-click > Add Files to "Cloutmate"...**

3. In the dialog:
   - ✅ Check "CloutmateWidget" under "Add to targets"
   - Click "Add"

### Configure CloutmateWidget Capabilities

1. Select **CloutmateWidget** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Check box for `group.kosmicapps.cloutmate`

---

## Step 4: Create Menu Bar App Target

1. **File > New > Target**
2. Select **macOS > App**
3. Click **Next**
4. Configure:
   - **Product Name:** `CloutmateMenuBar`
   - **Bundle Identifier:** `com.kosmicapps.Cloutmate.CloutmateMenuBar`
   - **Team:** Your development team
   - **Language:** Swift
   - **Interface:** SwiftUI
   - **Storage:** SwiftData
5. Click **Finish**
6. **Don't activate** the CloutmateMenuBar scheme

### Delete Default Files

1. Delete the auto-generated files in the CloutmateMenuBar group:
   - `CloutmateMenuBarApp.swift` (or similar)
   - `ContentView.swift`
   - If created automatically

### Add Menu Bar Files to Target

1. Select these files from `CloutmateMenuBar/`:
   - `MenuBarApp.swift`
   - `MenuBarPopoverView.swift`
   - `QuickComposerView.swift`
   - `UpcomingPostsView.swift`
   - `MenuBarSettingsView.swift`

2. **Right-click > Add Files to "Cloutmate"...**

3. In the dialog:
   - ✅ Check "CloutmateMenuBar" under "Add to targets"
   - Click "Add"

### Configure CloutmateMenuBar as Agent App

1. Select **CloutmateMenuBar** target
2. Go to **Info** tab
3. Under "Custom macOS Application Target Properties", click **+**
4. Add new key:
   - **Key:** `LSUIElement`
   - **Type:** Boolean
   - **Value:** YES

This hides the app from the Dock.

### Configure CloutmateMenuBar Capabilities

1. Select **CloutmateMenuBar** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups** - check `group.kosmicapps.cloutmate`
5. Add **App Sandbox**:
   - Enable **Outgoing Connections (Client)**

---

## Step 5: Add Dependencies

### Update CloutmateShared Build Settings

1. Select **CloutmateShared** target
2. Go to **Build Settings**
3. Search for "Swift Language Version"
4. Set to **Swift 5**

### Update CloutmateWidget Dependencies

1. Select **CloutmateWidget** target
2. Go to **General** tab
3. Under **Embedded Binaries**:
   - Click **+**
   - Select **CloutmateShared.framework**
   - Click **Add**

### Update CloutmateMenuBar Dependencies  

1. Select **CloutmateMenuBar** target
2. Go to **General** tab
3. Under **Embedded Binaries**:
   - Click **+**
   - Select **CloutmateShared.framework**
   - Click **Add**

### Update Main App Dependencies

1. Select **Cloutmate** target
2. Go to **General** tab
3. Under **Frameworks and Libraries**:
   - Click **+**
   - Select **CloutmateShared.framework**
   - Ensure it's set to **Embed & Sign**

---

## Step 6: Update Main App to Use Shared Container

Open `Cloutmate/CloutmateApp.swift` and update the model container:

```swift
var sharedModelContainer: ModelContainer = SharedDataManager.createSharedModelContainer()
```

### Add Import Statement

At the top of files that use shared models, add:

```swift
import CloutmateShared
```

---

## Step 7: Configure Keychain Access Group

Update `CloutmateShared/CloutmateShared/Services/KeychainService.swift`:

Add this property at the top of the class:

```swift
private let accessGroup = "group.kosmicapps.cloutmate"
```

Then update the `saveToken` and `getToken` methods to use:

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: account,
    kSecAttrService as String: serviceName,
    kSecValueData as String: token,
    kSecAttrAccessGroup as String: accessGroup
]
```

---

## Step 8: Add URL Scheme (Deep Linking)

1. Select **Cloutmate** target
2. Go to **Info** tab
3. Expand **URL Types**
4. Click **+** to add a new URL Type
5. Configure:
   - **Identifier:** `com.kosmicapps.cloutmate`
   - **URL Schemes:** `cloutmate`
   - **Role:** Editor

### Handle Deep Links in App

Open `Cloutmate/CloutmateApp.swift` and add:

```swift
.onOpenURL { url in
    if url.scheme == "cloutmate" {
        handleDeepLink(url)
    }
}
```

---

## Step 9: Build Settings for All Targets

For each target (Cloutmate, CloutmateShared, CloutmateWidget, CloutmateMenuBar):

1. Select the target
2. Go to **Build Settings**
3. Set:
   - **Swift Language Version:** Swift 5
   - **Minimum Deployment:** macOS 14.0
4. Under **Signing**:
   - Enable **Automatically manage signing**
   - Select your **Team**
   - Check **Capabilities** tab for app group

---

## Step 10: Test the Integration

### Build Each Target

1. **Select Scheme:** Cloutmate
   - **Product > Build** (⌘B)
   
2. **Select Scheme:** CloutmateShared
   - **Product > Build**
   
3. **Select Scheme:** CloutmateWidget
   - **Product > Build**
   
4. **Select Scheme:** CloutmateMenuBar
   - **Product > Build**

### Run the Widget

1. Select **CloutmateWidget** scheme
2. Click **Run** (⌘R)
3. Choose the widget when prompted
4. Add it to your desktop

### Run the Menu Bar App

1. Select **CloutmateMenuBar** scheme
2. Click **Run** (⌘R)
3. Look for the menu bar icon in your status bar

---

## Troubleshooting

### "No such module 'CloutmateShared'"

- Ensure CloutmateShared is added as a dependency
- Clean build folder (⇧⌘K)
- Restart Xcode

### "App Group not found"

- Verify app group ID: `group.kosmicapps.cloutmate`
- Check all targets have the capability enabled
- Ensure same team is used for all targets

### Widget Not Updating

- Check widget timeline in Xcode
- Verify SwiftData queries are working
- Check console for errors

### Menu Bar App Not Starting

- Check LSUIElement is set to YES
- Verify app has correct entitlements
- Check Console.app for errors

---

## File Structure After Setup

```
Cloutmate.xcodeproj
├── Cloutmate (Main App)
│   ├── Models/ → (will import from CloutmateShared)
│   └── Views/
├── CloutmateShared (Framework)
│   ├── Models/
│   ├── Services/
│   └── UI/
├── CloutmateWidget (Widget Extension)
│   ├── CloutmateWidget.swift
│   ├── WidgetTimelineProvider.swift
│   └── CloutmateWidgetView.swift
└── CloutmateMenuBar (Menu Bar App)
    ├── MenuBarApp.swift
    ├── MenuBarPopoverView.swift
    ├── QuickComposerView.swift
    ├── UpcomingPostsView.swift
    └── MenuBarSettingsView.swift
```

---

## Next Steps After Setup

1. Move remaining services to CloutmateShared:
   - `ThreadsService.swift`
   - `FacebookService.swift`
   - `MetaAPIService.swift`

2. Update all imports in main app from:
   ```swift
   import Foundation
   ```
   to:
   ```swift
   import Foundation
   import CloutmateShared
   ```

3. Test data sync between apps
4. Test publishing from menu bar
5. Test widget refresh

---

## Quick Command Reference

```bash
# Open project
open Cloutmate.xcodeproj

# Clean build
xcodebuild clean -project Cloutmate.xcodeproj

# Build all targets
xcodebuild -project Cloutmate.xcodeproj -scheme Cloutmate build
xcodebuild -project Cloutmate.xcodeproj -scheme CloutmateShared build
xcodebuild -project Cloutmate.xcodeproj -scheme CloutmateWidget build
xcodebuild -project Cloutmate.xcodeproj -scheme CloutmateMenuBar build
```

---

**Need help?** Check the console output in Xcode or Terminal for detailed error messages.

