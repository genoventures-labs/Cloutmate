# FocusOSHelper Needs These Files

FocusOSHelper's `PostPublisher.swift` uses:
- `Platform` (from Platform.swift)
- `ThreadsService`
- `FacebookService`
- `KeychainService`

These are all in `FocusOS/Services/` and `FocusOS/Models/`.

## Add to FocusOSHelper Target

In Xcode, for each file, add FocusOSHelper to Target Membership:

### From FocusOS/Models/:
- ✅ Platform.swift
- ✅ APIModels.swift (for response types)

### From FocusOS/Services/:
- ✅ MetaAPIService.swift
- ✅ ThreadsService.swift
- ✅ FacebookService.swift
- ✅ KeychainService.swift

### How to check:
1. Select each file
2. ⌥⌘1 (File Inspector)
3. Ensure FocusOSHelper is CHECKED

## Alternative: Copy Files to FocusOSHelper

Copy these files INTO `FocusOSHelper/` directory so they're ONLY for FocusOSHelper target.

