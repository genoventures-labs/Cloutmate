# Final Fix for Model Redeclaration Errors

## The Error
```
Invalid redeclaration of 'AIMessage'
'AIConversation' is ambiguous for type lookup
```

## Root Cause
Models exist in BOTH locations:
- `CloutmateShared/CloutmateShared/Models/` ✅ (correct)
- `Cloutmate/Models/` ❌ (duplicate, causing conflict)

## The Fix in Xcode

### Option 1: Remove from Cloutmate Target (Recommended)

For **EACH file** in `CloutmateShared/CloutmateShared/Models/`:
1. Select the file
2. ⌥⌘1 (File Inspector)
3. **Target Membership**:
   - ❌ Uncheck **Cloutmate**
   - ✅ Keep **CloutmateShared**

### Option 2: Delete Duplicate Files Entirely

Delete the entire `CloutmateShared/CloutmateShared/Models/` directory if these files exist elsewhere.

**BUT WAIT** - The error says files are in `Cloutmate/Models/` which should not exist if they're already in the shared framework.

## Check Build Phases

1. Select **Cloutmate** target
2. Build Phases → Compile Sources
3. Remove these files from the list:
   - AIMessage.swift
   - Post.swift
   - Draft.swift
   - AISettings.swift
   - Template.swift
   - InsightSnapshot.swift
   - Platform.swift
   - Platform+UI.swift
   - PlatformAccount.swift

## After Fixing

Clean build (⇧⌘K) → Build (⌘B)

Errors should be gone! ✅

