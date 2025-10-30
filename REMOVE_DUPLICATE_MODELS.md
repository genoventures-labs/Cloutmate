# Remove Duplicate Models from Cloutmate Target

## Problem
Models exist in BOTH:
- `Cloutmate/Models/` (11 files including AIMessage.swift)
- `CloutmateShared/CloutmateShared/CloutmateShared/Models/` (10 files)

Both are being compiled → "Invalid redeclaration" errors

## Solution: Remove from Cloutmate Target

In Xcode, for **EACH file** in `Cloutmate/Models/`:

1. **Select the file** (e.g., `Cloutmate/Models/AIMessage.swift`)
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ❌ **UNCHECK Cloutmate**
   - ✅ **UNCHECK CloutmateShared** 
   - ✅ Only **CloutmateShared** target should remain

### Files to Fix in `Cloutmate/Models/`:
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
These models should ONLY be compiled by the CloutmateShared framework. 
The main app should import and use them from the framework, not compile them directly.

## After Fixing

Clean build (⇧⌘K) → Build (⌘B)

Errors should be gone! ✅

