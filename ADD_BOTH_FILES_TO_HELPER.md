# Add Both Files to FocusOSHelper Target

## Files Needed by FocusOSHelper

FocusOSHelper compiles services that depend on these types:
- ✅ **Platform.swift** - Defines `Platform` enum
- ✅ **APIModels.swift** - Defines `OAuthTokenResponse`, `AccountInfoResponse`, `FacebookPagesResponse`, etc.

## Solution: Add Both Files

### In Xcode, for EACH file:

#### 1. Platform.swift
1. **Select** `FocusOS/Models/Platform.swift`
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK FocusOS** (already there)
   - ✅ **CHECK FocusOSHelper** (ADD THIS!)
   - ✅ **CHECK FocusOSShared** (if not already checked)

#### 2. APIModels.swift
1. **Select** `FocusOS/Models/APIModels.swift`
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK FocusOS** (already there)
   - ✅ **CHECK FocusOSHelper** (ADD THIS!)
   - ❌ **UNCHECK FocusOSShared** (not needed in shared framework)

## Why?

FocusOSHelper compiles:
- MetaAPIService
- ThreadsService
- FacebookService

These services need Platform and API response types to compile successfully.

## After Adding

Clean build (⇧⌘K) → Build (⌘B)

All "Cannot find type" errors should be gone! ✅

