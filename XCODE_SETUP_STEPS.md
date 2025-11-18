# Xcode Setup Steps - Widget & Menu Bar Integration

This guide walks you through setting up the Widget and Menu Bar integration in Xcode.

## Quick Reference

**App Group ID:** `group.kosmicapps.focusos`

**Bundle IDs:**
- Main App: `com.kosmicapps.FocusOS`
- Shared: `com.kosmicapps.FocusOS.FocusOSShared`
- Widget: `com.kosmicapps.FocusOS.FocusOSWidget`
- Menu Bar: `com.kosmicapps.FocusOS.FocusOSMenuBar`

---

## Step 1: Open Project in Xcode

```bash
open "/Users/kosmicapps/Desktop/Kosmic Apps/Projects/FocusOS/FocusOS.xcodeproj"
```

Or simply double-click the `FocusOS.xcodeproj` file.

---

## Step 2: Create Shared Framework Target

1. **File > New > Target**
2. Select **macOS > Framework** 
3. Click **Next**
4. Configure:
   - **Product Name:** `FocusOSShared`
   - **Bundle Identifier:** `com.kosmicapps.FocusOS.FocusOSShared`
   - **Team:** Your development team
   - **Language:** Swift
5. Click **Finish**
6. **Don't activate** the FocusOSShared scheme when prompted

### Add Files to FocusOSShared Target

1. In the Project Navigator, select these files:
   - `FocusOSShared/FocusOSShared/Models/` (all .swift files)
   - `FocusOSShared/FocusOSShared/Services/` (all .swift files)  
   - `FocusOSShared/FocusOSShared/UI/` (all .swift files)
   - `FocusOSShared/FocusOSShared/SharedDataManager.swift`

2. **Right-click > Add Files to "FocusOS"...**

3. In the dialog:
   - ✅ Check "FocusOSShared" under "Add to targets"
   - Select "Create groups"
   - Click "Add"

### Configure FocusOSShared

**Note:** Frameworks don't need entitlements. The app group will be configured on the app targets that use this framework.

---

## Step 3: Create Widget Extension Target

1. **File > New > Target**
2. Select **macOS > Widget Extension**
3. Click **Next**
4. Configure:
   - **Product Name:** `FocusOSWidget`
   - **Bundle Identifier:** `com.kosmicapps.FocusOS.FocusOSWidget`
   - **Team:** Your development team
   - **Widget Extension Language:** Swift
   - **Include Configuration Intent:** ❌ No
5. Click **Finish**
6. **Don't activate** the FocusOSWidget scheme

### Add Files to FocusOSWidget Target

1. Select these files:
   - `FocusOSWidget/FocusOSWidget.swift`
   - `FocusOSWidget/WidgetTimelineProvider.swift`
   - `FocusOSWidget/FocusOSWidgetView.swift`

2. **Right-click > Add Files to "FocusOS"...**

3. In the dialog:
   - ✅ Check "FocusOSWidget" under "Add to targets"
   - Click "Add"

### Configure FocusOSWidget Capabilities

1. Select **FocusOSWidget** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Check box for `group.kosmicapps.focusos`

---

## Step 4: Create Menu Bar App Target

1. **File > New > Target**
2. Select **macOS > App**
3. Click **Next**
4. Configure:
   - **Product Name:** `FocusOSMenuBar`
   - **Bundle Identifier:** `com.kosmicapps.FocusOS.FocusOSMenuBar`
   - **Team:** Your development team
   - **Language:** Swift
   - **Interface:** SwiftUI
   - **Storage:** SwiftData
5. Click **Finish**
6. **Don't activate** the FocusOSMenuBar scheme

### Delete Default Files

1. Delete the auto-generated files in the FocusOSMenuBar group:
   - `FocusOSMenuBarApp.swift` (or similar)
   - `ContentView.swift`
   - If created automatically

### Add Menu Bar Files to Target

1. Select these files from `FocusOSMenuBar/`:
   - `MenuBarApp.swift`
   - `MenuBarPopoverView.swift`
   - `QuickComposerView.swift`
   - `UpcomingPostsView.swift`
   - `MenuBarSettingsView.swift`

2. **Right-click > Add Files to "FocusOS"...**

3. In the dialog:
   - ✅ Check "FocusOSMenuBar" under "Add to targets"
   - Click "Add"

### Configure FocusOSMenuBar as Agent App

1. Select **FocusOSMenuBar** target
2. Go to **Info** tab
3. Under "Custom macOS Application Target Properties", click **+**
4. Add new key:
   - **Key:** `LSUIElement`
   - **Type:** Boolean
   - **Value:** YES

This hides the app from the Dock.

### Configure FocusOSMenuBar Capabilities

