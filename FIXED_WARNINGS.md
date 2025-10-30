# Fixed PublishingService Warnings

## What Was Fixed
Removed unused `accessToken` variables from lines 28 and 54 in PublishingService.swift.

## Still Need to Fix
CloudmateHelper still can't find types from APIModels.swift.

## Add to CloudmateHelper Target:
1. Select `Cloutmate/Models/APIModels.swift`
2. Press ⌥⌘1 (File Inspector)
3. ✅ Check CloudmateHelper
4. ❌ Uncheck CloutmateShared

Then clean build (⇧⌘K) → Build (⌘B)

