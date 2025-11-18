# Add APIModels.swift to FocusOSHelper Target

## Problem
FocusOSHelper can't find types like:
- `Platform`
- `OAuthTokenResponse`
- `AccountInfoResponse`
- `FacebookPagesResponse`
- etc.

These are defined in `APIModels.swift` which is NOT in the FocusOSHelper target.

## Solution

### In Xcode:

1. **Select** `FocusOS/Models/APIModels.swift`
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK FocusOS** (already there)
   - ✅ **CHECK FocusOSHelper** (ADD THIS!)
   - ❌ Keep FocusOSShared unchecked

## Why?

FocusOSHelper needs to compile MetaAPIService, ThreadsService, and FacebookService, which all depend on types defined in `APIModels.swift`.

Without APIModels.swift in the FocusOSHelper target, it can't find these types → compilation errors.

## After Adding

Clean build (⇧⌘K) → Build (⌘B)

The "Cannot find type" errors should be gone! ✅

