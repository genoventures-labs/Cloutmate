# Fix: Models Still in Cloutmate Target

## Even Though Target Membership Shows Only CloutmateShared

If you're getting "Invalid redeclaration" errors, the files are still being compiled by BOTH targets somewhere.

## Check Build Phases

1. **Select Cloutmate TARGET** (not the project)
2. Go to **Build Phases** tab
3. Expand **Compile Sources**
4. Look for these files:
   - AIMessage.swift
   - Post.swift
   - Draft.swift
   - etc.

5. If they're in the list, **DELETE them** (select → press Delete key)

## Why This Happens

Even if File Inspector shows only CloutmateShared checked, the files can still be in the "Compile Sources" list from being added earlier.

## After Removing from Compile Sources

Clean build (⇧⌘K) → Build (⌘B)

Errors should be gone! ✅

