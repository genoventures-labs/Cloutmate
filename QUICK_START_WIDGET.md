# Quick Start: Widget & Menu Bar Setup

## 🚀 Quick Setup (15 minutes)

Follow these steps to complete the Widget and Menu Bar integration:

### 1. Open Xcode Project

```bash
open FocusOS.xcodeproj
```

### 2. Create FocusOSShared Framework

1. **File → New → Target → macOS → Framework**
   - Name: `FocusOSShared`
   - Bundle ID: `com.kosmicapps.FocusOS.FocusOSShared`

2. **Add files to target:**
   ```
   - FocusOSShared/FocusOSShared/Models/*.swift
   - FocusOSShared/FocusOSShared/Services/*.swift  
   - FocusOSShared/FocusOSShared/UI/*.swift
   - FocusOSShared/FocusOSShared/SharedDataManager.swift
   ```

### 3. Create FocusOSWidget Extension

1. **File → New → Target → macOS → Widget Extension**
   - Name: `FocusOSWidget`
   - Bundle ID: `com.kosmicapps.FocusOS.FocusOSWidget`
   - Include Configuration Intent: **No**

2. **Add App Groups capability**
   - Add group: `group.kosmicapps.focusos`

3. **Add FocusOSShared as dependency:**
   - General tab → Frameworks → + → Add FocusOSShared.framework

4. **Add files to target:**
   ```
   - FocusOSWidget/FocusOSWidget.swift
   - FocusOSWidget/WidgetTimelineProvider.swift
   - FocusOSWidget/FocusOSWidgetView.swift
   ```

### 4. Create FocusOSMenuBar App

1. **File → New → Target → macOS → App**
   - Name: `FocusOSMenuBar`
   - Bundle ID: `com.kosmicapps.FocusOS.FocusOSMenuBar`

2. **Configure as agent app** (Info tab):
   - Add key: `LSUIElement` = **YES**

3. **Add App Groups & App Sandbox capabilities**
   - Add group: `group.kosmicapps.focusos`
   - Enable **Outgoing Connections**

4. **Add FocusOSShared as dependency**

5. **Add files to target:**
   ```
   - FocusOSMenuBar/MenuBarApp.swift
   - FocusOSMenuBar/MenuBarPopoverView.swift
   - FocusOSMenuBar/QuickComposerView.swift
   - FocusOSMenuBar/UpcomingPostsView.swift
   - FocusOSMenuBar/MenuBarSettingsView.swift
   ```

### 5. Update Main App Container

**Open** `FocusOS/FocusOSApp.swift`

**Replace** this line:
```swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([...])
    ...
}()
```

**With:**
```swift
var sharedModelContainer: ModelContainer = SharedDataManager.createSharedModelContainer()
```

**Add import at top of file:**
```swift
import FocusOSShared
```

### 6. Update Keychain Service

**Open** `FocusOSShared/FocusOSShared/Services/KeychainService.swift`

**Add** after line 14:
```swift
private let accessGroup = "group.kosmicapps.focusos"
```

**Update** all `kSecAttrAccessGroup` references to use `accessGroup` variable.

### 7. Update Imports in Main App

For any files using Post, Draft, Platform models, add:
```swift
import FocusOSShared
```

**Files to update:**
- Most files in `FocusOS/Models/`
- Most files in `FocusOS/Views/`
- `FocusOSApp.swift`

### 8. Build & Test

1. **Build FocusOSShared**
   - Product → Build (⌘B)

2. **Build FocusOSWidget**  
   - Product → Build

3. **Build FocusOSMenuBar**
   - Product → Build

4. **Run Widget**
   - Select FocusOSWidget scheme → Run → Add to desktop

5. **Run Menu Bar**
   - Select FocusOSMenuBar scheme → Run → Check menu bar icon

---

## 📋 Checklist

- [ ] FocusOSShared framework created and configured
- [ ] FocusOSWidget extension created and configured  
- [ ] FocusOSMenuBar app created and configured
- [ ] App Groups capability added to all targets
- [ ] FocusOSShared added as dependency to widget and menu bar
- [ ] Main app updated to use shared container
- [ ] Keychain service updated for app group
- [ ] All imports updated
- [ ] All targets build successfully
- [ ] Widget appears on desktop
- [ ] Menu bar icon appears

---

## 🔧 Common Issues

**"No such module 'FocusOSShared'"**
→ Add FocusOSShared.framework to target's dependencies

**"App Group not found"**  
→ Verify all targets use same app group ID: `group.kosmicapps.focusos`

**Widget not showing data**
→ Check Console.app for SwiftData errors

**Menu bar app not launching**
→ Verify LSUIElement is set to YES in Info.plist

---

## 📖 Detailed Documentation

For complete setup guide, see: **XCODE_SETUP_STEPS.md**

For integration guide, see: **WIDGET_INTEGRATION_GUIDE.md**

---

## 🎯 What You've Built

✅ **Widget** - Shows scheduled post count and next post time  
✅ **Menu Bar App** - Quick composer with glassmorphic UI  
✅ **Shared Storage** - All three apps access same SwiftData container  
✅ **Background Publishing** - Uses existing XPC service  

---

Need help? Check the full setup guide in `XCODE_SETUP_STEPS.md`

