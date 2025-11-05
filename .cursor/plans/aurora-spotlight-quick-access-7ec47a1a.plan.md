<!-- 7ec47a1a-b3f9-4982-a122-1a0904969b65 2a68c1f7-a759-4187-ad24-f02e307ca6d9 -->
# Aurora AI Assistant UI Redesign - Apple-Aligned

## Overview

Transform the AI Assistant view to align with Apple design language while maintaining Cloutmate branding. Prioritize Aurora's core capabilities, fix UI issues, and add intelligent features like ARTE state-based tinting and contextual hints.

## Core Changes

### 1. Toolbar Redesign - Core Capabilities Focus

**File: `Cloutmate/Views/AIAssistant/AIAssistantView.swift`**

Replace the social media-focused toolbar with Aurora's core capabilities:

- **Primary Actions (Icon-only, prominent):**
  - Create Task (`checkmark.circle.fill`)
  - Create Project (`folder.fill`)
  - Create Note (`note.text`)
  - Create Reminder (`bell.fill`)
  - Analyze Document (`doc.text.magnifyingglass`)
  - Analyze Image (`photo.fill`)

- **Secondary Actions (Labeled, accessible):**
  - Platform selector moved to input area
  - Content tools (brainstorm, captions, hashtags, tone) moved to secondary menu or input area

- **Toolbar Layout:**
  - Horizontal bar with icon-only buttons
  - Subtle hover states with tooltips
  - ARTE state-based tinting (see below)
  - Spacing: 12pt between items, 16pt padding

### 2. Fix Double Placeholder Issue

**File: `Cloutmate/Views/AIAssistant/AIAssistantView.swift` (inputArea, ~line 580)**

Remove the overlay Text placeholder (`"Ask me anything..."`) since `MentionInputField` already provides its own placeholder. Keep only the `MentionInputField` placeholder.

### 3. ARTE State-Based Toolbar Tinting

**File: `Cloutmate/Views/AIAssistant/AIAssistantView.swift`**

Integrate with ARTE emotional states:

- **Focused state:** Toolbar icons tinted with `kosmicBlue` (from EmotionalPalette)
- **Idle/Calm state:** Neutral gray (`Color.secondary`)
- **Analyzing state:** Warm amber (`Color.orange.opacity(0.8)`)

Access `viewModel.currentActivity` or ARTE state from `GlassColorSystem` to determine tint color dynamically.

### 4. Inline Micro-Feedback

**File: `Cloutmate/Views/AIAssistant/AIAssistantView.swift`**

Add shimmer/pulse effects when actions are triggered:

- 0.5s duration shimmer or icon pulse
- Use `.symbolEffect(.pulse)` or custom shimmer overlay
- Trigger on button press, show "Prefilling..." or similar brief feedback

### 5. Smart Toolbar Rearrangement

**New File: `Cloutmate/Services/ToolbarUsageTracker.swift`**

Track tool usage frequency:

- Store usage counts in UserDefaults or SwiftData
- Reorder toolbar items by frequency (most-used first)
- Add "Reset Layout" option in Settings or toolbar context menu
- Update toolbar order dynamically based on usage

### 6. Contextual Hint Bar

**File: `Cloutmate/Views/AIAssistant/AIAssistantView.swift`**

Add subtle hint text below input field:

- Text: "You can @mention a project or attach a doc"
- Style: `.caption`, `.secondary` color, subtle opacity
- Visibility: Only shown when `inputText.isEmpty` and not loading
- Position: Between input area and quick action tools

### 7. Overall UI Refinement - Apple Design Language

**File: `Cloutmate/Views/AIAssistant/AIAssistantView.swift`**

Apply Apple design principles:

- **Spacing:** Increase padding (16pt → 20pt for main areas)
- **Typography:** Use SF Pro system fonts, refined hierarchy
- **Corners:** Subtle corner radius (8pt → 12pt for cards)
- **Shadows:** Softer, more subtle shadows
- **Materials:** Use `.ultraThinMaterial` or `.thinMaterial` consistently
- **Dividers:** Subtle, reduced opacity dividers
- **Colors:** Leverage ARTE emotional palettes for accents

### 8. Quick Action Tools Redesign

**File: `Cloutmate/Views/AIAssistant/AIAssistantView.swift` (quickActionTools)**

Replace horizontal scrolling toolbar:

- Move platform selector to input area (dropdown or segmented control)
- Move content tools to a secondary menu or remove entirely (focus on core capabilities)
- Keep Cloutmate branding but make it more minimal
- Use icon-only buttons with tooltips for discoverability

### 9. Input Area Enhancement

**File: `Cloutmate/Views/AIAssistant/AIAssistantView.swift` (inputArea)**

- Remove duplicate placeholder overlay
- Add platform selector as segmented control or dropdown near input
- Improve attachment preview styling
- Better spacing and alignment

## Implementation Details

### Toolbar Button Component

Create reusable toolbar button component that:

- Accepts icon, label (optional), action
- Supports ARTE state tinting
- Shows micro-feedback on press
- Has hover states

### Usage Tracking

Store toolbar usage in UserDefaults:

```swift
@AppStorage("toolbarUsage") private var toolbarUsage: Data = Data()
```

### ARTE Integration

Access ARTE state via:

- `GlassColorSystem.active?.emotionalState`
- `viewModel.currentActivity` for activity-based tinting
- Map activities to emotional states: `.analyzingDocument` → analyzing → amber

## Files to Modify

1. `Cloutmate/Views/AIAssistant/AIAssistantView.swift` - Main UI redesign
2. `Cloutmate/Services/ToolbarUsageTracker.swift` - New file for usage tracking
3. `Cloutmate/ViewModels/AIAssistantViewModel.swift` - Add toolbar reordering logic
4. `Cloutmate/Views/Components/AIToolbarButton.swift` - New reusable component (optional)

## Testing Checklist

- [ ] Toolbar icons display correctly with ARTE tinting
- [ ] No double placeholder visible
- [ ] Contextual hint appears/disappears correctly
- [ ] Toolbar reorders based on usage
- [ ] Micro-feedback appears on button press
- [ ] Overall UI feels more Apple-like while maintaining Cloutmate branding
- [ ] All core capabilities accessible from toolbar
- [ ] Platform selector accessible in input area
- [ ] Keyboard shortcuts work (⌘1-⌘6)
- [ ] ArteTintManager provides consistent tinting across views
- [ ] ToolbarButtonStyle applies consistent hover/press states