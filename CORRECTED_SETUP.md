# Corrected Setup - Widget & Menu Bar

## Important: Framework vs App Entitlements

**FocusOSShared is a Framework** - it does NOT need:
- ❌ Entitlements file
- ❌ App Groups capability
- ❌ Signing & Capabilities configuration

**The app targets** (FocusOS, FocusOSWidget, FocusOSMenuBar) DO need:
- ✅ Entitlements file
- ✅ App Groups capability

---

## Correct Setup Steps

### 1. Create FocusOSShared Framework

In Xcode:
1. **File → New → Target → macOS → Framework**
2. Name: `FocusOSShared`
3. Click **Finish**
4. **DO NOT** configure capabilities (frameworks don't need them)

### 2. Add Files to FocusOSShared

Right-click and add these files to the FocusOSShared target:
- `FocusOSShared/FocusOSShared/Models/*.swift`
- `FocusOSShared/FocusOSShared/Services/*.swift`
- `FocusOSShared/FocusOSShared/UI/*.swift`
- `FocusOSShared/FocusOSShared/SharedDataManager.swift`

**In the add files dialog:**
- ✅ Check "FocusOSShared" under "Add to targets"
- Click "Add"

### 3. Add App Groups to Main App

Select **FocusOS** target (the main app):
1. Go to **Signing & Capabilities**
2. Click **+ Capability**
3. Add **App Groups**
4. Check: `group.kosmicapps.focusos`

### 4. Add App Groups to Widget

Select **FocusOSWidget** target:
1. Add files to target:
   - `FocusOSWidget/FocusOSWidget.swift`
   - `FocusOSWidget/WidgetTimelineProvider.swift`
   - `FocusOSWidget/FocusOSWidgetView.swift`
2. Go to **General** tab
3. Under **Frameworks**: Click + → Add `FocusOSShared.framework`
4. Go to **Signing & Capabilities**
5. Add **App Groups**: `group.kosmicapps.focusos`

### 5. Add App Groups to Menu Bar App

Select **FocusOSMenuBar** target:
1. Add files to target:
   - `MenuBarApp.swift`
   - `MenuBarPopoverView.swift`
   - `QuickComposerView.swift`
   - `UpcomingPostsView.swift`
   - `MenuBarSettingsView.swift`
2. Go to **General** tab
3. Under **Frameworks**: Click + → Add `FocusOSShared.framework`
4. Go to **Signing & Capabilities**
5. Add **App Groups**: `group.kosmicapps.focusos`
6. Add **App Sandbox**:
   - Enable **Outgoing Connections (Client)**
7. Go to **Info** tab
8. Add key: `LSUIElement` = **YES**

---

## Summary: What Needs Entitlements?

| Target | Type | Needs Entitlements? | Needs App Groups? |
|--------|------|-------------------|-------------------|
| FocusOS | App | ✅ Yes | ✅ Yes |
| FocusOSShared | Framework | ❌ No | ❌ No |
| FocusOSWidget | Widget Extension | ✅ Yes | ✅ Yes |
| FocusOSMenuBar | App | ✅ Yes | ✅ Yes |

---

## Key Files Location

```
FocusOS/
├── FocusOS.entitlements ✅ (has App Groups)
├── FocusOSWidget.entitlements ✅ (has App Groups)
├── FocusOSMenuBar.entitlements ✅ (has App Groups)
├── FocusOSShared/ ❌ (no entitlements needed)
```

---

## Quick Fix for Your Error

If you're seeing "Capabilities for FocusOSShared are not supported":

1. **Select FocusOSShared target**
2. Go to **Signing & Capabilities** tab
3. **Remove any capabilities** you added there
4. Frameworks just compile code - they don't need signing or capabilities
5. The app targets (FocusOS, FocusOSWidget, FocusOSMenuBar) handle the entitlements

---

## Build Order

1. Build FocusOSShared first (it's a dependency)
2. Build the apps that use it (FocusOS, FocusOSWidget, FocusOSMenuBar)

The FocusOSShared framework will be automatically linked to the apps that use it.

