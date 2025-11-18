# Fix: FocusOS/Models Files Being Compiled by FocusOSShared

## The Problem
Files in `FocusOS/Models/` are being compiled by BOTH:
- ✅ FocusOS target (correct)
- ❌ FocusOSShared target (WRONG - causing redeclaration)

## The Solution

### For EACH file in `FocusOS/Models/`:

1. **Select the file** in Xcode (e.g., `FocusOS/Models/Template.swift`)
2. Press **⌥⌘1** (File Inspector)
3. **Target Membership**:
   - ✅ **CHECK FocusOS** (keep)
   - ❌ **UNCHECK FocusOSShared** (remove)

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

Files in `FocusOS/Models/` should ONLY be in the FocusOS (main app) target.
They should NOT be in the FocusOSShared target.

The shared framework has its OWN copies in `FocusOSShared/FocusOSShared/FocusOSShared/Models/`.

## After Fixing

Clean build (⇧⌘K) → Build (⌘B)

The "Invalid redeclaration" errors should be gone! ✅

