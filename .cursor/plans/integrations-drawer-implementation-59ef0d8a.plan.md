<!-- 59ef0d8a-7700-425e-8b76-2889a604ae9b ad478cb6-2bbc-45c0-9cad-2b88ec56cc6d -->
# Integrations Drawer Implementation

## Overview

Create a unified integrations drawer that serves as a one-stop destination for managing all FocusOS integrations. The drawer will use V2DrawerScaffold, include the existing Notion integration, and add 7 placeholder integrations that look functional but have no backend implementation yet.

## Files to Create

### 1. `FocusOS/Views/Settings/IntegrationsDrawer.swift` (new)

- Main drawer component using V2DrawerScaffold pattern
- Slides in from right side with backdrop overlay
- Uses GeometryReader for responsive width (min 1200px or 90% of screen width)
- Header with title "Integrations" and close button
- Content area with scrollable list of integration sections
- Each integration uses DrawerSection component
- Dismissal via backdrop tap, close button, or ESC key
- Animation: `.move(edge: .trailing).combined(with: .opacity)` with `GlassMotion.Easing.modalOpen`

### 2. Integration Section Components (within IntegrationsDrawer.swift)

**Notion Integration Section:**

- Move logic from NotionIntegrationSection.swift into drawer
- Connect/disconnect functionality
- Status indicator (connected/disconnected)
- "Manage Integration" button that opens NotionIntegrationDrawer
- Uses existing NotionIntegrationSection logic but adapted for drawer context

**Integration Sections (ordered by productivity priority):**

1. Apple Calendar - icon: "calendar.badge.clock", color: .kosmicPurple (Native macOS, highest priority)
2. Apple Reminders - icon: "bell.badge", color: .kosmicGreen (Native macOS, high priority)
3. Google Calendar - icon: "calendar", color: .kosmicBlue (Most popular calendar service)
4. Google Tasks - icon: "list.bullet.rectangle", color: .kosmicGreen (Task management)
5. Todoist - icon: "checkmark.circle.fill", color: .kosmicBlue (Popular task management)
6. Notion - icon: "externaldrive.badge.icloud", color: .kosmicBlue (Knowledge management, already implemented)
7. Trello - icon: "square.grid.2x2", color: .kosmicPurple (Project management/kanban)
8. Monday.com - icon: "square.stack.3d.up", color: .kosmicBlue (Project management)

Each placeholder section includes:

- Connect button with loading state
- "Coming Soon" badge or subtitle
- Disabled state styling (opacity 0.6)
- Matching visual design to Notion section
- GlassButton components for consistency

## Files to Modify

### 3. `FocusOS/Views/Settings/NotionIntegrationSection.swift`

- Extract connection logic into reusable functions
- Create a simplified view that can be embedded in drawer
- Keep existing drawer presentation logic for "Manage Integration" button
- Maintain compatibility with existing SettingsView usage

### 4. `FocusOS/Views/Settings/SettingsView.swift`

- Add new "Integrations" entry to SettingsEntry enum
- Add to `.integrations` group in settingsSidebarGroups
- Create integrationsControls view builder
- Add button in V2GlassControlStack that opens IntegrationsDrawer
- Button: "Manage Integrations" with icon "link" and primary role
- Add @State var showIntegrationsDrawer: Bool = false
- Add drawer overlay using same pattern as NotionIntegrationDrawer

## Implementation Details

### Drawer Structure

```swift
V2DrawerScaffold(
    accentGradient: AuroraPalette.linearGradient(for: colorScheme),
    showsSidebar: false,
    header: { /* Header with title and close */ },
    content: { /* Scrollable list of integration sections */ },
    sidebar: { EmptyView() }
)
```

### Integration Section Pattern

Each section uses DrawerSection with:

- Title and icon
- Status indicator (connected/not connected)
- Action buttons (Connect/Disconnect/Manage)
- Consistent spacing and styling

### Placeholder Behavior

- Connect buttons show loading spinner then "Coming Soon" message
- All functionality disabled but UI fully interactive
- Visual feedback matches real integrations
- No actual API calls or data persistence

## Visual Design

- Match existing drawer patterns (NotionIntegrationDrawer, NotionAccessTokenMissingDrawer)
- Use glassColorSystem for all colors
- Consistent spacing: 28pt horizontal padding, 28pt vertical spacing
- DrawerSection components for each integration
- GlassButton for all actions
- Smooth animations matching project standards

### To-dos

- [ ] Create IntegrationsDrawer.swift with V2DrawerScaffold, backdrop overlay, and slide-in animation
- [ ] Move Notion integration logic into IntegrationsDrawer, maintaining connect/disconnect and manage functionality
- [ ] Add 7 placeholder integration sections (Todoist, Trello, Google Tasks, Google Calendar, Apple Calendar, Apple Reminders, Monday.com) with functional-looking UI but no backend
- [ ] Add Integrations entry to SettingsView, create button that opens IntegrationsDrawer, and add drawer overlay presentation
- [ ] Refactor NotionIntegrationSection.swift to work both standalone and within drawer context