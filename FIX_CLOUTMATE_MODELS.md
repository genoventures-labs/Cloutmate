# Fix: Cloutmate/Models Files Being Compiled by CloutmateShared

## The Problem
Files in `Cloutmate/Models/` are being compiled by BOTH:
- ✅ Cloutmate target (correct)
- ❌ CloutmateShared target (WRONG - causing redeclaration)

## The Solution

### For EACH file in `Cloutmate/Models/`:

1. **Select the file** in Xcode (e.g., `Cloutmate/Models/Template.swift`)
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK Cloutmate** (keep)
   - ❌ **UNCHECK CloutmateShared** (remove)

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
- APIModels.swift

## Why?

Files in `Cloutmate/Models/` should ONLY be in the Cloutmate (main app) target.
They should NOT be in the CloutmateShared target.

The shared framework has its OWN copies in `CloutmateShared/CloutmateShared/CloutmateShared/Models/`.

## After Fixing

Clean build (⇧⌘K) → Build (⌘B)

The "Invalid redeclaration" errors should be gone! ✅

