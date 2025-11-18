# Remove Platform.swift from FocusOSShared (Duplicate)

## Problem
Platform.swift exists in BOTH:
- `FocusOS/Models/Platform.swift`
- `FocusOSShared/FocusOSShared/FocusOSShared/Models/Platform.swift`

Both are being compiled by FocusOSShared → duplicate error.

## Solution

Remove the file from FocusOSShared target:

1. **Select** `FocusOS/Models/Platform.swift`
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK FocusOS**
   - ✅ **CHECK FocusOSHelper**
   - ❌ **UNCHECK FocusOSShared** (remove this)

## Why?

FocusOSShared has its OWN copy in:
`FocusOSShared/FocusOSShared/FocusOSShared/Models/Platform.swift`

The file in `FocusOS/Models/` should NOT be compiled by FocusOSShared target.

## After Removing

Clean build (⇧⌘K) → Build (⌘B)

Duplicate error should be gone! ✅

