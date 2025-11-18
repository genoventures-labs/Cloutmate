# Plan: Rename FocusOS to FocusOS

## Overview

Comprehensive renaming of the app, project, repository, and all references from "FocusOS" to "FocusOS". This is a large-scale refactoring affecting directories, files, code references, bundle identifiers, app groups, and documentation.

## Scope Analysis

- **1,327 occurrences** of "FocusOS" found across the codebase
- **Multiple directories** to rename: FocusOS/, FocusOSHelper/, FocusOSWidget/, FocusOSMenuBar/, FocusOSShared/
- **Project file**: FocusOS.xcodeproj
- **Bundle identifiers**: com.kosmicapps.FocusOS.*
- **App group**: group.kosmicapps.focusos
- **Documentation files**: Multiple .md files with "FocusOS" references

## Renaming Strategy

### Phase 1: Directory and File Renaming

1. Rename main directories:

- `FocusOS/` → `FocusOS/`
- `FocusOSHelper/` → `FocusOSHelper/`
- `FocusOSWidget/` → `FocusOSWidget/`
- `FocusOSMenuBar/` → `FocusOSMenuBar/`
- `FocusOSShared/` → `FocusOSShared/`
- `FocusOSTests/` → `FocusOSTests/`
- `FocusOSUITests/` → `FocusOSUITests/`
- `FocusOSSharedTests/` → `FocusOSSharedTests/`
- `FocusOSMenuBarTests/` → `FocusOSMenuBarTests/`
- `FocusOSMenuBarUITests/` → `FocusOSMenuBarUITests/`

2. Rename project file:

- `FocusOS.xcodeproj` → `FocusOS.xcodeproj`

3. Rename files with "FocusOS" in name:

- `FocusOSApp.swift` → `FocusOSApp.swift`
- `FocusOSHelperApp.swift` → `FocusOSHelperApp.swift`
- `FocusOSWidget.swift` → `FocusOSWidget.swift`
- `FocusOSWidgetView.swift` → `FocusOSWidgetView.swift`
- `FocusOSWidgetControl.swift` → `FocusOSWidgetControl.swift`
- `FocusOSWidgetBundle.swift` → `FocusOSWidgetBundle.swift`
- `FocusOSShared.swift` → `FocusOSShared.swift`
- All `.entitlements` files with "FocusOS" in path
- All test files with "FocusOS" in name

### Phase 2: Code References

1. Update all Swift imports:

- `import FocusOSShared` → `import FocusOSShared`
- `FocusOSShared.` → `FocusOSShared.`

2. Update type names:

- `FocusOSApp` → `FocusOSApp`
- `FocusOSHelperApp` → `FocusOSHelperApp`
- `FocusOSWidget` → `FocusOSWidget`
- All references to `FocusOSShared` types

3. Update string literals:

- Notification names: `"FocusOSPostCreated"` → `"FocusOSPostCreated"`
- App group IDs: `"group.kosmicapps.focusos"` → `"group.kosmicapps.focusos"`
- Database names: `"FocusOS_v3.sqlite"` → `"FocusOS_v3.sqlite"`
- Hotkey signatures: `"CLMT"` → `"FOCS"` (or appropriate 4-char code)

4. Update comments and documentation strings:

- All file headers
- All inline comments
- All doc comments

### Phase 3: Xcode Project Configuration

1. Update `project.pbxproj`:

- All target names
- All product names
- All bundle identifiers:
- `com.kosmicapps.FocusOS` → `com.kosmicapps.FocusOS`
- `com.kosmicapps.FocusOS.Helper` → `com.kosmicapps.FocusOS.Helper`
- `com.kosmicapps.FocusOS.FocusOSShared` → `com.kosmicapps.FocusOS.FocusOSShared`
- `com.kosmicapps.FocusOS.FocusOSWidget` → `com.kosmicapps.FocusOS.FocusOSWidget`
- `com.kosmicapps.FocusOS.FocusOSMenuBar` → `com.kosmicapps.FocusOS.FocusOSMenuBar`
- All file references
- All folder references
- All build settings

2. Update entitlements files:

- App group identifiers
- All references to bundle identifiers

3. Update Info.plist files:

- Bundle display names
- Bundle identifiers

### Phase 4: Documentation

1. Update README.md
2. Update all .md files in root directory
3. Update documentation in code files
4. Update setup guides and integration guides

### Phase 5: Scripts and Configuration

1. Update shell scripts:

- `SETUP_WIDGET_MENUBAR.sh`
- `SIGN_MENUBAR_APP.sh`
- Any other scripts with "FocusOS" references

2. Update configuration files:

