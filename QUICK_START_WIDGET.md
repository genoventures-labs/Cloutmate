# Quick Start: Widget & Menu Bar Setup

## 🚀 Quick Setup (15 minutes)

Follow these steps to complete the Widget and Menu Bar integration:

### 1. Open Xcode Project

```bash
open Cloutmate.xcodeproj
```

### 2. Create CloutmateShared Framework

1. **File → New → Target → macOS → Framework**
   - Name: `CloutmateShared`
   - Bundle ID: `com.kosmicapps.Cloutmate.CloutmateShared`

2. **Add files to target:**
   ```
   - CloutmateShared/CloutmateShared/Models/*.swift
   - CloutmateShared/CloutmateShared/Services/*.swift  
   - CloutmateShared/CloutmateShared/UI/*.swift
   - CloutmateShared/CloutmateShared/SharedDataManager.swift
   ```

### 3. Create CloutmateWidget Extension

1. **File → New → Target → macOS → Widget Extension**
   - Name: `CloutmateWidget`
   - Bundle ID: `com.kosmicapps.Cloutmate.CloutmateWidget`
   - Include Configuration Intent: **No**

2. **Add App Groups capability**
   - Add group: `group.kosmicapps.cloutmate`

3. **Add CloutmateShared as dependency:**
   - General tab → Frameworks → + → Add CloutmateShared.framework

4. **Add files to target:**
   ```
   - CloutmateWidget/CloutmateWidget.swift
   - CloutmateWidget/WidgetTimelineProvider.swift
   - CloutmateWidget/CloutmateWidgetView.swift
   ```

### 4. Create CloutmateMenuBar App

1. **File → New → Target → macOS → App**
   - Name: `CloutmateMenuBar`
   - Bundle ID: `com.kosmicapps.Cloutmate.CloutmateMenuBar`

2. **Configure as agent app** (Info tab):
   - Add key: `LSUIElement` = **YES**

3. **Add App Groups & App Sandbox capabilities**
   - Add group: `group.kosmicapps.cloutmate`
   - Enable **Outgoing Connections**

4. **Add CloutmateShared as dependency**

5. **Add files to target:**
   ```
   - CloutmateMenuBar/MenuBarApp.swift
   - CloutmateMenuBar/MenuBarPopoverView.swift
   - CloutmateMenuBar/QuickComposerView.swift
   - CloutmateMenuBar/UpcomingPostsView.swift
   - CloutmateMenuBar/MenuBarSettingsView.swift
   ```

### 5. Update Main App Container

**Open** `Cloutmate/CloutmateApp.swift`

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
import CloutmateShared
```

### 6. Update Keychain Service

**Open** `CloutmateShared/CloutmateShared/Services/KeychainService.swift`

**Add** after line 14:
```swift
private let accessGroup = "group.kosmicapps.cloutmate"
```

**Update** all `kSecAttrAccessGroup` references to use `accessGroup` variable.

### 7. Update Imports in Main App

For any files using Post, Draft, Platform models, add:
```swift
import CloutmateShared
```

**Files to update:**
- Most files in `Cloutmate/Models/`
- Most files in `Cloutmate/Views/`
- `CloutmateApp.swift`

### 8. Build & Test

1. **Build CloutmateShared**
   - Product → Build (⌘B)

2. **Build CloutmateWidget**  
   - Product → Build

3. **Build CloutmateMenuBar**
   - Product → Build

4. **Run Widget**
   - Select CloutmateWidget scheme → Run → Add to desktop

5. **Run Menu Bar**
   - Select CloutmateMenuBar scheme → Run → Check menu bar icon

---

## 📋 Checklist

- [ ] CloutmateShared framework created and configured
- [ ] CloutmateWidget extension created and configured  
- [ ] CloutmateMenuBar app created and configured
- [ ] App Groups capability added to all targets
- [ ] CloutmateShared added as dependency to widget and menu bar
- [ ] Main app updated to use shared container
- [ ] Keychain service updated for app group
- [ ] All imports updated
- [ ] All targets build successfully
- [ ] Widget appears on desktop
- [ ] Menu bar icon appears

---

## 🔧 Common Issues

**"No such module 'CloutmateShared'"**
→ Add CloutmateShared.framework to target's dependencies

**"App Group not found"**  
→ Verify all targets use same app group ID: `group.kosmicapps.cloutmate`

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

