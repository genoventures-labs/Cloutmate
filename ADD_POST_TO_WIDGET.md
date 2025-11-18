# Add Post Model to FocusOSWidget Target

## Problem
Widget can't find Post type even though it imports FocusOSShared.

## Solution

The Post model files need to be in the FocusOSWidget target.

### In Xcode:

1. **Select** `FocusOSShared/FocusOSShared/FocusOSShared/Models/Post.swift`
2. Press **⌥⌘1** (File Inspector)  
3. **Target Membership**:
   - ✅ **CHECK FocusOSShared** (already there)
   - ✅ **CHECK FocusOSWidget** (ADD THIS!)

4. **Repeat for other model files:**
   - AIMessage.swift
   - AIConversation.swift  
   - Draft.swift
   - InsightSnapshot.swift
   - Platform.swift
   - PlatformAccount.swift
   - Template.swift

All models in `FocusOSShared/FocusOSShared/FocusOSShared/Models/` need FocusOSWidget checked in their target membership.

## After Adding

Clean build (⇧⌘K) → Build (⌘B)

"Cannot find type 'Post'" error should be gone! ✅

