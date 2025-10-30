# Add MetaAPIService Files to Required Targets

## Problem
InsightsView.swift uses MetaAPIService but it's not in the Cloutmate target.

## Solution

MetaAPIService is in `Cloutmate/Services/` but needs to be in the Cloutmate target.

### In Xcode:

1. **Select** `Cloutmate/Services/MetaAPIService.swift`
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK Cloutmate** (ADD THIS!)

4. **Repeat for:**
   - `Cloutmate/Services/ThreadsService.swift`
   - `Cloutmate/Services/FacebookService.swift`
   - `Cloutmate/Services/KeychainService.swift` (if not already)

These service files need to be in the Cloutmate target to be used by the main app.

## After Adding

Clean build (⇧⌘K) → Build (⌘B)

"Cannot find 'MetaAPIService'" error should be gone! ✅

