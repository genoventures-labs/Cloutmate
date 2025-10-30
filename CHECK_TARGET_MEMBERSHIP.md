# Check Target Membership for Required Files

CloudmateHelper needs access to several files. Check their target membership:

## Files to Verify in Xcode

### Select each file and press ⌥⌘1 (File Inspector):

#### Models:
1. `Cloutmate/Models/Platform.swift` → Should have CloudmateHelper CHECKED
2. `Cloutmate/Models/APIModels.swift` → Should have CloudmateHelper CHECKED

#### Services:
3. `Cloutmate/Services/MetaAPIService.swift` → Should have CloudmateHelper CHECKED
4. `Cloutmate/Services/ThreadsService.swift` → Should have CloudmateHelper CHECKED  
5. `Cloutmate/Services/FacebookService.swift` → Should have CloudmateHelper CHECKED
6. `Cloutmate/Services/KeychainService.swift` → Should have CloudmateHelper CHECKED

## If CloudmateHelper is NOT checked:

Add it! That's why you're getting "Cannot find type" errors.

## If already checked but still errors:

Then there might be import issues or the files need to reference types from somewhere else.

