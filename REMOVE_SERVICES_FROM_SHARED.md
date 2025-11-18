# Remove Services from FocusOSShared Target

## Problem
Files in `FocusOS/Services/` are being compiled by BOTH:
- ✅ FocusOS target (correct)
- ❌ FocusOSShared target (WRONG)

## Solution

In Xcode, for these files in `FocusOS/Services/`:

1. **MetaAPIService.swift**
2. **ThreadsService.swift**
3. **FacebookService.swift**
4. **Any other service files showing errors**

### Fix Each File:
1. **Select the file** in Xcode
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK FocusOS** (keep)
   - ✅ **CHECK FocusOSHelper** (if needed)
   - ❌ **UNCHECK FocusOSShared** (remove)

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

