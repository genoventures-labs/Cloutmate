# Add FocusOSShared Framework to Widget

## Problem
Widget extension can't find `Post` type even though we import `FocusOSShared`.

## Solution: Add Framework Dependency

### In Xcode:

1. **Select FocusOSWidget TARGET** (not the project)
   - Click on "FocusOSWidget" in the target list

2. **Go to General tab**

3. **Scroll to "Frameworks, Libraries, and Embedded Content"**

4. **Click the + button**

5. **In the dialog:**
   - Search for: "FocusOSShared"
   - Select: **FocusOSShared.framework**
   - Click: **Add**

6. **Set to "Embed & Sign"**

### Alternative: Check Build Phases

1. Select **FocusOSWidget** target
2. **Build Phases** tab
3. Check if "Link Binary With Libraries" has **FocusOSShared.framework**

---

## Also Verify in File Inspector

For the widget files themselves:

1. Select each widget file:
   - `FocusOSWidget.swift`
   - `FocusOSWidgetView.swift`
   - `WidgetTimelineProvider.swift`

2. Press **⌥⌘1** (File Inspector)

3. **Target Membership** section:
   - ✅ **FocusOSWidget** should be CHECKED
   - ✅ Other targets should be UNCHECKED

---

## Quick Check

After adding framework:

- Build should work
- "Cannot find Post" errors should be gone
- Widget can access shared models

