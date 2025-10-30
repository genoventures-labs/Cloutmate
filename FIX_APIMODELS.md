# Fix APIModels Duplicate Error

## The Problem
`APIModels.swift` exists in TWO locations:
- `Cloutmate/Models/APIModels.swift` 
- `CloutmateHelper/Services/APIModels.swift`

Both are being compiled for the `CloutmateHelper` target, causing a conflict.

## Solution - Step by Step

### 1. Select the Main App's APIModels File
1. In Xcode Project Navigator (left sidebar), find and click:
   **`Cloutmate/Models/APIModels.swift`**

### 2. Open File Inspector  
2. Press **`Option + Command + 1`** (⌥⌘1) to open the File Inspector panel (right sidebar)

### 3. Check Target Membership
3. Scroll down to the **"Target Membership"** section
4. You should see checkboxes for:
   - ☐ Cloutmate
   - ☐ CloutmateHelper

### 4. Fix the Target Membership
4. For `Cloutmate/Models/APIModels.swift`:
   - ✅ **CHECK** `Cloutmate` 
   - ❌ **UNCHECK** `CloutmateHelper` (if it's checked)

### 5. Verify the Helper File
5. Now select **`CloutmateHelper/Services/APIModels.swift`**
6. Open File Inspector (⌥⌘1)
7. In Target Membership:
   - ✅ **CHECK** `CloutmateHelper`
   - ❌ **UNCHECK** `Cloutmate` (if it's checked)

## Important
Even if you already did this, try:
1. **Clean Build Folder**: Press `Shift + Command + K` (⇧⌘K)
2. **Close Xcode completely**
3. **Delete DerivedData** (optional but recommended):
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Cloutmate-*
   ```
4. **Reopen Xcode** and build again

## Quick Visual Check
After fixing, when you select each file, File Inspector should show:
- `Cloutmate/Models/APIModels.swift` → ✅ Cloutmate only
- `CloutmateHelper/Services/APIModels.swift` → ✅ CloutmateHelper only

