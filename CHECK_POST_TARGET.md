# Check Post.swift Target Membership

## Current Status
✅ SharedDataManager.swift exists: `/FocusOSShared/FocusOSShared/Services/`
✅ Post.swift exists: `/FocusOSShared/FocusOSShared/Models/`

## But widget can't see Post type

This means Post.swift is NOT in the FocusOSShared target.

## Fix in Xcode:

1. Select `FocusOSShared/FocusOSShared/Models/Post.swift`
2. Press ⌥⌘1 (File Inspector)
3. Check **Target Membership**:
   - ✅ **FocusOSShared** - should be CHECKED
   - ❌ Other targets - should be UNCHECKED

Do this for ALL model files in that directory:
- AIMessage.swift
- AISettings.swift  
- Draft.swift
- InsightSnapshot.swift
- Platform.swift
- Platform+UI.swift
- PlatformAccount.swift
- Post.swift
- Template.swift

## After Fixing:

Clean build (⇧⌘K) → Build (⌘B)

The widget should now see the Post type! ✅

