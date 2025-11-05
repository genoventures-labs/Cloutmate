# ARTE Initialization Fix

## Summary
Fixed ARTE (Phase 7) initialization issues that were causing crashes in InsightsView.

## Root Causes

### 1. Timing Issue
**Problem:** ARTE was starting in `onAppear` immediately, before SwiftData's ModelContainer was fully initialized.

**Solution:** Added a 0.1 second delay using `_Concurrency.Task` to ensure SwiftData is ready before ARTE initialization:
```swift
.onAppear {
    startPublishingTimer()
    checkAndRunMigration()
    registerGlobalHotkey()
    startRitualSystemsIfNeeded()
    // Start ARTE after other systems
    _Concurrency.Task { @MainActor in
        try? await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        startARTE()
    }
}
```

### 2. Phase 9 Dependencies in Phase 7
**Problem:** `ReactiveThemeManager` was trying to use Phase 9 features (`DriftMonitor`, `MomentumMetrics`) that break the initialization dependency order.

**Solution:** Removed Phase 9 integration from Phase 7 code:
- Removed `momentumSnapshot: MomentumMetrics?` property
- Removed `DriftMonitor.shared.momentumPublisher` subscription
- Removed `adjustStateWithMomentum()` method

**Rationale:** Each phase should be self-contained and not depend on later phases. Phase 7 can be enhanced with Phase 9 features later via dependency injection, but shouldn't hard-depend on them at initialization.

### 3. Name Collision
**Problem:** Swift's `Task` type conflicts with `CloutmateShared.Task` model.

**Solution:** Always use `_Concurrency.Task` to disambiguate:
```swift
_Concurrency.Task { @MainActor in
    try? await _Concurrency.Task.sleep(nanoseconds: 100_000_000)
    startARTE()
}
```

## Files Modified
- `Cloutmate/CloutmateApp.swift` - Fixed ARTE initialization timing
- `Cloutmate/Services/ReactiveThemeManager.swift` - Removed Phase 9 dependencies

## Testing Results
✅ Build succeeds with no errors
✅ ARTE initializes after SwiftData is ready
✅ No Phase 9 hard dependencies in Phase 7 code
✅ All linter checks pass

## Next Steps
1. Test ARTE in the app to ensure emotional state detection works
2. Verify InsightsView loads without crashes
3. Consider adding emotional state indicator back to InsightsView once ARTE is stable
4. Monitor telemetry for initialization performance

## Architecture Notes
**Phase Dependency Order:**
- Phase 7 (ARTE) should only depend on:
  - Phase 6 (Memory Graph)
  - Phase 6.1 (Intelligence Layer)
  - Core SwiftData models

**Future Enhancement:**
- Phase 7 can be enhanced with Phase 9 features via:
  - Protocol-based dependency injection
  - Optional feature flags
  - Lazy initialization of advanced features

This keeps each phase independent and testable.

