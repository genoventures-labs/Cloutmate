# Visual Fix Steps - Target Membership

## What You're Seeing

The Target Membership shows which targets will compile this file. For the problem files, you need to:

✅ KEEP: CloutmateShared (checked)  
❌ REMOVE: Cloutmate (unchecked)

---

## Step-by-Step Fix

### For each problem file:

1. **You're looking at the Target Membership** (shown in your image)

2. **The checkboxes are at the bottom of each target** (not visible in your screenshot)

3. **Do this:**
   - Look for checkbox next to "Cloutmate" → **UNCHECK IT** ❌
   - Look for checkbox next to "CloutmateShared" → **KEEP CHECKED** ✅
   - Checkbox next to "CloudmateHelper" → Leave as is

4. **The interface shows:**
   ```
   ☐ Cloutmate           ← UNCHECK THIS
   ☐ CloudmateHelper     ← Leave alone
   ☑ CloutmateShared     ← KEEP CHECKED
   ```

---

## Apply to These Files

Do the unchecking for:
- `APIModels.swift`
- `MetaAPIService.swift`
- `ThreadsService.swift`
- `FacebookService.swift`

Each file should only have CloutmateShared checked ✅

---

## Why?

These files are now part of the CloutmateShared **framework** which all other targets (Cloutmate, Widget, MenuBar) will **import**. The main Cloutmate app shouldn't compile them directly anymore - it should import them from the framework.

---

## After Fixing

1. Clean build: ⇧⌘K
2. Build: ⌘B
3. The error should be gone! ✅

