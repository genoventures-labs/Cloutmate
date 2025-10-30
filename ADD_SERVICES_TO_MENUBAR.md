# Add Service Files to CloutmateMenuBar Target

## Problem
Menu bar can't find XPCService and PublishingService.

## Solution

These service files need to be in the CloutmateMenuBar target.

### In Xcode:

1. **Select** `CloutmateShared/CloutmateShared/CloutmateShared/Services/XPCService.swift`
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK CloutmateMenuBar** (ADD THIS!)

4. **Select** `CloutmateShared/CloutmateShared/CloutmateShared/Services/PublishingService.swift`
5. Press **⌥⌘1** (File Inspector)
6. **Target Membership**:
   - ✅ **CHECK CloutmateMenuBar** (ADD THIS!)

These service files need to be in the CloutmateMenuBar target to be accessible.

## After Adding

Clean build (⇧⌘K) → Build (⌘B)

"Cannot find 'XPCService'" and "Cannot find 'PublishingService'" errors should be gone! ✅

