# Final Fix for Model Redeclaration Errors

## The Error
```
Invalid redeclaration of 'AIMessage'
'AIConversation' is ambiguous for type lookup
```

## Root Cause
Models exist in BOTH locations:
- `FocusOSShared/FocusOSShared/Models/` ✅ (correct)
- `FocusOS/Models/` ❌ (duplicate, causing conflict)

## The Fix in Xcode

### Option 1: Remove from FocusOS Target (Recommended)

For **EACH file** in `FocusOSShared/FocusOSShared/Models/`:
1. Select the file
2. ⌥⌘1 (File Inspector)
3. **Target Membership**:
   - ❌ Uncheck **FocusOS**
   - ✅ Keep **FocusOSShared**

### Option 2: Delete Duplicate Files Entirely

Delete the entire `FocusOSShared/FocusOSShared/Models/` directory if these files exist elsewhere.

**BUT WAIT** - The error says files are in `FocusOS/Models/` which should not exist if they're already in the shared framework.

## Check Build Phases

1. Select **FocusOS** target
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

