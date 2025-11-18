# Fix Duplicate Build Error

## The Problem
Xcode is trying to compile duplicate files for the same target, causing build errors:
- `MetaAPIService.swift`
- `FacebookService.swift`
- `ThreadsService.swift`
- `APIModels.swift`

## The Solution

### Step 1: Fix Helper Files
These files should ONLY be in the `FocusOSHelper` target:

1. Select each file in Xcode's Project Navigator:
   - `FocusOSHelper/Services/MetaAPIService.swift`
   - `FocusOSHelper/Services/FacebookService.swift`
   - `FocusOSHelper/Services/ThreadsService.swift`
   - `FocusOSHelper/Services/APIModels.swift`

2. For each file, press `Option + Command + 1` (⌥⌘1) to open File Inspector

3. In "Target Membership" section:
   - ✅ **Check** `FocusOSHelper`
   - ❌ **Uncheck** `FocusOS` (if it's checked)

### Step 2: Fix Main App Files
These files should ONLY be in the `FocusOS` target:

1. Select each file:
   - `FocusOS/Services/MetaAPIService.swift`
   - `FocusOS/Services/FacebookService.swift`
   - `FocusOS/Services/ThreadsService.swift`
   - `FocusOS/Models/APIModels.swift`

2. Press `Option + Command + 1` (⌥⌘1) to open File Inspector

3. In "Target Membership" section:
   - ✅ **Check** `FocusOS`
   - ❌ **Uncheck** `FocusOSHelper` (if it's checked)

## Visual Guide
```
FocusOSHelper/Services/*.swift  →  Target: ✅ FocusOSHelper  ❌ FocusOS
FocusOS/Services/*.swift         →  Target: ✅ FocusOS       ❌ FocusOSHelper
```

## After Fixing
1. Clean Build Folder: `Shift + Command + K` (⇧⌘K)
2. Build again: `Command + B` (⌘B)
