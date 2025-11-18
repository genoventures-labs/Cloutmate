# Remove Models from FocusOS Main App Target

## Problem
Files in `FocusOS/Models/` are being compiled by BOTH:
- FocusOS target (main app)
- FocusOSShared target

This causes "Invalid redeclaration" errors.

## Solution

**The models should ONLY be in the FocusOSShared framework.**

### For EACH file in `FocusOS/Models/`:

1. **Select the file** (e.g., `FocusOS/Models/AIMessage.swift`)
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership** section:
   - ❌ **UNCHECK** FocusOS
   - ✅ **KEEP** FocusOSShared

### Files to Fix:
- AIMessage.swift
- AISettings.swift
- Draft.swift
- InsightSnapshot.swift
- Platform.swift
- Platform+UI.swift
- PlatformAccount.swift
- Post.swift
- Template.swift
- Any other model files

### Why?

These models are now part of the FocusOSShared framework. The main app should:
- Import the framework (`import FocusOSShared`)
- NOT compile the files directly

## Alternative Option

If you don't want to change each file individually, you can:
1. Delete `FocusOS/Models/` directory entirely
2. The main app will import models from FocusOSShared framework

## After Fixing:

Clean build (⇧⌘K) → Build (⌘B)

Errors should be gone! ✅

