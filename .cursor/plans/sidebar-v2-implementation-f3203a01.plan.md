<!-- f3203a01-528c-435b-bd74-c2b445fe646c 9ad1ed3d-8ca6-47c0-b30a-622c281a9360 -->
# Sidebar V2 Implementation Plan

## Overview

Replace the existing `Sidebar.swift` with a new `SidebarNavigationViewV2.swift` that provides ARTE-adaptive navigation with tone-aware gradients, elegant animations, and a clean grouped structure. The sidebar will integrate with the existing `TabIdentifier` system and `ReactiveThemeManager` for emotional state synchronization.

## Files to Create

### 1. `FocusOS/Views/Sidebar/SidebarNavigationViewV2.swift`

Main sidebar component with:

- Header zone with App Orb + "FocusOS" label
- Three navigation groups: Primary, Personal, System
- Collapse/expand functionality (260pt expanded, 72pt collapsed)
- ARTE tone-aware background gradients
- Focus mode active indicator
- Keyboard shortcuts support (⌘1-⌘9, ⌘⇧←/→, ⌘K)
- Accessibility support (VoiceOver, Reduce Motion, High Contrast)

### 2. `FocusOS/Views/Sidebar/SidebarNavItem.swift`

Individual navigation item component:

- Icon (20pt SF Symbols thin)
- Label (Inter/SF Pro Rounded medium)
- Active indicator (kosmicBlue gradient glow ring)
- Hover lift animation (`.floatLift()`)
- Notification dot indicator (kosmicGreen glow)
- Focus mode pulsing accent bar

### 3. `FocusOS/Views/Sidebar/SidebarCollapseButton.swift`

Collapse/expand toggle button:

- Chevron icon (minimal)
- Smooth width transition animation (0.25s easeInOut)
- Persistent state via `@AppStorage("sidebar.v2.collapsed")`

### 4. `FocusOS/Services/SidebarToneSyncService.swift`

Service to sync sidebar background with ARTE emotional state:

- Observes `ReactiveThemeManager.shared.currentState`
- Maps emotional states to gradient colors:
- Calm → kosmicBlue → kosmicPurple
- Reflective → kosmicPurple → kosmicViolet
- Energized → kosmicGreen → kosmicBlue
- Fatigued → desaturated kosmicBlue → gray fade
- Crossfade transitions (300-350ms)
- Fades to 40% opacity when tone stabilizes

## Files to Modify

### 1. `FocusOS/Views/MainWindowView.swift`

- Replace `Sidebar` reference with `SidebarNavigationViewV2`
- Update `sidebarWidth` state to handle collapse (260pt/72pt)
- Add keyboard shortcut handlers (⌘1-⌘9 for tab navigation)
- Add `@AppStorage("selectedRoute")` for persistent selection
- Map TabIdentifier to route strings for persistence

### 2. `FocusOS/Utilities/GlassColorSystem.swift`

- Add `kosmicViolet` color constant (if not exists)
- Add `sidebarToneGradient(for: EmotionalState)` method
- Integrate with existing ARTE emotional state system

## Implementation Details

### Navigation Groups

**Primary Nav:**

- Dashboard (`.home`) → 🧠 icon
- Tasks (`.tasks`) → ✅ icon
- Projects (`.projects`) → 📁 icon
- Calendar (`.calendar`) → 📅 icon
- Insights (`.insights`) → 📊 icon

**Personal Nav:**

- Journal (`.journal`) → 📓 icon
- Rituals (`.rituals`) → 🌅 icon
- Artifacts (`.posts`) → 🧩 icon
- Areas (`.areas`) → 🗂 icon

**System Nav:**

- Focus Mode (`.focusMode`) → 🎯 icon (with pulsing indicator when active)
- Archives (`.archives`) → 🗃 icon
- AI Assistant (`.aiAssistant`) → 🤖 icon
- Settings (`.settings`) → ⚙️ icon

### Visual Specifications

- Width: 260pt (expanded) / 72pt (collapsed)
- Background: `.glassPanel(tier: .sidebar)` with ARTE tone gradient overlay
- Corner Radius: 16pt (right side only)
- Icon Size: 20pt (SF Symbols thin weight)
- Font: Inter / SF Pro Rounded (medium weight)
- Active Tab: kosmicBlue gradient glow ring
- Hover: `.floatLift()` + 0.15s spring animation
- Divider: kosmicPurple.opacity(0.12) between zones

### ARTE Integration

- Background gradient shifts with `ReactiveThemeManager.shared.currentState`
- Tone updates crossfade in 300-350ms
- Sidebar glow fades to 40% opacity when emotional tone stabilizes
- Focus Mode active state detected via `FocusSessionService.shared.getActiveSession()`

### State Management

- Use `@AppStorage("sidebar.v2.collapsed")` for collapse state
- Use `@AppStorage("selectedRoute")` for persistent route selection
- Restore last active route on app relaunch
- Integrate with existing `TabIdentifier` enum

### Keyboard Shortcuts

- ⌘1-⌘9: Jump to tabs (mapped to navigation groups)
- ⌘⇧←/→: Cycle through navigation groups
- ⌘K: Global search overlay (already exists in MainWindowView)

### Accessibility

- VoiceOver: Reads tab name, status ("active", "unread", "focus active")
- Reduce Motion: Disables hover lift and gradient transitions
- High Contrast: Switches to kosmicBlue solid highlight ring
- Keyboard Nav: Arrow keys to move focus + Return to select

## Integration Points

1. **TabIdentifier Mapping**: Use existing enum, map to route strings for persistence
2. **Focus Mode Detection**: Query `FocusSessionService.shared.getActiveSession(modelContext:)`
3. **ARTE State**: Observe `ReactiveThemeManager.shared.$currentState`
4. **Color System**: Use `GlassColorSystem` for kosmic colors
5. **Animations**: Use existing `GlassMotion` and `.floatLift()` modifier
6. **Glass Panel**: Use `.glassPanel(tier: .sidebar)` for background

## Testing Considerations

- Verify ARTE tone transitions are smooth (300-350ms)
- Test collapse/expand animation (0.25s easeInOut)
- Verify keyboard shortcuts work correctly
- Test Focus Mode active indicator appears/disappears correctly
- Verify accessibility features (VoiceOver, Reduce Motion, High Contrast)
- Test persistent state restoration on app relaunch

### To-dos

- [ ] Create SidebarNavigationViewV2.swift with header, navigation groups, and collapse functionality
- [ ] Create SidebarNavItem.swift component with icon, label, active indicator, and hover animations
- [ ] Create SidebarCollapseButton.swift with chevron icon and smooth transition animation
- [ ] Create SidebarToneSyncService.swift to sync sidebar background with ARTE emotional states
- [ ] Add kosmicViolet color and sidebarToneGradient method to GlassColorSystem
- [ ] Replace Sidebar with SidebarNavigationViewV2 in MainWindowView and add keyboard shortcuts
- [ ] Add Focus Mode active state detection and pulsing indicator to sidebar
- [ ] Implement VoiceOver, Reduce Motion, and High Contrast support