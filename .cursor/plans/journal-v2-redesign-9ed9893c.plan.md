<!-- 9ed9893c-4247-4dfd-a6e8-06bed630e9d4 af6303ab-c051-4939-9c67-4631857d4f5d -->
# Journal V2 Redesign Plan

## Overview

Transform the Journal view into a reflective workspace that captures emotional patterns, creative reflections, and daily summaries — directly linked with Aurora's emotional intelligence and Focus Gravity data.

Visually, Journal V2 merges **Rituals' calm card aesthetic** with **Notes' drawer mechanics** and **Calendar's gradient language**.

---

## Phase 1: Unified Header Zone

**File:** `Cloutmate/Views/Journal/Components/JournalHeaderView.swift` (new)

### Structure

- **Title:** "Journal" in `.system(.title3, design: .rounded)` with gradient foreground (kosmicBlue → kosmicPurple)
- **Subline:** "Reflections synced with Aurora" (updates dynamically if predictive cognition is active)
- **Filters:** Filter chips for "All", "Morning", "Evening", "Mood Entries", "AI Reflections"
- **Search Bar:** Glass inline field with placeholder "Search reflections or emotions…"
- **Quick Add:** `+` GlassButton (new entry modal)

### Visual Design

- Background: `.glassPanel(tier: .overlay)`
- Padding: `.horizontal(20)`, `.vertical(16)`
- Scroll fade transitions (`.opacity.combined(with: .move(edge: .top))`)
- Accent gradient: kosmicBlue → kosmicPurple

### Implementation

- Create `JournalHeaderView` component similar to `NotesHeaderView`
- Add filter enum: `JournalFilter` (all, morning, evening, moodEntries, aiReflections)
- Use `GlassButton` with `.iconOnly` style for Quick Add
- Integrate with `UnifiedJournalView` state management

---

## Phase 2: Journal Card System

**File:** `Cloutmate/Views/Journal/Components/JournalCardV2.swift` (new)

### Card Structure

- **Base:** `.glassPanel(tier: .contentCard, cornerRadius: 12)`
- **Sections:**
- **Header:** Date (e.g., "Nov 5, 2025") + tag badge (Morning / Evening / Reflection)
- **Body:** Excerpt (first 5 lines, fade gradient bottom edge)
- **Footer:** Mood icon + sentiment tone (from ARTE data, e.g., "Calm • 84%")
- **Hover:** `.floatLift()` + kosmicPurple shadow glow
- **Accent Indicator:** Left-edge gradient bar = emotional tone (blue = focused, purple = creative, green = accomplished)

### Interactions

- Tap → opens detail drawer
- Right-click → context menu (Edit, Duplicate, Export, Delete)
- Swipe (trackpad): Left = archive, Right = favorite

### Implementation

- Create `JournalCardV2` component following `NoteCardV2` pattern
- Add left-edge gradient bar (4pt width) based on `JournalMood` and ARTE tone
- Implement excerpt truncation with fade gradient overlay
- Use `GlassMotion.spring` for hover animations
- Add context menu using `contextMenu` modifier

---

## Phase 3: Journal Detail Drawer

**File:** `Cloutmate/Views/Journal/Components/JournalDetailDrawer.swift` (new)

### Drawer Layout

- Appears from right (400px width)
- `.ultraThinMaterial` blur background
- **Header:** Title (editable), timestamp, mood indicator
- **Body:** Markdown-compatible editor with calm typing feel (reduced motion, gentle caret glow)
- **Sidebar:**
- ARTE reflection summary card
- Mood analysis chart (mini radar of Calm / Creative / Chaotic / Restless)
- "Ask Aurora" button (contextual reflection — e.g., "What pattern do you notice here?")

### Features

- Auto-fetches **ARTE tone** and **Focus Gravity trend** for entry date
- Aurora can auto-generate a "Reflection Summary" after each entry save
- Drawer respects Calm Mode (reduces motion, muted blur)

### Implementation

- Follow `NoteDetailDrawer` pattern (right-side drawer, 400px width)
- Add ARTE integration: query `EmotionalStateDetector` for entry date
- Add Focus Gravity: query `AnalyticsEngine` for daily snapshot
- Create `ARTEReflectionCard` component for sidebar
- Create `MoodRadarChart` mini visualization component
- Add "Ask Aurora" button that opens mini chat overlay (similar to AI Assistant but contextual)

---

