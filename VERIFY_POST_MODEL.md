# Verify Post Model in CloutmateShared Framework

## Issue
Widget can't find Post type even though CloutmateShared.framework is linked.

## Check These:

### 1. Is Post.swift in CloutmateShared?

Go to:
- `CloutmateShared/CloutmateShared/Models/Post.swift`

This file should exist.

### 2. Is Post.swift in CloutmateShared TARGET?

In Xcode:

1. Select `CloutmateShared/CloutmateShared/Models/Post.swift` file
2. Press ⌥⌘1 (File Inspector)
3. Check **Target Membership**:
   - ✅ **CloutmateShared** should be CHECKED
   - ❌ **Cloutmate** (main app) can be checked or not
   - ❌ Other targets should be UNCHECKED

### 3. Rebuild the Framework

After verifying:

1. Select **CloutmateShared** scheme
2. Product → Clean Build Folder (⇧⌘K)
3. Product → Build (⌘B)

### 4. Then Build Widget

1. Select **CloutmateWidget** scheme
2. Product → Build (⌘B)

---

## If Still Not Working

The Post model might be ONLY in the main app, not in the framework.

**Check:** Open `Cloutmate/Models/Post.swift` and verify it's NOT in CloutmateShared target.

**Fix:** Add `CloutmateShared/CloutmateShared/Models/Post.swift` to CloutmateShared target in File Inspector.

