# Check Target Membership for Required Files

FocusOSHelper needs access to several files. Check their target membership:

## Files to Verify in Xcode

### Select each file and press ⌥⌘1 (File Inspector):

#### Models:
1. `FocusOS/Models/Platform.swift` → Should have FocusOSHelper CHECKED
2. `FocusOS/Models/APIModels.swift` → Should have FocusOSHelper CHECKED

#### Services:
3. `FocusOS/Services/MetaAPIService.swift` → Should have FocusOSHelper CHECKED
4. `FocusOS/Services/ThreadsService.swift` → Should have FocusOSHelper CHECKED  
5. `FocusOS/Services/FacebookService.swift` → Should have FocusOSHelper CHECKED
6. `FocusOS/Services/KeychainService.swift` → Should have FocusOSHelper CHECKED

## If FocusOSHelper is NOT checked:

Add it! That's why you're getting "Cannot find type" errors.

## If already checked but still errors:

Then there might be import issues or the files need to reference types from somewhere else.

