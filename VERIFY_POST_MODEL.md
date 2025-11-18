# Verify Post Model in FocusOSShared Framework

## Issue
Widget can't find Post type even though FocusOSShared.framework is linked.

## Check These:

### 1. Is Post.swift in FocusOSShared?

Go to:
- `FocusOSShared/FocusOSShared/Models/Post.swift`

This file should exist.

### 2. Is Post.swift in FocusOSShared TARGET?

In Xcode:

1. Select `FocusOSShared/FocusOSShared/Models/Post.swift` file
2. Press ⌥⌘1 (File Inspector)
3. Check **Target Membership**:
   - ✅ **FocusOSShared** should be CHECKED
   - ❌ **FocusOS** (main app) can be checked or not
   - ❌ Other targets should be UNCHECKED

### 3. Rebuild the Framework

After verifying:

1. Select **FocusOSShared** scheme
2. Product → Clean Build Folder (⇧⌘K)
3. Product → Build (⌘B)

### 4. Then Build Widget

1. Select **FocusOSWidget** scheme
2. Product → Build (⌘B)

---

## If Still Not Working

The Post model might be ONLY in the main app, not in the framework.

**Check:** Open `FocusOS/Models/Post.swift` and verify it's NOT in FocusOSShared target.

**Fix:** Add `FocusOSShared/FocusOSShared/Models/Post.swift` to FocusOSShared target in File Inspector.

