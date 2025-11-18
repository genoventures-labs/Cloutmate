<!-- ce5c7964-51a1-4ea6-86ca-7a483035e6ab ebc822ac-7305-4b32-a5f7-d8d3487bbeae -->
# Focus Gravity Tab Redesign

## Overview

Redesign the Focus Gravity tab to match the visual hierarchy and usability patterns of Focus Mode, Insights, and AI Assistant tabs. The redesign focuses on the tab layout and controls, not the field visualization itself (which remains a modular placeholder for future enhancements).

## Current State

**File**: `FocusOS/Views/Focus/FocusGravityView.swift`

The current implementation has:

- Basic header with title and subtext
- 7-option segmented picker for filtering (all/task/project/note/draft/post/inbox)
- Simple refresh button
- List-based priority item display
- Basic empty state

## Design Goals

1. **Consistent Layout**: Match Focus Mode/Insights/AI Assistant tab structure
2. **Simplified Controls**: Reduce visual noise with cleaner filter options
3. **ARTE Integration**: Show live cognitive state with badges
4. **Better Hierarchy**: Clear separation between controls, filters, and content
5. **Modular Structure**: Easy to swap visualization later

## Implementation Plan

### 1. Header Section Redesign

**Update the header to match Focus Mode pattern:**

```swift
// Current (lines 24-44)
HStack {
    VStack(alignment: .leading, spacing: 4) {
        Text("Focus Gravity")
            .font(.largeTitle)
            .fontWeight(.bold)
        Text("Dynamically ranked by the Contextual Priority System")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    Spacer()
    Button(action: refreshPriorities) { ... }
}
```

**Replace with:**

- Header: "Focus Gravity" with subtext: "Track how your focus shifts across tasks and priorities."
- Move controls to dedicated top-right cluster
- Add ARTE state badge in top-right corner
- Add last sync timestamp below header

Reference: `FocusModeView.swift` lines 32-54 for header structure

### 2. Filter Simplification

**Replace the 7-option segmented picker (lines 47-57) with a clean 3-option toggle:**

```swift
// New filter bar in top-right area
HStack(spacing: 8) {
    ForEach(["All", "Tasks Only", "Notes Only"], id: \.self) { option in
        Button(option) {
            selectedType = mapToType(option)
        }
        .buttonStyle(.bordered)
        .tint(selectedType == mapToType(option) ? .kosmicBlue : .secondary)
    }
}
```

- Position in top-right cluster alongside controls
- Use ghost button style (shadcn-inspired)
- Map: "All" → all, "Tasks Only" → task, "Notes Only" → note

### 3. Control Cluster (Top-Right)

**Add new control cluster with:**

1. **Aurora Insight Button**

   - Icon: `lightbulb` or `sparkles`
   - Opens AI insight about current priorities
   - Reference: `AIFloatingButton.swift` for icon style

2. **Recenter View Button**

   - Icon: `arrow.up.left.and.arrow.down.right`
   - Resets scroll position (placeholder for future field view)

3. **Refresh Data Button**

   - Icon: `arrow.clockwise`
   - Calls `refreshPriorities()`
   - Disabled while loading

4. **Open in Focus Mode Button**

   - Icon: `timer` (Focus Mode icon)
   - Navigates to Focus Mode tab with same dataset
   - Use binding to selectedTab

### 4. ARTE State Badge

**Add state indicator (top-right, next to controls):**

```swift
HStack(spacing: 6) {
    Circle()
        .fill(stateColor)
        .frame(width: 8, height: 8)
        .overlay(
            Circle()
                .stroke(stateColor.opacity(0.3), lineWidth: 2)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 1)
                .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
        )
    Text(stateName)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(stateColor)
}
.padding(.horizontal, 12)
.padding(.vertical, 6)
.background(stateColor.opacity(0.1))
.cornerRadius(12)
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: glassColorSystem?.emotionalState)
```

**State Mapping:**

- Calm (blue): `EmotionalState.calm`
- Flow (purple): `EmotionalState.focused`
- Fatigue (amber): `EmotionalState.fatigued`

Access via: `@EnvironmentObject private var glassColorSystem: GlassColorSystem`

Read: `glassColorSystem?.emotionalState` (optional for preview safety)

**Safety:** Gate ARTE references for SwiftUI previews:

```swift
private var stateColor: Color {
    guard let state = glassColorSystem?.emotionalState else { return .blue }
    switch state {
    case .calm: return .blue
    case .focused: return .purple
    case .fatigued: return .orange
    default: return .blue
    }
}

private var stateName: String {
    guard let state = glassColorSystem?.emotionalState else { return "Calm" }
    switch state {
    case .calm: return "Calm"
    case .focused: return "Flow"
    case .fatigued: return "Fatigue"
    default: return "Calm"
    }
}
```

### 5. Last Sync Timestamp

**Add sync time display below header:**

```swift
Text("Synced \(timeAgo(from: PriorityEngine.shared.lastSyncTime))")
    .font(.caption)
    .foregroundColor(.secondary)
```

**Update PriorityEngine.swift** (thread-safe exposure):

```swift
// Replace private var lastCacheRefresh: Date?
private var _lastCacheRefresh: Date?

// Add computed property for thread-safe access
var lastSyncTime: Date? {
    _lastCacheRefresh
}

// Update internal references to use _lastCacheRefresh
```

- Format as relative time ("2m ago", "just now")
- Use computed property to maintain thread safety

### 6. Content Area Restructure

**Replace current ScrollView (lines 70-78) with modular container:**

