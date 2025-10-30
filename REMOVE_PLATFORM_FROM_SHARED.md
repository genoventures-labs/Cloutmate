# Remove Platform.swift from CloutmateShared (Duplicate)

## Problem
Platform.swift exists in BOTH:
- `Cloutmate/Models/Platform.swift`
- `CloutmateShared/CloutmateShared/CloutmateShared/Models/Platform.swift`

Both are being compiled by CloutmateShared → duplicate error.

## Solution

Remove the file from CloutmateShared target:

1. **Select** `Cloutmate/Models/Platform.swift`
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK Cloutmate**
   - ✅ **CHECK CloudmateHelper**
   - ❌ **UNCHECK CloutmateShared** (remove this)

## Why?

CloutmateShared has its OWN copy in:
`CloutmateShared/CloutmateShared/CloutmateShared/Models/Platform.swift`

The file in `Cloutmate/Models/` should NOT be compiled by CloutmateShared target.

## After Removing

Clean build (⇧⌘K) → Build (⌘B)

Duplicate error should be gone! ✅

