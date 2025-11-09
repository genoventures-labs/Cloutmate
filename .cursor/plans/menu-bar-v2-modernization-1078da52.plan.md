<!-- 1078da52-1e7e-4712-85a3-6ee8fefaadaa cd5c381a-631c-468f-8738-37959ff3f2dc -->
# Menu Bar V2 Modernization Plan

## Overview

Transform the menu bar app to match the Archives V2 design system, remove deprecated posting status features, and align with current Cloutmate functionalities (PARA, Aurora, ARTE).

## Files to Modify

**Core Files:**

- `CloutmateMenuBar/MenuBarApp.swift` - Remove posting status, update icon, integrate GlassColorSystem
- `CloutmateMenuBar/MenuBarPopoverView.swift` - Replace segmented picker with FilterChip tabs, use GlassPanel
- `CloutmateMenuBar/MenuBarQuickCaptureView.swift` - Update to GlassPanel design
- `CloutmateMenuBar/MenuBarSettingsView.swift` - Update to GlassPanel design
- `CloutmateMenuBar/QuickComposerView.swift` - Update to GlassPanel design
- `CloutmateMenuBar/UpcomingPostsView.swift` - Update to GlassPanel design

## Phase 1: MenuBarApp.swift Modernization

### Remove Deprecated Features

- Remove `PostStatusChanged` notification observer
- Remove `IconState` enum (idle/posting/error)
- Remove `handlePostingStatus()` method
- Remove `updateIcon()` state-based icon changes
- Remove posting-related icon animations

### Update Icon & Menu

- Change icon from `message.fill` to `sparkles` (Aurora icon) or `brain.head.profile`
- Use static icon (no state changes)
- Update menu styling to use GlassPanel design tokens
- Keep "Open Main App" and "Quit Cloutmate" menu items

### Integrate Design System

- Add `@StateObject private var glassColorSystem = GlassColorSystem()`
- Add `@StateObject private var accessibilityGlassManager = AccessibilityGlassManager()`
- Pass environment objects to popover content
- Use `GlassColorSystem` for adaptive colors

### Popover Setup

- Update popover background to use `glassColorSystem.backgroundColor()`
- Use `GlassPanel` wrapper for popover content
- Apply `GlassMotion.spring` animations for popover show/hide

## Phase 2: MenuBarPopoverView Redesign

### Replace Segmented Picker

- Remove `.pickerStyle(.segmented)` Picker
- Create horizontal ScrollView with `FilterChip` components
- Tabs: "Capture", "Tasks", "Artifacts", "Drafts", "Settings"
- Use `FilterChip` pattern from Archives V2:
- Active state: kosmicBlue gradient background (via `glassColorSystem.buttonColor(for: .primary)`)
- Inactive state: `.glassPanel(tier: .contentCard)` background
- `.GlassMotion.spring` transitions on selection

### Header Section

- Add gradient header: "Cloutmate Menu" with kosmicBlue → kosmicPurple gradient
- Use `.glassPanel(tier: .overlay)` wrapper
- Subline: "Quick access to your workspace"
- SF Pro Rounded font for title

### Content Container

- Wrap content in `.glassPanel(tier: .contentCard, cornerRadius: 12)`
- Use `GlassMotion.spring` for tab switching animations
- Apply `.opacity` fade transitions (0.3 → 1.0) on tab change

### Keyboard Shortcuts

- Keep existing keyboard shortcuts (Cmd+W, Cmd+V, Cmd+S)
- Update to match new tab structure

## Phase 3: MenuBarQuickCaptureView Redesign

### Update Styling

- Replace `.ultraThinMaterial` with `.glassPanel(tier: .contentCard)`
- Update type selector to use `FilterChip` components instead of segmented picker
- Use `GlassButton` for "Capture" action button
- Apply `floatLift()` modifier to input fields on hover

### Layout

- Use `GlassPanel` for TextEditor container
- Add kosmicBlue accent border on focus
- Success message uses kosmicGreen color
- Apply `GlassMotion.spring` for button press animations

## Phase 4: MenuBarSettingsView Redesign

### Header Section

- Replace icon with gradient text: "Cloutmate" (kosmicBlue → kosmicPurple)
- Use `.glassPanel(tier: .overlay)` wrapper
- Update description text styling

### Action Buttons

