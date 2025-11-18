# Fix APIModels Duplicate Error

## The Problem
`APIModels.swift` exists in TWO locations:
- `FocusOS/Models/APIModels.swift` 
- `FocusOSHelper/Services/APIModels.swift`

Both are being compiled for the `FocusOSHelper` target, causing a conflict.

## Solution - Step by Step

### 1. Select the Main App's APIModels File
1. In Xcode Project Navigator (left sidebar), find and click:
   **`FocusOS/Models/APIModels.swift`**

### 2. Open File Inspector  
2. Press **`Option + Command + 1`** (⌥⌘1) to open the File Inspector panel (right sidebar)

### 3. Check Target Membership
3. Scroll down to the **"Target Membership"** section
4. You should see checkboxes for:
   - ☐ FocusOS
   - ☐ FocusOSHelper

### 4. Fix the Target Membership
4. For `FocusOS/Models/APIModels.swift`:
   - ✅ **CHECK** `FocusOS` 
   - ❌ **UNCHECK** `FocusOSHelper` (if it's checked)

### 5. Verify the Helper File
5. Now select **`FocusOSHelper/Services/APIModels.swift`**
6. Open File Inspector (⌥⌘1)
7. In Target Membership:
   - ✅ **CHECK** `FocusOSHelper`
   - ❌ **UNCHECK** `FocusOS` (if it's checked)

## Important
Even if you already did this, try:
1. **Clean Build Folder**: Press `Shift + Command + K` (⇧⌘K)
2. **Close Xcode completely**
3. **Delete DerivedData** (optional but recommended):
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/FocusOS-*
   ```
4. **Reopen Xcode** and build again

## Quick Visual Check
After fixing, when you select each file, File Inspector should show:
- `FocusOS/Models/APIModels.swift` → ✅ FocusOS only
- `FocusOSHelper/Services/APIModels.swift` → ✅ FocusOSHelper only

