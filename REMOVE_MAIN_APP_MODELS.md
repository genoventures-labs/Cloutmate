# Remove Models from Cloutmate Main App Target

## Problem
Files in `Cloutmate/Models/` are being compiled by BOTH:
- Cloutmate target (main app)
- CloutmateShared target

This causes "Invalid redeclaration" errors.

## Solution

**The models should ONLY be in the CloutmateShared framework.**

### For EACH file in `Cloutmate/Models/`:

1. **Select the file** (e.g., `Cloutmate/Models/AIMessage.swift`)
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership** section:
   - ❌ **UNCHECK** Cloutmate
   - ✅ **KEEP** CloutmateShared

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

These models are now part of the CloutmateShared framework. The main app should:
- Import the framework (`import CloutmateShared`)
- NOT compile the files directly

## Alternative Option

If you don't want to change each file individually, you can:
1. Delete `Cloutmate/Models/` directory entirely
2. The main app will import models from CloutmateShared framework

## After Fixing:

Clean build (⇧⌘K) → Build (⌘B)

Errors should be gone! ✅

