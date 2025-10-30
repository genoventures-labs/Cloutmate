# Fix Duplicate Build Error

## The Problem
Xcode is trying to compile duplicate files for the same target, causing build errors:
- `MetaAPIService.swift`
- `FacebookService.swift`
- `ThreadsService.swift`
- `APIModels.swift`

## The Solution

### Step 1: Fix Helper Files
These files should ONLY be in the `CloutmateHelper` target:

1. Select each file in Xcode's Project Navigator:
   - `CloutmateHelper/Services/MetaAPIService.swift`
   - `CloutmateHelper/Services/FacebookService.swift`
   - `CloutmateHelper/Services/ThreadsService.swift`
   - `CloutmateHelper/Services/APIModels.swift`

2. For each file, press `Option + Command + 1` (⌥⌘1) to open File Inspector

3. In "Target Membership" section:
   - ✅ **Check** `CloutmateHelper`
   - ❌ **Uncheck** `Cloutmate` (if it's checked)

### Step 2: Fix Main App Files
These files should ONLY be in the `Cloutmate` target:

1. Select each file:
   - `Cloutmate/Services/MetaAPIService.swift`
   - `Cloutmate/Services/FacebookService.swift`
   - `Cloutmate/Services/ThreadsService.swift`
   - `Cloutmate/Models/APIModels.swift`

2. Press `Option + Command + 1` (⌥⌘1) to open File Inspector

3. In "Target Membership" section:
   - ✅ **Check** `Cloutmate`
   - ❌ **Uncheck** `CloutmateHelper` (if it's checked)

## Visual Guide
```
CloutmateHelper/Services/*.swift  →  Target: ✅ CloutmateHelper  ❌ Cloutmate
Cloutmate/Services/*.swift         →  Target: ✅ Cloutmate       ❌ CloutmateHelper
```

## After Fixing
1. Clean Build Folder: `Shift + Command + K` (⇧⌘K)
2. Build again: `Command + B` (⌘B)