```swift
// Primary section: Placeholder canvas
ZStack {
    // Background with ARTE tint
    glassColorSystem?.backgroundColor() ?? Color.clear
    
    if let system = glassColorSystem {
        system.emotionalBackgroundShift()
    }
    
    // Content container (modular)
    Group {
        if isLoading {
            loadingState
        } else if priorityItems.isEmpty {
            emptyState
        } else {
            // Current list (easily swappable)
            priorityListView
        }
    }
}
.glassPanel(tier: .contentCard, cornerRadius: 16)
```

- Wrap in `.glassPanel()` for consistency
- Add ARTE background tint overlay with nil-coalescing
- Keep list structure modular for future field visualization

### 7. Empty State Enhancement

**Improve empty state (lines 177-195):**

```swift
VStack(spacing: 24) {
    // Aurora orbit animation
    ZStack {
        ForEach(0..<3) { i in
            Circle()
                .stroke(Color.kosmicBlue.opacity(0.3), lineWidth: 2)
                .frame(width: 60 + CGFloat(i * 20), height: 60 + CGFloat(i * 20))
                .rotationEffect(.degrees(orbitRotation + Double(i * 120)))
        }
        Image(systemName: "sparkles")
            .font(.system(size: 24))
            .foregroundColor(.kosmicBlue)
    }
    .frame(height: 120)
    .onAppear {
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            orbitRotation = 360
        }
    }
    
    Text("Nothing's pulling your attention right now")
        .font(.title3)
        .fontWeight(.semibold)
    
    Text("Start a Focus Session or open your Tasks to set priorities.")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
}
```

### 8. Loading State

**Add calm loading animation:**

```swift
VStack(spacing: 16) {
    ZStack {
        Circle()
            .stroke(Color.kosmicBlue.opacity(0.2), lineWidth: 3)
            .frame(width: 60, height: 60)
        
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.kosmicBlue, lineWidth: 3)
            .frame(width: 60, height: 60)
            .rotationEffect(.degrees(loadingRotation))
    }
    .onAppear {
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            loadingRotation = 360
        }
    }
    
    Text("Calculating priorities...")
        .font(.subheadline)
        .foregroundColor(.secondary)
}
```

### 9. Consistency Updates

**Match Focus Mode styling:**

1. **Typography**: Use same font sizes and weights as `FocusModeView.swift`
2. **Spacing**: 

   - Header padding: `.padding()` (16pt)
   - Section spacing: `VStack(spacing: 20)`
   - Card padding: `.padding()` for inner content

3. **Background**: 

   - Use `.frame(minWidth: 700, minHeight: 500)` to match Focus Mode
   - Add ARTE tint: `glassColorSystem?.emotionalBackgroundShift()`

4. **Divider**: Add divider after header to match layout
5. **Animations**: Use `.spring(response: 0.3, dampingFraction: 0.7)` for state changes

## Files to Modify

1. **`FocusOS/Views/Focus/FocusGravityView.swift`** - Main redesign
2. **`FocusOS/Services/PriorityEngine.swift`** - Expose `lastCacheRefresh` as computed property
3. **`FocusOS/Views/MainWindowView.swift`** - Pass `selectedTab` binding if needed for "Open in Focus Mode"

## Key Implementation Details

- Import `FocusOSShared` for shared models
- Make `glassColorSystem` optional-aware: `@EnvironmentObject private var glassColorSystem: GlassColorSystem?`
- Add `@State private var orbitRotation: Double = 0` for animations
- Add `@State private var loadingRotation: Double = 0` for loading spinner
- Add `@State private var isPulsing: Bool = true` for state badge pulse
- Create helper functions:
  - `timeAgo(from: Date?)` for relative timestamps
  - `mapToType(_ filter: String)` for filter mapping
  - `stateColor` and `stateName` computed properties with nil guards for ARTE badge
  - `openInFocusMode()` to switch tabs

## Safety & Polish Refinements

1. **Badge Color Transitions**: Add `.animation(.spring(...), value: glassColorSystem?.emotionalState)` for smooth color transitions
2. **Thread Safety**: Use computed property for `lastSyncTime` instead of direct public var
3. **Preview Safety**: Gate all ARTE references with optional chaining or nil-coalescing to prevent preview crashes

## Testing Checklist

- [ ] Header matches Focus Mode hierarchy
- [ ] 3-option filter works correctly
- [ ] State badge updates with ARTE changes (smooth transitions)
- [ ] Last sync time displays correctly
- [ ] Empty state shows Aurora orbit animation
- [ ] Loading state shows calm animation
- [ ] All controls functional (Refresh, Recenter, Aurora, Focus Mode)
- [ ] ARTE background tint applies correctly
- [ ] Layout consistent across light/dark mode
- [ ] SwiftUI previews work without crashes

### To-dos

- [ ] Add public getter for lastCacheRefresh in PriorityEngine
- [ ] Update header with new subtext, ARTE badge, and sync timestamp
- [ ] Replace 7-option picker with 3-option toggle (All/Tasks/Notes)
- [ ] Add top-right control cluster (Aurora, Recenter, Refresh, Open in Focus Mode)
- [ ] Add ARTE state badge with pulse animation (Calm/Flow/Fatigue)
- [ ] Restructure content area with modular container and ARTE tint
- [ ] Add Aurora orbit animation to empty state
- [ ] Create calm loading animation with spinner
- [ ] Update spacing, padding, and fonts to match Focus Mode
- [ ] Test all controls, states, and ARTE integration