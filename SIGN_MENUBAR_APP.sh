#!/bin/bash

# Sign the CloutmateMenuBar app so it can be opened
# This removes quarantine attributes and signs it for local development

APP_PATH="/Users/kosmicapps/Library/Developer/Xcode/DerivedData/Cloutmate-*/Build/Products/Debug/CloutmateMenuBar.app"

echo "Removing quarantine attributes..."
xattr -cr "$APP_PATH"

echo "Signing app for local development..."
codesign --force --deep --sign - "$APP_PATH"

echo "Done! You can now open the menu bar app."
echo "Or run it directly from Xcode."

