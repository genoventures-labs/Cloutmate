# Integration Phases - FocusOS Widget & Menu Bar

## ✅ Phase 1: Shared Framework (COMPLETED)
- Created FocusOSShared framework
- Added all models and UI components
- Added services (Keychain, XPC, Publishing, MetaAPI)
- Configured for app group storage
- ✅ **Status:** Files added to target

## ✅ Phase 2: App Group Configuration (COMPLETED)
- Updated main app entitlements
- Created widget entitlements
- Created menu bar entitlements
- ✅ **Status:** App group configured

## Phase 3: Add Widget Files to Target

### Steps:

1. **Select Widget files** in Project Navigator:
   - `FocusOSWidget/FocusOSWidget.swift`
   - `FocusOSWidget/WidgetTimelineProvider.swift`
   - `FocusOSWidget/FocusOSWidgetView.swift`

2. **For each file:**
   - Press ⌥⌘1 (File Inspector)
   - Check ✅ **FocusOSWidget** in Target Membership

3. **Add FocusOSShared as dependency:**
   - Select **FocusOSWidget** target
   - General tab → Frameworks
   - Click + → Add **FocusOSShared.framework**
   - Set to **Embed & Sign**

---

## Phase 4: Add Menu Bar Files to Target

### Steps:

1. **Select Menu Bar files** in Project Navigator:
   - `MenuBarApp.swift`
   - `MenuBarPopoverView.swift`
   - `QuickComposerView.swift`
   - `UpcomingPostsView.swift`
   - `MenuBarSettingsView.swift`

2. **For each file:**
   - Press ⌥⌘1 (File Inspector)
   - Check ✅ **FocusOSMenuBar** in Target Membership

3. **Add FocusOSShared as dependency:**
   - Select **FocusOSMenuBar** target
   - General tab → Frameworks
   - Click + → Add **FocusOSShared.framework**
   - Set to **Embed & Sign**

---

## Phase 5: Update Main App to Use Shared Container

### File: `FocusOS/FocusOSApp.swift`

Find this section (around line 19-40):
```swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Post.self,
        Draft.self,
        // ...
    ])
    
    let config = ModelConfiguration(schema: schema, ...)
    // ...
}()
```

**Replace with:**
```swift
var sharedModelContainer: ModelContainer = SharedDataManager.createSharedModelContainer()
```

**Add import at top:**
```swift
import FocusOSShared
```

---

## Phase 6: Update Imports in Main App

Files that need updating:
- Any file using `Post`, `Draft`, `Platform` models
- Any file using glassmorphic UI components

**Add this import to affected files:**
```swift
import FocusOSShared
```

### Quick Find & Replace:

1. Open Find (⌘F) → Replace (⌥⌘F)
2. Search: `import Foundation`
3. Add line: `import FocusOSShared`
4. Replace in files that use shared models

### Files to Update:

Check these files for imports:
- Views in `FocusOS/Views/`
- ViewModels in `FocusOS/ViewModels/`
- Services that use models

---

## Phase 7: Build & Test

### Build Each Target:

```bash
# 1. Build Shared Framework first
xcodebuild -project FocusOS.xcodeproj -scheme FocusOSShared build

# 2. Build Widget
xcodebuild -project FocusOS.xcodeproj -scheme FocusOSWidget build

# 3. Build Menu Bar
xcodebuild -project FocusOS.xcodeproj -scheme FocusOSMenuBar build

# 4. Build Main App
xcodebuild -project FocusOS.xcodeproj -scheme FocusOS build
```

Or in Xcode:
1. Select scheme: FocusOSShared
2. Product → Build (⌘B)
3. Repeat for other targets

---

## Phase 8: Test Integration

### Test 1: Widget Timeline
1. Select **FocusOSWidget** scheme
2. Run (⌘R)
3. When prompted, choose widget
4. Add to desktop
5. Should show scheduled post count

### Test 2: Menu Bar App
1. Select **FocusOSMenuBar** scheme
2. Run (⌘R)
3. Look for menu bar icon
4. Click to open popover
5. Create a post

### Test 3: Data Sync
1. Run main app
2. Create a scheduled post
3. Run menu bar app
4. Verify post appears in "Upcoming" tab
5. Schedule from menu bar
6. Verify appears in main app

### Test 4: Publishing
1. In menu bar, create post with "Post Now"
2. Select platforms
3. Click "Post Now"
4. Should publish directly (if tokens configured)

---

## Phase 9: Fix Remaining Issues

Common issues and fixes:

### "Module 'FocusOSShared' not found"
- Check target has FocusOSShared.framework linked
- Clean build (⇧⌘K)
- Delete Derived Data

### "Cannot find 'X' in scope"
- Add `import FocusOSShared`
- Check file is in correct target

### Widget not updating
- Check timeline provider has correct data
- Verify SwiftData queries work
- Check Console.app for errors

### Menu bar app crashes
- Check LSUIElement is YES
- Verify entitlements
- Check Console.app

---

## Phase 10: Polish & Finalize

- [ ] Test all features work
- [ ] Fix any compilation errors
- [ ] Test on multiple macOS versions
- [ ] Add app icons
- [ ] Test widget refresh
- [ ] Verify data sync
- [ ] Test publishing flow
- [ ] Document any issues

---

## Quick Status Check

Run this to see current status:

```bash
# Check if all targets build
cd "/Users/kosmicapps/Desktop/Kosmic Apps/Projects/FocusOS"
xcodebuild -list -project FocusOS.xcodeproj | grep -A 20 "Targets"
```

Should show:
- FocusOS
- FocusOSShared
- FocusOSWidget
- FocusOSMenuBar

---

## Next Action

**Current Phase:** 3-4 (Add files to targets)

**What to do now:**
1. Add widget files to FocusOSWidget target
2. Add menu bar files to FocusOSMenuBar target
3. Link FocusOSShared.framework to both
4. Then proceed to Phase 5 (Update main app)

