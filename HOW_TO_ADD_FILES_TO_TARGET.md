# How to Add Files to CloutmateShared Target

## Quick Method - File Inspector

### Step-by-Step:

1. **Open Xcode project**
   ```bash
   open Cloutmate.xcodeproj
   ```

2. **Select a file** in Project Navigator (left sidebar)
   - Example: `MetaAPIService.swift`
   - Look for it in `CloutmateShared/CloutmateShared/Services/`

3. **Open File Inspector** (right sidebar)
   - Press ⌥⌘1 (Option+Command+1)
   - Or: View → Inspectors → File

4. **Find "Target Membership" section**
   - Scroll down to see checkboxes

5. **Check ✅ CloutmateShared**
   - You'll see checkboxes for each target
   - Check the box for "CloutmateShared"

6. **Repeat for each file:**
   - `MetaAPIService.swift`
   - `ThreadsService.swift`
   - `FacebookService.swift`
   - `MetaAPIConfig.swift`
   - `APIModels.swift`

---

## Visual Guide

```
Step 1: Select file
├── CloutmateShared/
    └── CloutmateShared/
        └── Services/
            └── MetaAPIService.swift ← Click here

Step 2: Open Inspector (⌥⌘1)
Right sidebar shows:
┌─────────────────────────────┐
│ File Inspector              │
├─────────────────────────────┤
│ Location:  path/to/file    │
│ ...                         │
│ Target Membership:          │
│ ☐ Cloutmate                │
│ ☑ CloutmateShared          │ ← Check this!
│ ☐ CloutmateWidget          │
│ ☐ CloutmateMenuBar         │
└─────────────────────────────┘
```

---

## Batch Method - Multiple Files

1. **Select multiple files** (⌘-click each one)
   - `MetaAPIService.swift`
   - `ThreadsService.swift`
   - `FacebookService.swift`
   - `MetaAPIConfig.swift`
   - `APIModels.swift`

2. **Open File Inspector** (⌥⌘1)

3. **Check ✅ CloutmateShared** for all at once

---

## Alternative: Drag to Target

1. **In Project Navigator**, find the CloutmateShared TARGET (under TARGETS)

2. **Expand** it to see "Compile Sources"

3. **Drag files** from CloutmateShared folder into "Compile Sources"

4. **Verify** they appeared in the list

---

## Verify It Worked

After adding files:

1. **Select any file** (e.g., MetaAPIService.swift)

2. **Check File Inspector** (⌥⌘1)

3. **Target Membership** should show:
   ```
   ☐ Cloutmate
   ☑ CloutmateShared ← Checked! ✅
   ☐ CloutmateWidget
   ☐ CloutmateMenuBar
   ```

---

## Troubleshooting

**Can't find files in Project Navigator?**

1. **Right-click** on `CloutmateShared` folder
2. **Add Files to "Cloutmate"...**
3. Navigate to the files
4. Make sure "Copy items if needed" is **unchecked**
5. **Check "CloutmateShared"** under "Add to targets"
6. Click **Add**

**Files show but not compiling?**

- Check Target Membership for each file
- Clean build folder: Product → Clean Build Folder (⇧⌘K)
- Rebuild

---

## Quick Checklist

- [ ] Opened Cloutmate.xcodeproj
- [ ] Found files in Project Navigator
- [ ] Selected each file
- [ ] Pressed ⌥⌘1 to open File Inspector
- [ ] Checked ✅ CloutmateShared in Target Membership
- [ ] Repeated for all 5 files
- [ ] Files now compile in CloutmateShared target

