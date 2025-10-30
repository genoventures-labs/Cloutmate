# Add Post Model to CloutmateWidget Target

## Problem
Widget can't find Post type even though it imports CloutmateShared.

## Solution

The Post model files need to be in the CloutmateWidget target.

### In Xcode:

1. **Select** `CloutmateShared/CloutmateShared/CloutmateShared/Models/Post.swift`
2. Press **⌥⌘1** (File Inspector)  
3. **Target Membership**:
   - ✅ **CHECK CloutmateShared** (already there)
   - ✅ **CHECK CloutmateWidget** (ADD THIS!)

4. **Repeat for other model files:**
   - AIMessage.swift
   - AIConversation.swift  
   - Draft.swift
   - InsightSnapshot.swift
   - Platform.swift
   - PlatformAccount.swift
   - Template.swift

All models in `CloutmateShared/CloutmateShared/CloutmateShared/Models/` need CloutmateWidget checked in their target membership.

## After Adding

Clean build (⇧⌘K) → Build (⌘B)

"Cannot find type 'Post'" error should be gone! ✅