## Phase 4: Emotional Timeline

**File:** `Cloutmate/Views/Journal/Components/JournalTimelineView.swift` (new)

### Purpose

Visualize emotion and focus patterns over time.

### Design

- Horizontal scrollable timeline
- Dots represent entries; color = dominant mood tone
- Hover shows preview (title, date, mood)
- Gradient baseline (kosmicBlue → kosmicPurple → kosmicGreen)
- Integrates Focus Gravity data for matching intensity overlay

### Implementation

- Create horizontal `ScrollView` with `LazyHStack`
- Map journal entries to timeline dots (positioned by date)
- Color dots based on `JournalMood` enum (use `mood.color` property)
- Add hover preview tooltip using `.onHover` modifier
- Overlay Focus Gravity intensity as background gradient (query `AnalyticsEngine` for date range)

---

## Phase 5: Quick Add & Capture Flow

**Integration:** `Cloutmate/Views/Components/ContextualCreateSheet.swift` (modify)

### Changes

- Add `.journal` case to `actionsForTab` switch
- Options: "Morning Reflection", "Evening Reflection", "Free Write"
- On selection → opens `JournalDetailDrawer` with prefilled template

### Templates

- **Morning:** "Today I intend to…"
- **Evening:** "Today I learned…"
- **Free Write:** blank editor

### Implementation

- Add journal actions to `ContextualCreateSheet.actionsForTab`
- Create `JournalTemplate` enum (morning, evening, freeWrite)
- Modify `JournalDetailDrawer` to accept optional template parameter
- Prefill content based on template when creating new entry

---

## Phase 6: Aurora Integration

### Memory Graph Updates

**File:** `Cloutmate/Views/Journal/Components/JournalDetailDrawer.swift`

- Each entry update calls `AIRecallService.shared.registerUpdated(journal, modelContext: modelContext)`
- Link journal entries to Memory Graph nodes via tags and emotional keywords

### Emotional Continuity

- Journal entries update **Emotional Continuity layer** via `EmotionAnalyzer`
- Aurora can summarize mood shifts over week ("You've felt more focused lately than creative")
- Weekly reflection summary appears in **Insights → Emotional Trends**

### Ask Aurora Chat Overlay

**File:** `Cloutmate/Views/Journal/Components/AuroraJournalChatOverlay.swift` (new)

- Mini chat overlay (300px width, bottom-right corner)
- Contextual to current journal entry
- Prompts: "What pattern do you notice here?", "How does this relate to last week?", "What should I reflect on?"
- Uses `GeminiService` with journal entry context

### Implementation

- Add `updateMemoryGraph()` method to `JournalDetailDrawer` (called on save)
- Create `AuroraJournalChatOverlay` component (similar to AI Assistant but smaller, contextual)
- Add weekly reflection summary generation in `AIReflectionService` (new method: `reflectOnJournalEntries`)

---

## Phase 7: Unified Journal View

**File:** `Cloutmate/Views/Journal/UnifiedJournalView.swift` (new, replaces `JournalView.swift`)

### Structure

- Header: `JournalHeaderView`
- Content: ScrollView with `LazyVStack` of `JournalCardV2` components
- Timeline: Optional `JournalTimelineView` (toggleable)
- Drawer: `JournalDetailDrawer` overlay

### Grouping

- Group by date (Today, Yesterday, This Week, This Month, Older)
- Collapsible sections (similar to `UnifiedNotesView`)

### Implementation

- Follow `UnifiedNotesView` pattern
- Add date grouping logic
- Integrate drawer state management
- Add keyboard navigation (⌘N for new, Enter to open, Escape to close)

---

## Phase 8: Calm Mode & Accessibility

### Large Tap Targets

- Cards: min 56pt height
- Buttons: min 44x44pt

### Dynamic Type

- Use `.system(.body)` with Dynamic Type support
- Scale card text appropriately

### VoiceOver

- Reads date, tone, and excerpt
- Announces mood indicator and ARTE summary

### Reduce Motion

- Disables typing glow & hover lift
- Uses `.animation(nil)` when `accessibilityReduceMotion` is true

### High Contrast

- Fallback → solid kosmicBlue borders
- Increased contrast for mood indicators

---

## Phase 9: Motion & Visual Harmony