1. Select **FocusOSMenuBar** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups** - check `group.kosmicapps.focusos`
5. Add **App Sandbox**:
   - Enable **Outgoing Connections (Client)**

---

## Step 5: Add Dependencies

### Update FocusOSShared Build Settings

1. Select **FocusOSShared** target
2. Go to **Build Settings**
3. Search for "Swift Language Version"
4. Set to **Swift 5**

### Update FocusOSWidget Dependencies

1. Select **FocusOSWidget** target
2. Go to **General** tab
3. Under **Embedded Binaries**:
   - Click **+**
   - Select **FocusOSShared.framework**
   - Click **Add**

### Update FocusOSMenuBar Dependencies  

1. Select **FocusOSMenuBar** target
2. Go to **General** tab
3. Under **Embedded Binaries**:
   - Click **+**
   - Select **FocusOSShared.framework**
   - Click **Add**

### Update Main App Dependencies

1. Select **FocusOS** target
2. Go to **General** tab
3. Under **Frameworks and Libraries**:
   - Click **+**
   - Select **FocusOSShared.framework**
   - Ensure it's set to **Embed & Sign**

---

## Step 6: Update Main App to Use Shared Container

Open `FocusOS/FocusOSApp.swift` and update the model container:

```swift
var sharedModelContainer: ModelContainer = SharedDataManager.createSharedModelContainer()
```

### Add Import Statement

At the top of files that use shared models, add:

```swift
import FocusOSShared
```

---

## Step 7: Configure Keychain Access Group

Update `FocusOSShared/FocusOSShared/Services/KeychainService.swift`:

Add this property at the top of the class:

```swift
private let accessGroup = "group.kosmicapps.focusos"
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

1. Select **FocusOS** target
2. Go to **Info** tab
3. Expand **URL Types**
4. Click **+** to add a new URL Type
5. Configure:
   - **Identifier:** `com.kosmicapps.focusos`
   - **URL Schemes:** `focusos`
   - **Role:** Editor

### Handle Deep Links in App

Open `FocusOS/FocusOSApp.swift` and add:

```swift
.onOpenURL { url in
    if url.scheme == "focusos" {
        handleDeepLink(url)
    }
}
```

---

## Step 9: Build Settings for All Targets

For each target (FocusOS, FocusOSShared, FocusOSWidget, FocusOSMenuBar):

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

1. **Select Scheme:** FocusOS
   - **Product > Build** (⌘B)
   
2. **Select Scheme:** FocusOSShared
   - **Product > Build**
   
3. **Select Scheme:** FocusOSWidget
   - **Product > Build**
   
4. **Select Scheme:** FocusOSMenuBar
   - **Product > Build**

### Run the Widget

1. Select **FocusOSWidget** scheme
2. Click **Run** (⌘R)
3. Choose the widget when prompted
4. Add it to your desktop

### Run the Menu Bar App

1. Select **FocusOSMenuBar** scheme
2. Click **Run** (⌘R)
3. Look for the menu bar icon in your status bar

---

## Troubleshooting

### "No such module 'FocusOSShared'"

- Ensure FocusOSShared is added as a dependency
- Clean build folder (⇧⌘K)
- Restart Xcode

### "App Group not found"

- Verify app group ID: `group.kosmicapps.focusos`
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
FocusOS.xcodeproj
├── FocusOS (Main App)
│   ├── Models/ → (will import from FocusOSShared)
│   └── Views/
├── FocusOSShared (Framework)
│   ├── Models/
│   ├── Services/
│   └── UI/
├── FocusOSWidget (Widget Extension)
│   ├── FocusOSWidget.swift
│   ├── WidgetTimelineProvider.swift
│   └── FocusOSWidgetView.swift
└── FocusOSMenuBar (Menu Bar App)
    ├── MenuBarApp.swift
    ├── MenuBarPopoverView.swift
    ├── QuickComposerView.swift
    ├── UpcomingPostsView.swift
    └── MenuBarSettingsView.swift
```

---

## Next Steps After Setup

1. Move remaining services to FocusOSShared:
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
   import FocusOSShared
   ```

3. Test data sync between apps
4. Test publishing from menu bar
5. Test widget refresh

---

## Quick Command Reference

```bash
# Open project
open FocusOS.xcodeproj

# Clean build
xcodebuild clean -project FocusOS.xcodeproj

# Build all targets
xcodebuild -project FocusOS.xcodeproj -scheme FocusOS build
xcodebuild -project FocusOS.xcodeproj -scheme FocusOSShared build
xcodebuild -project FocusOS.xcodeproj -scheme FocusOSWidget build
xcodebuild -project FocusOS.xcodeproj -scheme FocusOSMenuBar build
```

---

**Need help?** Check the console output in Xcode or Terminal for detailed error messages.

