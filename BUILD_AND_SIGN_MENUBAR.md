# Build and Sign Menu Bar App

## Build the Menu Bar App in Xcode

1. **Open Xcode**
2. Select the **CloutmateMenuBar** scheme from the scheme dropdown
3. Press **⌘B** to build, or **⌘R** to build and run

The menu bar app should launch automatically and appear in your menu bar.

## Or from Terminal

```bash
cd "/Users/kosmicapps/Desktop/Kosmic Apps/Projects/Cloutmate"

# Build the menu bar app
xcodebuild -project Cloutmate.xcodeproj \
  -scheme CloutmateMenuBar \
  -configuration Debug \
  -destination 'platform=macOS' \
  build

# Then sign it
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Cloutmate-*/Build/Products/Debug -name "CloutmateMenuBar.app" | head -1)
xattr -cr "$APP_PATH"
codesign --force --deep --sign - "$APP_PATH"
open "$APP_PATH"
```

## After Building

The menu bar app will be in:
`~/Library/Developer/Xcode/DerivedData/Cloutmate-*/Build/Products/Debug/CloutmateMenuBar.app`

Once built, you can open it from Settings → Menu Bar → "Open Menu Bar App"

