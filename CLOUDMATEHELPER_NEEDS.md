# CloudmateHelper Needs These Files

CloudmateHelper's `PostPublisher.swift` uses:
- `Platform` (from Platform.swift)
- `ThreadsService`
- `FacebookService`
- `KeychainService`

These are all in `Cloutmate/Services/` and `Cloutmate/Models/`.

## Add to CloudmateHelper Target

In Xcode, for each file, add CloudmateHelper to Target Membership:

### From Cloutmate/Models/:
- ✅ Platform.swift
- ✅ APIModels.swift (for response types)

### From Cloutmate/Services/:
- ✅ MetaAPIService.swift
- ✅ ThreadsService.swift
- ✅ FacebookService.swift
- ✅ KeychainService.swift

### How to check:
1. Select each file
2. ⌥⌘1 (File Inspector)
3. Ensure CloudmateHelper is CHECKED

## Alternative: Copy Files to CloudmateHelper

Copy these files INTO `CloutmateHelper/` directory so they're ONLY for CloudmateHelper target.

