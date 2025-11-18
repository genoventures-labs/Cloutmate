# Remove Duplicate Models from FocusOS Target

## Problem
Models exist in BOTH:
- `FocusOS/Models/` (11 files including AIMessage.swift)
- `FocusOSShared/FocusOSShared/FocusOSShared/Models/` (10 files)

Both are being compiled → "Invalid redeclaration" errors

## Solution: Remove from FocusOS Target

In Xcode, for **EACH file** in `FocusOS/Models/`:

1. **Select the file** (e.g., `FocusOS/Models/AIMessage.swift`)
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ❌ **UNCHECK FocusOS**
   - ✅ **UNCHECK FocusOSShared** 
   - ✅ Only **FocusOSShared** target should remain

### Files to Fix in `FocusOS/Models/`:
- AIMessage.swift
- AISettings.swift
- APIModels.swift (unique to this folder)
- Draft.swift
- InsightSnapshot.swift
- Platform+UI.swift
- Platform.swift
- PlatformAIConfiguration.swift (differs from shared version)
- PlatformAccount.swift
- Post.swift
- Template.swift

## Why?
These models should ONLY be compiled by the FocusOSShared framework. 
The main app should import and use them from the framework, not compile them directly.

## After Fixing

Clean build (⇧⌘K) → Build (⌘B)

Errors should be gone! ✅

