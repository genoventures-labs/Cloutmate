<!-- 2526ccae-60fa-40bb-b305-402863b5c3c1 5300f925-6a8e-49f2-a496-8128ac81e9b3 -->
# Widget & Menu Bar Integration Plan

## Overview

Build a WidgetKit widget (small size) and menu bar app that allows quick post scheduling without opening the main Cloutmate app. Both will share data via the app group `group.kosmicapps.cloutmate` and use the existing background XPC service for publishing.

## Architecture

### Data Sharing Strategy

- **SwiftData with App Group**: Configure the existing SwiftData ModelContainer to use the app group container
- **Shared Models**: Widget and menu bar app will access the same Post, Draft, and PlatformAccount models
- **Keychain Access**: Enable keychain sharing in app group for platform authentication tokens
- **XPC Communication**: Widget/menu bar will use the existing CloutmateHelper XPC service for background scheduling

### Components to Build

#### 1. WidgetKit Extension (Small Widget)

**Target**: CloutmateWidget

- Display quick stats (scheduled posts count, next post time)
- Tappable widget opens the menu bar app or main app
- Deep link support to open composer
- Glassmorphic design matching app theme
- Timeline updates every 15 minutes

#### 2. Menu Bar App

**Target**: CloutmateMenuBar (new macOS app target)

- Menu bar icon with status indicator
- Popover interface with glassmorphic styling
- **Quick Composer**: Text input, platform selection, schedule picker
- **Upcoming Posts**: List of next 3-5 scheduled posts
- **Post Now** button for immediate publishing
- Uses same GlassPanel, GlassMotion components from main app

#### 3. Shared Framework

**Target**: CloutmateShared (new framework)

- Move core models (Post, Draft, Platform, etc.) to shared framework
- Move services (KeychainService, XPCService, PublishingService)
- Move glassmorphic UI components (GlassPanel, GlassMaterialTiers, GlassMotion, GlassColorSystem)
- Configure SwiftData with app group container URL

## Implementation Steps

### Phase 1: Shared Framework Setup

1. Create `CloutmateShared.framework` target
2. Move models to shared framework:

   - `Post.swift`
   - `Draft.swift`
   - `Template.swift`
   - `Platform.swift`
   - `PlatformAccount.swift`
   - `InsightSnapshot.swift`

3. Move services to shared framework:

   - `KeychainService.swift`
   - `XPCService.swift`
   - `PublishingService.swift`
   - `XPCProtocol.swift`
   - `Logger.swift`

4. Move glassmorphic UI to shared framework:

   - `GlassPanel.swift`
   - `GlassMaterialTiers.swift`
   - `GlassMotion.swift`
   - `GlassColorSystem.swift`
   - `AccessibilityGlassManager.swift`

5. Update all imports in main app to reference shared framework

### Phase 2: App Group Configuration

1. Update main app entitlements with app group
2. Create `SharedDataManager.swift` to handle app group SwiftData container:
```swift
static func createSharedModelContainer() -> ModelContainer {
    let appGroupURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.kosmicapps.cloutmate"
    )!
    let storeURL = appGroupURL.appendingPathComponent("Cloutmate.sqlite")
    
    let config = ModelConfiguration(url: storeURL)
    return try! ModelContainer(for: schema, configurations: [config])
}
```

3. Update keychain access group in `KeychainService` to use app group
4. Migrate existing data to app group container (one-time migration)

### Phase 3: WidgetKit Extension

1. Create `CloutmateWidget` WidgetKit extension target
2. Add app group entitlement to widget
3. Create widget entry model:

   - `WidgetEntry`: timestamp, scheduled post count, next post date

4. Create `WidgetTimelineProvider`:

   - Fetch from shared SwiftData container
   - Update timeline every 15 minutes

5. Create small widget view (`CloutmateWidgetView`):

   - Glassmorphic background using `GlassPanel`
   - Display scheduled post count
   - Display next post time
   - App icon with badge

6. Add deep link support (URL scheme: `cloutmate://compose`)

### Phase 4: Menu Bar App

1. Create `CloutmateMenuBar` macOS app target
2. Configure as menu bar app (LSUIElement = YES)
3. Add app group entitlement
4. Create `MenuBarApp.swift`:

   - NSApplication lifecycle
   - Status bar item with icon
   - Popover controller

