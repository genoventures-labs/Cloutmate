# Add APIModels.swift to CloudmateHelper Target

## Problem
CloudmateHelper can't find types like:
- `Platform`
- `OAuthTokenResponse`
- `AccountInfoResponse`
- `FacebookPagesResponse`
- etc.

These are defined in `APIModels.swift` which is NOT in the CloudmateHelper target.

## Solution

### In Xcode:

1. **Select** `Cloutmate/Models/APIModels.swift`
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK Cloutmate** (already there)
   - ✅ **CHECK CloudmateHelper** (ADD THIS!)
   - ❌ Keep CloutmateShared unchecked

## Why?

CloudmateHelper needs to compile MetaAPIService, ThreadsService, and FacebookService, which all depend on types defined in `APIModels.swift`.

Without APIModels.swift in the CloudmateHelper target, it can't find these types → compilation errors.

## After Adding

Clean build (⇧⌘K) → Build (⌘B)

The "Cannot find type" errors should be gone! ✅

