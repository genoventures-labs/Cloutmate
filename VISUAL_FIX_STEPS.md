# Visual Fix Steps - Target Membership

## What You're Seeing

The Target Membership shows which targets will compile this file. For the problem files, you need to:

✅ KEEP: FocusOSShared (checked)  
❌ REMOVE: FocusOS (unchecked)

---

## Step-by-Step Fix

### For each problem file:

1. **You're looking at the Target Membership** (shown in your image)

2. **The checkboxes are at the bottom of each target** (not visible in your screenshot)

3. **Do this:**
   - Look for checkbox next to "FocusOS" → **UNCHECK IT** ❌
   - Look for checkbox next to "FocusOSShared" → **KEEP CHECKED** ✅
   - Checkbox next to "FocusOSHelper" → Leave as is

4. **The interface shows:**
   ```
   ☐ FocusOS           ← UNCHECK THIS
   ☐ FocusOSHelper     ← Leave alone
   ☑ FocusOSShared     ← KEEP CHECKED
   ```

---

## Apply to These Files

Do the unchecking for:
- `APIModels.swift`
- `MetaAPIService.swift`
- `ThreadsService.swift`
- `FacebookService.swift`

Each file should only have FocusOSShared checked ✅

---

## Why?

These files are now part of the FocusOSShared **framework** which all other targets (FocusOS, Widget, MenuBar) will **import**. The main FocusOS app shouldn't compile them directly anymore - it should import them from the framework.

---

## After Fixing

1. Clean build: ⇧⌘K
2. Build: ⌘B
3. The error should be gone! ✅

