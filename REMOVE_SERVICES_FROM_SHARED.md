# Remove Services from CloutmateShared Target

## Problem
Files in `Cloutmate/Services/` are being compiled by BOTH:
- ✅ Cloutmate target (correct)
- ❌ CloutmateShared target (WRONG)

## Solution

In Xcode, for these files in `Cloutmate/Services/`:

1. **MetaAPIService.swift**
2. **ThreadsService.swift**
3. **FacebookService.swift**
4. **Any other service files showing errors**

### Fix Each File:
1. **Select the file** in Xcode
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK Cloutmate** (keep)
   - ✅ **CHECK CloudmateHelper** (if needed)
   - ❌ **UNCHECK CloutmateShared** (remove)

These files belong to the main app, NOT the shared framework.

## Why?
The shared framework should only have:
- Models
- SharedDataManager
- PublishingService (the shared version)

NOT the main app's services like MetaAPIService, ThreadsService, etc.

## After Fixing

Clean build (⇧⌘K) → Build (⌘B)

Errors should be gone! ✅

