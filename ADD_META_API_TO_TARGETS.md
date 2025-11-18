# Add MetaAPIService Files to Required Targets

## Problem
InsightsView.swift uses MetaAPIService but it's not in the FocusOS target.

## Solution

MetaAPIService is in `FocusOS/Services/` but needs to be in the FocusOS target.

### In Xcode:

1. **Select** `FocusOS/Services/MetaAPIService.swift`
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK FocusOS** (ADD THIS!)

4. **Repeat for:**
   - `FocusOS/Services/ThreadsService.swift`
   - `FocusOS/Services/FacebookService.swift`
   - `FocusOS/Services/KeychainService.swift` (if not already)

These service files need to be in the FocusOS target to be used by the main app.

## After Adding

Clean build (⇧⌘K) → Build (⌘B)

"Cannot find 'MetaAPIService'" error should be gone! ✅

