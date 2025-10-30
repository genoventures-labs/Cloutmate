# Visual Guide: Adding Files & Frameworks to CloutmateShared

## Step 1: Add Files to CloutmateShared Target

### Visual Steps:

1. **Select the files in Finder/Xcode project navigator:**
   - Open `CloutmateShared/CloutmateShared/Services/`
   - Select these files:
     - `MetaAPIService.swift`
     - `ThreadsService.swift`
     - `FacebookService.swift`
     - `MetaAPIConfig.swift`
     - `APIModels.swift` (might be in Models folder)

2. **Right-click** on the selected files

3. **Choose** "Get Info" (⌘I)

4. **Target Membership** section → Check **CloutmateShared**

### Alternative Method:

1. **Project Navigator** → Select file (e.g., `MetaAPIService.swift`)

2. **File Inspector** (⌥⌘1) - Right sidebar

3. **Target Membership** → Check ✅ **CloutmateShared**

4. Repeat for all files

---

## Step 2: Add AuthenticationServices Framework

### Visual Steps:

1. **Click on CloutmateShared target** in Xcode (top of project navigator)

2. **General tab** (should be selected by default)

3. Scroll down to **"Frameworks, Libraries, and Embedded Content"**

4. **Click the + button** (bottom left of that section)

5. In the dialog that appears:
   - **Type:** "AuthenticationServices"
   - **Search:** AuthenticationServices framework
   - **Select:** AuthenticationServices.framework (macOS)
   - **Click:** Add

6. Ensure it says **"Do Not Embed"** (frameworks don't need embedding)

### If + Button Not Visible:

1. Select **CloutmateShared** project (blue icon, not the target)

2. Select **CloutmateShared** TARGET (under TARGETS section)

3. **General tab** → Scroll to "Frameworks, Libraries, and Embedded Content"

---

## Step 3: Verify Network Capabilities

### For CloutmateMenuBar Target:

1. **Select CloutmateMenuBar** target

2. **Signing & Capabilities** tab

3. If not already added:
   - Click **+ Capability**
   - Add **App Sandbox**
   - Enable ✅ **"Outgoing Connections (Client)"**

---

## Visual Reference

```
Xcode Project Structure:
├── Cloutmate.xcodeproj
    ├── TARGETS
    │   ├── Cloutmate (Main App)
    │   ├── CloutmateShared ← Select this
    │   ├── CloutmateWidget
    │   └── CloutmateMenuBar
    └── PROJECTS
        └── Cloutmate
```

**Where to find things:**
- **Target Membership:** File Inspector (⌥⌘1) - right sidebar when file selected
- **Frameworks:** General tab of target settings
- **Capabilities:** Signing & Capabilities tab

---

## Quick Check

After adding files, you should see in File Inspector (⌥⌘1):

**For each file:**
```
Target Membership:
☐ Cloutmate
☑ CloutmateShared  ← Checked!
☐ CloutmateWidget
☐ CloutmateMenuBar
```

**In CloutmateShared General tab:**
```
Frameworks, Libraries, and Embedded Content:
+ AuthenticationServices.framework (Do Not Embed)
```

---

## Troubleshooting

**"AuthenticationServices not found":**
- Make sure you're adding the macOS version
- Try: System Frameworks → AuthenticationServices

**"File not compiling in CloutmateShared":**
- Check File Inspector → Target Membership
- Ensure file is checked for CloutmateShared target

**"Module 'AuthenticationServices' not found":**
- Verify the framework is in "Frameworks, Libraries, and Embedded Content"
- Clean build folder (⇧⌘K)
- Build again

