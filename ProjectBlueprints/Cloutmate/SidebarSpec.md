# Sidebar Navigation V2 Specification

The sidebar is a critical navigation surface that mirrors ARTE state changes and exposes the PARA hierarchy. The implementation lives under `FocusOS/Views/Sidebar/`.

---

## 1. Files

- `SidebarNavigationViewV2.swift` – Main component.
- `SidebarNavItem.swift` – Renders a single navigation row with icon, badges, and hover states.
- `CollapsibleSidebarSection.swift` – Handles grouping + collapse interaction.
- `SidebarCollapseButton.swift` – Drawer toggle control.

---

## 2. Layout & Behavior

### Sections

The sidebar divides navigation into three groups:

1. **Primary** – Home, Tasks, Projects, Calendar, Insights.
2. **Personal** – Inbox, Journal, Notes, Rituals, Areas.
3. **System** – Focus Mode, Archives, AI Assistant, Settings.

Section headers disappear when collapsed, but spacing remains for muscle memory.

### Collapse States

- Width toggles between 268pt (expanded) and 76pt (collapsed), stored in `@AppStorage("sidebar.v2.collapsed")`.
- `SidebarCollapseButton` at the bottom toggles state; `GlassColorSystem` animates the background accordingly.
- When collapsed, nav icons center-align and labels hide.

### Scrolling

- Uses `GeometryReader` and a custom preference key (`SidebarScrollMetricsPreferenceKey`) to compute scroll offset and content height.
- Displays a translucent scrollbar overlay when content exceeds viewport height, even with system scroll indicators hidden.

### Hover/Focus Feedback

- `hoveredTab` state scales nav items slightly (`glassHoverEffect`).
- Accent rail on the leading edge inherits ARTE colors via `glassColorSystem.glassTint(for: .primary)`.
- `SidebarToneSyncService` ensures ARTE and sidebar gradients stay synchronized.

### Persistence

- Selected tab stored in `@AppStorage("selectedRoute")`, restored on launch.
- `MainWindowView` also tracks `selectedTab`; both stay in sync via `onChange` + notifications.

---

## 3. Keyboard & Notifications

- Keyboard shortcuts defined in `FocusOSApp.commands` (⌘1–⌘6, ⌘, for Settings) post `.switchTab` notifications.
- Sidebar subscribes to `.focusSessionStatusChanged` to show focus-mode badges (e.g., highlight Focus Mode when active).
- Flow Companion + Command Palette live outside the sidebar but post `.switchTab` notifications for navigation when actions complete.

---

## 4. Extending the Sidebar

1. **Add a tab** – Extend `TabIdentifier` enum and update `primaryNav`/`personalNav`/`systemNav` arrays in `SidebarNavigationViewV2`.
2. **Badges** – Update `SidebarNavItem` to display counts (e.g., unread Inbox items) via `@Query` or published counts.
3. **Secondary actions** – Add long-press or context menu actions to `SidebarNavItem` for quick toggles.
4. **Adaptive states** – Introduce additional widths or a "auto-hide" mode by adjusting frame calculations and storing preferences.

---

## 5. QA Checklist

- Collapsing/expanding should animate smoothly even when Reduce Motion is enabled (it disables animations).
- Sidebar must auto-collapse when entering Settings (see `MainWindowView` handling) and restore previous state on exit.
- Test with ARTE disabled to ensure fallback gradients render correctly.
- Verify scrollbars appear when content overflows.

This spec ensures the navigation surface stays coherent with FocusOS’s emotional theming and PARA workflow.
