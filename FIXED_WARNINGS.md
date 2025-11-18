# Fixed PublishingService Warnings

## What Was Fixed
Removed unused `accessToken` variables from lines 28 and 54 in PublishingService.swift.

## Still Need to Fix
FocusOSHelper still can't find types from APIModels.swift.

## Add to FocusOSHelper Target:
1. Select `FocusOS/Models/APIModels.swift`
2. Press ⌥⌘1 (File Inspector)
3. ✅ Check FocusOSHelper
4. ❌ Uncheck FocusOSShared

Then clean build (⇧⌘K) → Build (⌘B)

