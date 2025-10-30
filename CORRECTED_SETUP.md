# Corrected Setup - Widget & Menu Bar

## Important: Framework vs App Entitlements

**CloutmateShared is a Framework** - it does NOT need:
- ❌ Entitlements file
- ❌ App Groups capability
- ❌ Signing & Capabilities configuration

**The app targets** (Cloutmate, CloutmateWidget, CloutmateMenuBar) DO need:
- ✅ Entitlements file
- ✅ App Groups capability

---

## Correct Setup Steps

### 1. Create CloutmateShared Framework

In Xcode:
1. **File → New → Target → macOS → Framework**
2. Name: `CloutmateShared`
3. Click **Finish**
4. **DO NOT** configure capabilities (frameworks don't need them)

### 2. Add Files to CloutmateShared

Right-click and add these files to the CloutmateShared target:
- `CloutmateShared/CloutmateShared/Models/*.swift`
- `CloutmateShared/CloutmateShared/Services/*.swift`
- `CloutmateShared/CloutmateShared/UI/*.swift`
- `CloutmateShared/CloutmateShared/SharedDataManager.swift`

**In the add files dialog:**
- ✅ Check "CloutmateShared" under "Add to targets"
- Click "Add"

### 3. Add App Groups to Main App

Select **Cloutmate** target (the main app):
1. Go to **Signing & Capabilities**
2. Click **+ Capability**
3. Add **App Groups**
4. Check: `group.kosmicapps.cloutmate`

### 4. Add App Groups to Widget

Select **CloutmateWidget** target:
1. Add files to target:
   - `CloutmateWidget/CloutmateWidget.swift`
   - `CloutmateWidget/WidgetTimelineProvider.swift`
   - `CloutmateWidget/CloutmateWidgetView.swift`
2. Go to **General** tab
3. Under **Frameworks**: Click + → Add `CloutmateShared.framework`
4. Go to **Signing & Capabilities**
5. Add **App Groups**: `group.kosmicapps.cloutmate`

### 5. Add App Groups to Menu Bar App

Select **CloutmateMenuBar** target:
1. Add files to target:
   - `MenuBarApp.swift`
   - `MenuBarPopoverView.swift`
   - `QuickComposerView.swift`
   - `UpcomingPostsView.swift`
   - `MenuBarSettingsView.swift`
2. Go to **General** tab
3. Under **Frameworks**: Click + → Add `CloutmateShared.framework`
4. Go to **Signing & Capabilities**
5. Add **App Groups**: `group.kosmicapps.cloutmate`
6. Add **App Sandbox**:
   - Enable **Outgoing Connections (Client)**
7. Go to **Info** tab
8. Add key: `LSUIElement` = **YES**

---

## Summary: What Needs Entitlements?

| Target | Type | Needs Entitlements? | Needs App Groups? |
|--------|------|-------------------|-------------------|
| Cloutmate | App | ✅ Yes | ✅ Yes |
| CloutmateShared | Framework | ❌ No | ❌ No |
| CloutmateWidget | Widget Extension | ✅ Yes | ✅ Yes |
| CloutmateMenuBar | App | ✅ Yes | ✅ Yes |

---

## Key Files Location

```
Cloutmate/
├── Cloutmate.entitlements ✅ (has App Groups)
├── CloutmateWidget.entitlements ✅ (has App Groups)
├── CloutmateMenuBar.entitlements ✅ (has App Groups)
├── CloutmateShared/ ❌ (no entitlements needed)
```

---

## Quick Fix for Your Error

If you're seeing "Capabilities for CloutmateShared are not supported":

1. **Select CloutmateShared target**
2. Go to **Signing & Capabilities** tab
3. **Remove any capabilities** you added there
4. Frameworks just compile code - they don't need signing or capabilities
5. The app targets (Cloutmate, CloutmateWidget, CloutmateMenuBar) handle the entitlements

---

## Build Order

1. Build CloutmateShared first (it's a dependency)
2. Build the apps that use it (Cloutmate, CloutmateWidget, CloutmateMenuBar)

The CloutmateShared framework will be automatically linked to the apps that use it.