5. Create `MenuBarPopoverView.swift`:

   - Main popover UI with glassmorphic styling
   - Tab system: Quick Post | Upcoming | Settings

6. Create `QuickComposerView.swift`:

   - Text editor (caption input)
   - Platform toggles (Threads/Facebook)
   - Schedule date picker with "Post Now" toggle
   - "Schedule" / "Post Now" button
   - Uses existing XPCService for scheduling

7. Create `UpcomingPostsView.swift`:

   - Fetch scheduled posts from SwiftData
   - List view with glassmorphic cards
   - Show next 5 posts with time, platform, preview

8. Create `MenuBarSettingsView.swift`:

   - Quick settings toggle
   - Link to open main app
   - Widget refresh button

### Phase 5: Integration & Polish

1. Update main app to refresh when returning from background (detect widget/menu bar changes)
2. Add notification support for post success/failure from XPC service
3. Test data sync between all three apps
4. Add widget configuration (optional: choose what to display)
5. Add menu bar icon states (idle, posting, error)
6. Implement proper error handling and validation in menu bar composer
7. Add keyboard shortcuts in menu bar app (⌘N for new post)

## Key Files to Create

### Shared Framework

- `CloutmateShared/Models/*.swift` (moved from main app)
- `CloutmateShared/Services/*.swift` (moved from main app)
- `CloutmateShared/UI/*.swift` (glassmorphic components)
- `CloutmateShared/SharedDataManager.swift`

### Widget Extension

- `CloutmateWidget/CloutmateWidget.swift`
- `CloutmateWidget/WidgetTimelineProvider.swift`
- `CloutmateWidget/CloutmateWidgetView.swift`
- `CloutmateWidget/WidgetEntry.swift`
- `CloutmateWidget/Assets.xcassets` (widget-specific icons)

### Menu Bar App

- `CloutmateMenuBar/MenuBarApp.swift`
- `CloutmateMenuBar/MenuBarPopoverView.swift`
- `CloutmateMenuBar/QuickComposerView.swift`
- `CloutmateMenuBar/UpcomingPostsView.swift`
- `CloutmateMenuBar/MenuBarSettingsView.swift`
- `CloutmateMenuBar/StatusBarController.swift`
- `CloutmateMenuBar/Assets.xcassets` (menu bar icons)

## Technical Considerations

### Glassmorphic Styling

All widget and menu bar UI will use the same glassmorphic components:

- `GlassPanel` with `.contentCard` and `.overlay` tiers
- `GlassMotion.Easing.spring` for animations
- `GlassColorSystem` for color consistency
- Match the `GlassCalendarDayCell` aesthetic

### Data Consistency

- Widget timeline refreshes every 15 minutes
- Menu bar app uses live SwiftData queries with `@Query`
- Main app receives notifications when widget/menu bar creates posts
- All three apps share same XPC service connection for background scheduling

### Publishing Flow

1. User enters post in menu bar or widget deep links to menu bar
2. Data saved to shared SwiftData container
3. If scheduled: XPCService.shared.schedulePost() called
4. If immediate: PublishingService.shared.publishPost() called
5. Widget and main app timelines refresh automatically

### URL Scheme

- `cloutmate://compose` - Open quick composer
- `cloutmate://compose?date=<timestamp>` - Open with pre-filled date
- `cloutmate://posts` - Open main app to posts list

## Testing Strategy

1. Test data sync between main app and menu bar
2. Test widget timeline updates
3. Test scheduling from menu bar app
4. Test immediate posting from menu bar app
5. Test deep links from widget
6. Verify glassmorphic styling consistency
7. Test on macOS 14.0+ (minimum for WidgetKit)

### To-dos

- [ ] Create CloutmateShared framework and move shared code (models, services, UI components)
- [ ] Configure app group and update SwiftData container to use shared storage
- [ ] Create WidgetKit extension with small widget view and timeline provider
- [ ] Create menu bar app target with status bar item and popover controller
- [ ] Build quick composer view in menu bar app with glassmorphic styling
- [ ] Build upcoming posts list view in menu bar app
- [ ] Implement URL scheme and deep linking between widget, menu bar, and main app
- [ ] Test data sync, posting, and UI consistency across all three apps