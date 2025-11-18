# Add Service Files to FocusOSMenuBar Target

## Problem
Menu bar can't find XPCService and PublishingService.

## Solution

These service files need to be in the FocusOSMenuBar target.

### In Xcode:

1. **Select** `FocusOSShared/FocusOSShared/FocusOSShared/Services/XPCService.swift`
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK FocusOSMenuBar** (ADD THIS!)

4. **Select** `FocusOSShared/FocusOSShared/FocusOSShared/Services/PublishingService.swift`
5. Press **⌥⌘1** (File Inspector)
6. **Target Membership**:
   - ✅ **CHECK FocusOSMenuBar** (ADD THIS!)

These service files need to be in the FocusOSMenuBar target to be accessible.

## After Adding

Clean build (⇧⌘K) → Build (⌘B)

"Cannot find 'XPCService'" and "Cannot find 'PublishingService'" errors should be gone! ✅

