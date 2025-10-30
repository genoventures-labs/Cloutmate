# Fix: Models in Both Targets

## Problem
All model files are being compiled by both:
- Cloutmate target (main app)
- CloutmateShared target

This causes "Multiple commands produce" errors.

## Solution: Remove Models from Main App Target

### In Xcode:

For EACH model file in `CloutmateShared/CloutmateShared/Models/`:

1. **Select the file** (e.g., `Post.swift`)
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership** section:
   - ❌ **UNCHECK** Cloutmate (main app)
   - ✅ **KEEP CHECKED** CloutmateShared
   - ❌ Other targets should be UNCHECKED

### Files to Fix:

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

### Why?

These models are now part of the **CloutmateShared framework**. The main app should **import** the framework, not compile these files directly.

## After Fixing:

1. Clean build: ⇧⌘K
2. Build: ⌘B
3. Errors should be gone! ✅

