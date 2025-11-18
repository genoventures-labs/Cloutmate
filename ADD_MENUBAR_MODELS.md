# Add Models to FocusOSMenuBar Target

## Problem
MenuBar can't find Post, Draft, PostStatus types.

## Solution

These model files need to be in the FocusOSMenuBar target:

### In Xcode:

For EACH file in `FocusOSShared/FocusOSShared/FocusOSShared/Models/`:

1. **Post.swift**
2. **Draft.swift**  
3. **Platform.swift** (contains PostStatus)
4. Any other models used by the menu bar

Select each file → ⌥⌘1 (File Inspector) → ✅ **CHECK FocusOSMenuBar** in Target Membership.

## Files Need to be in FocusOSMenuBar Target:
- Post.swift
- Draft.swift
- Platform.swift (has PostStatus enum)
- PlatformAccount.swift
- Any other @Model classes used

## Why?

The menu bar app needs access to these models to display and query data.

## After Adding

Clean build (⇧⌘K) → Build (⌘B)

Errors should be gone! ✅

