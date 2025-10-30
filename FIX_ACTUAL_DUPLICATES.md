# Fix Actual Duplicate Models

## The Problem

You have model files in TWO places:

1. **Original location**: `Cloutmate/Models/` - 11 files (these are in main app target)
2. **Copied location**: `CloutmateShared/CloutmateShared/Models/` - 10 files (in shared target)

Both sets are being compiled, causing "Multiple commands produce" errors.

## Solution: Remove Originals from Main App Target

The files in `Cloutmate/Models/` should NOT be in the Cloutmate target anymore - they should only be in CloutmateShared.

### For EACH file in Cloutmate/Models/:

1. **Select the file** in Project Navigator
   - Example: `Cloutmate/Models/Post.swift`

2. **Press ⌥⌘1** (File Inspector)

3. **Target Membership** section:
   - ❌ **UNCHECK Cloutmate**
   - ✅ **Keep CloutmateShared checked** (if it shows up)
   - OR: Just uncheck Cloutmate

### Files to Fix (from Cloutmate/Models/):

- AIMessage.swift
- AISettings.swift
- Draft.swift
- InsightSnapshot.swift
- Platform.swift
- Platform+UI.swift
- PlatformAccount.swift
- PlatformAIConfiguration.swift
- Post.swift
- Template.swift
- Any other model files

## Alternative: Copy Structure

If that doesn't work, you may need to:
1. Delete files from `Cloutmate/Models/`
2. Ensure only copies in `CloutmateShared/CloutmateShared/Models/` exist
3. Main app imports from framework

## After Fixing:

1. Clean build: ⇧⌘K
2. Build: ⌘B