- Replace `.ultraThinMaterial` buttons with `GlassButton` components
- Use `GlassButton(style: .pill, role: .primary)` for primary actions
- Apply `floatLift()` modifier on hover
- Use `GlassMotion.spring` for button animations

### Layout

- Wrap sections in `.glassPanel(tier: .contentCard)` containers
- Add proper spacing and padding (16pt)
- Use `glassColorSystem.textSecondary()` for secondary text

## Phase 5: QuickComposerView & UpcomingPostsView Updates

### QuickComposerView

- Replace all `.ultraThinMaterial` with `.glassPanel(tier: .contentCard)`
- Update TextEditor to use `GlassPanel` wrapper
- Replace platform selection with `FilterChip` components
- Use `GlassButton` for publish/schedule actions
- Apply `GlassMotion.spring` animations

### UpcomingPostsView

- Wrap cards in `.glassPanel(tier: .contentCard)` containers
- Update empty state to use gradient text
- Apply `floatLift()` modifier to cards
- Use `glassColorSystem` colors throughout

## Phase 6: Design Tokens & Consistency

### Color System

- Use `glassColorSystem.backgroundColor()` for backgrounds
- Use `glassColorSystem.buttonColor(for: .primary)` for primary actions (kosmicBlue)
- Use `glassColorSystem.buttonColor(for: .accent)` for accents (kosmicPurple)
- Use `glassColorSystem.textPrimary()` / `textSecondary()` for text

### Typography

- Headers: SF Pro Rounded, bold, 20-24pt
- Body: SF Pro, regular, 14pt
- Captions: SF Pro, medium, 12pt

### Spacing

- Padding: 16pt (standard), 12pt (compact)
- Corner radius: 12pt (standard), 8pt (compact)
- Shadow: kosmicPurple.opacity(0.15), radius 3

### Animations

- Tab switch: `GlassMotion.Easing.tabSwitch` (0.25s)
- Button press: `GlassMotion.Easing.buttonPress` (0.15s)
- Hover: `GlassMotion.Easing.spring` with `floatLift()` modifier
- Modal open: `GlassMotion.Easing.modalOpen` (0.3s)

## Phase 7: ARTE Integration (Optional)

### Emotional State Awareness

- Subscribe to `ReactiveThemeManager.shared.currentState`
- Apply emotional tint colors via `glassColorSystem.emotionalAccent()`
- Adjust animation speeds based on emotional state
- Use ARTE-aware colors for buttons and accents

## Implementation Checklist

- [ ] Phase 1: Remove posting status features from MenuBarApp.swift
- [ ] Phase 1: Update icon and integrate GlassColorSystem
- [ ] Phase 2: Replace segmented picker with FilterChip tabs in MenuBarPopoverView
- [ ] Phase 2: Add gradient header and GlassPanel containers
- [ ] Phase 3: Update MenuBarQuickCaptureView to use GlassPanel and GlassButton
- [ ] Phase 4: Update MenuBarSettingsView to use GlassButton and GlassPanel
- [ ] Phase 5: Update QuickComposerView and UpcomingPostsView styling
- [ ] Phase 6: Apply design tokens consistently across all views
- [ ] Phase 7: Integrate ARTE emotional state awareness (optional)

## Notes

- Ensure `GlassColorSystem` and `AccessibilityGlassManager` are properly initialized in MenuBarApp
- All views should respect `UIAccessibility.isReduceMotionEnabled` for animations
- Use `CloutmateShared` framework components where available (GlassPanel, GlassMotion, GlassColorSystem)
- Maintain backward compatibility with existing keyboard shortcuts

### To-dos

- [ ] Remove PostStatusChanged notifications, IconState enum, and posting-related icon animations from MenuBarApp.swift
- [ ] Update menu bar icon to sparkles/brain icon and integrate GlassColorSystem and AccessibilityGlassManager
- [ ] Replace segmented picker with FilterChip tabs and add gradient header in MenuBarPopoverView
- [ ] Update MenuBarQuickCaptureView to use GlassPanel, FilterChip, and GlassButton components
- [ ] Update MenuBarSettingsView to use GlassButton and GlassPanel design system
- [ ] Update QuickComposerView and UpcomingPostsView to use GlassPanel styling
- [ ] Apply consistent design tokens (colors, typography, spacing, animations) across all menu bar views
- [ ] Integrate ARTE emotional state awareness for adaptive colors and animations (optional)