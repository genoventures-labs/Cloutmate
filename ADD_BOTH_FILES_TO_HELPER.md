# Add Both Files to CloudmateHelper Target

## Files Needed by CloudmateHelper

CloudmateHelper compiles services that depend on these types:
- ✅ **Platform.swift** - Defines `Platform` enum
- ✅ **APIModels.swift** - Defines `OAuthTokenResponse`, `AccountInfoResponse`, `FacebookPagesResponse`, etc.

## Solution: Add Both Files

### In Xcode, for EACH file:

#### 1. Platform.swift
1. **Select** `Cloutmate/Models/Platform.swift`
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK Cloutmate** (already there)
   - ✅ **CHECK CloudmateHelper** (ADD THIS!)
   - ✅ **CHECK CloutmateShared** (if not already checked)

#### 2. APIModels.swift
1. **Select** `Cloutmate/Models/APIModels.swift`
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK Cloutmate** (already there)
   - ✅ **CHECK CloudmateHelper** (ADD THIS!)
   - ❌ **UNCHECK CloutmateShared** (not needed in shared framework)

## Why?

CloudmateHelper compiles:
- MetaAPIService
- ThreadsService
- FacebookService

These services need Platform and API response types to compile successfully.

## After Adding

Clean build (⇧⌘K) → Build (⌘B)

All "Cannot find type" errors should be gone! ✅