- Any JSON/YAML config files
- Build scripts
- CI/CD configurations (if any)

## Implementation Steps

### Step 1: Backup and Preparation

- [ ] Verify git status (commit or stash current changes)
- [ ] Create a backup branch: `git checkout -b backup-before-rename`

### Step 2: Update Code References First

- [ ] Use find-and-replace for all code files:
- `FocusOS` → `FocusOS` (case-sensitive)
- `focusos` → `focusos` (lowercase)
- `CLMT` → `FOCS` (hotkey signature)
- [ ] Update import statements
- [ ] Update type names
- [ ] Update string literals
- [ ] Update comments

### Step 3: Rename Directories

- [ ] Rename `FocusOS/` → `FocusOS/`
- [ ] Rename `FocusOSHelper/` → `FocusOSHelper/`
- [ ] Rename `FocusOSWidget/` → `FocusOSWidget/`
- [ ] Rename `FocusOSMenuBar/` → `FocusOSMenuBar/`
- [ ] Rename `FocusOSShared/` → `FocusOSShared/`
- [ ] Rename all test directories

### Step 4: Rename Files

- [ ] Rename `FocusOSApp.swift` → `FocusOSApp.swift`
- [ ] Rename all files with "FocusOS" in name
- [ ] Rename `FocusOS.xcodeproj` → `FocusOS.xcodeproj`

### Step 5: Update Xcode Project File

- [ ] Update all references in `project.pbxproj`
- [ ] Update bundle identifiers
- [ ] Update product names
- [ ] Update file paths
- [ ] Update target names

### Step 6: Update Entitlements and Info.plist

- [ ] Update app group identifiers
- [ ] Update bundle identifiers in entitlements
- [ ] Update Info.plist files

### Step 7: Update Documentation

- [ ] Update README.md
- [ ] Update all .md files
- [ ] Update inline documentation

### Step 8: Update Scripts

- [ ] Update shell scripts
- [ ] Update any build scripts

### Step 9: Verification

- [ ] Build project in Xcode
- [ ] Verify all targets compile
- [ ] Check for any remaining "FocusOS" references
- [ ] Test app launch
- [ ] Verify app group access
- [ ] Test widget and menu bar extensions

## Special Considerations

### Case Sensitivity

- "FocusOS" (capital C) → "FocusOS" (capital F, OS)
- "focusos" (lowercase) → "focusos" (lowercase)
- "CLMT" (hotkey signature) → "FOCS" (or appropriate 4-char code)

### Bundle Identifier Mapping

- `com.kosmicapps.FocusOS` → `com.kosmicapps.FocusOS`
- `com.kosmicapps.FocusOS.Helper` → `com.kosmicapps.FocusOS.Helper`
- `com.kosmicapps.FocusOS.FocusOSShared` → `com.kosmicapps.FocusOS.FocusOSShared`
- `com.kosmicapps.FocusOS.FocusOSWidget` → `com.kosmicapps.FocusOS.FocusOSWidget`
- `com.kosmicapps.FocusOS.FocusOSMenuBar` → `com.kosmicapps.FocusOS.FocusOSMenuBar`

### App Group Mapping

- `group.kosmicapps.focusos` → `group.kosmicapps.focusos`

### Database File Mapping

- `FocusOS_v3.sqlite` → `FocusOS_v3.sqlite`

### Hotkey Signature

- `"CLMT"` → `"FOCS"` (4-character OSType signature)

## Risks and Mitigation

### Risk 1: Xcode Project File Corruption

- **Mitigation**: Work on a copy, verify project opens after each major change

### Risk 2: Broken Imports

- **Mitigation**: Update imports systematically, test compilation frequently

### Risk 3: App Group Access Issues

- **Mitigation**: Update app group IDs consistently across all targets

### Risk 4: Bundle Identifier Conflicts

- **Mitigation**: Ensure all bundle identifiers are updated consistently

### Risk 5: Database Migration

- **Mitigation**: Consider if database file rename is needed, or if it can remain for backward compatibility

## Testing Checklist

- [ ] Project opens in Xcode
- [ ] All targets build successfully
- [ ] Main app launches
- [ ] Helper app works
- [ ] Widget extension works
- [ ] Menu bar app works
- [ ] App group sharing works
- [ ] Database access works
- [ ] Hotkeys work
- [ ] Notifications work
- [ ] All features functional

## Notes

- This is a comprehensive rename affecting the entire codebase
- Some references may be in external dependencies or generated files
- Database file name change may require migration logic
- App group ID change may require user to re-grant permissions
- Bundle identifier change will require new provisioning profiles