| Motion Type               | Component         | Description            |
| ------------------------- | ----------------- | ---------------------- |
| `.spring(duration: 0.35)` | Drawer open/close | Gentle entry motion    |
| `.floatLift()`            | Card hover        | Adds tactile depth     |
| `.opacity + .scale`       | Header fade       | Soft focus transitions |
| `.GlassMotion.ripple`     | Mood tag tap      | Subtle ripple feedback |

### Implementation

- Use `GlassMotion.Easing.spring` for drawer animations
- Apply `.floatLift()` modifier to `JournalCardV2`
- Add header scroll fade using `.opacity` and `.offset` modifiers
- Use `.ripple(color:)` modifier on mood tags

---

## Design Tokens

| Token            | Value                                                               |
| ---------------- | ------------------------------------------------------------------- |
| Corner radius    | 12pt                                                                |
| Primary Gradient | kosmicBlue → kosmicPurple                                           |
| Mood Gradient    | kosmicGreen → kosmicBlue (positive) / kosmicPurple → gray (neutral) |
| Shadow           | kosmicPurple.opacity(0.15), radius: 4                               |
| Blur             | `.ultraThinMaterial`                                                |
| Font             | SF Pro Rounded, Inter                                               |
| Animation        | `GlassMotion.spring`                                                |

---

## Implementation Files

### New Files

1. `Cloutmate/Views/Journal/Components/JournalHeaderView.swift`
2. `Cloutmate/Views/Journal/Components/JournalCardV2.swift`
3. `Cloutmate/Views/Journal/Components/JournalDetailDrawer.swift`
4. `Cloutmate/Views/Journal/Components/JournalTimelineView.swift`
5. `Cloutmate/Views/Journal/Components/AuroraJournalChatOverlay.swift`
6. `Cloutmate/Views/Journal/Components/ARTEReflectionCard.swift`
7. `Cloutmate/Views/Journal/Components/MoodRadarChart.swift`
8. `Cloutmate/Views/Journal/UnifiedJournalView.swift`

### Modified Files

1. `Cloutmate/Views/Components/ContextualCreateSheet.swift` - Add journal actions
2. `Cloutmate/Extensions/Notification+Names.swift` - Add `.openJournalEntry` notification
3. `Cloutmate/Views/MainWindowView.swift` - Update to use `UnifiedJournalView` instead of `JournalView`
4. `Cloutmate/Services/AIReflectionService.swift` - Add `reflectOnJournalEntries` method

---

## Testing Checklist

- [ ] Header search & filter chips function
- [ ] Card hover & mood indicator render correctly
- [ ] Drawer open/close with smooth transitions
- [ ] ARTE reflection summaries appear on save
- [ ] Aurora chat overlay functional
- [ ] Timeline renders emotional data accurately
- [ ] Quick Add templates load properly
- [ ] Reduce motion and calm mode respected
- [ ] VoiceOver announces key data correctly
- [ ] Memory Graph updates on journal save
- [ ] Focus Gravity data displays correctly

---

## Migration Strategy

1. Create new `UnifiedJournalView` alongside existing `JournalView`
2. Add feature flag to toggle between old and new views
3. Test thoroughly with existing journal data
4. Once stable, replace `JournalView` with `UnifiedJournalView` in `MainWindowView`
5. Archive old `JournalView.swift` (keep for reference)

---

## Emotional Identity

Journal V2 is about **gentle reflection** — it should feel serene, grounded, and intelligent.

It closes the loop of Cloutmate's cognitive model:

> Tasks → Projects → Focus → Reflection → Prediction.

### To-dos

- [ ] Create JournalHeaderView component with title, subline, filters, search bar, and Quick Add button
- [ ] Create JournalCardV2 component with card structure, hover effects, mood indicators, and left-edge gradient bar
- [ ] Create JournalDetailDrawer component with markdown editor, ARTE reflection card, mood radar chart, and Ask Aurora button
- [ ] Create JournalTimelineView component with horizontal scrollable timeline, mood-colored dots, and Focus Gravity overlay
- [ ] Create AuroraJournalChatOverlay component for contextual reflection chat
- [ ] Create UnifiedJournalView that integrates header, cards, timeline, and drawer following UnifiedNotesView pattern
- [ ] Add journal actions to ContextualCreateSheet with Morning/Evening/Free Write templates
- [ ] Integrate Memory Graph updates, Emotional Continuity, and weekly reflection summaries
- [ ] Add .openJournalEntry notification to Notification+Names.swift
- [ ] Update MainWindowView to use UnifiedJournalView instead of JournalView