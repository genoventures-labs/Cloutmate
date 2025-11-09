<!-- c01fa6ae-ed5d-4658-8727-d35842c8f7d2 d6d8af7c-8e39-4430-8887-0dc1bda0b123 -->
# AI Assistant V2 Build Plan

## Overview

AI Assistant V2 merges Aurora's intelligence systems (Recall, CPS, ARTE, Predictive Cognition) into a unified, glass-layered workspace. The redesign adopts the calm, glass-layered aesthetic shared across all tabs while retaining all conversational, operational, and analytical power.

**Foundation:** GlassMotion + ARTE + CPS Context

**Internal Name:** `AuroraV2`

**Tab:** `AI Assistant`

---

## Phase 1: Layout Architecture

### 1.1 Create Unified Main View

**New File:** `Cloutmate/Views/AIAssistant/UnifiedAIAssistantView.swift`

- Replace `AIAssistantView.swift` with new unified structure
- Use `HSplitView` for sidebar + main pane layout
- Implement Glass Tier system:
  - Header: `.overlay` tier
  - Sidebar: `.contentCard` tier  
  - Conversation pane: `.background` tier
  - Toolbar: `.overlay` tier
  - Composer: `.contentCard` tier
- Integrate `ReactiveThemeManager` for ARTE emotional state
- Apply ARTE gradient tint to conversation pane background

### 1.2 Create Header Component

**New File:** `Cloutmate/Views/AIAssistant/AIAssistantHeaderView.swift`

- Gradient title: "Aurora" with subtitle "Your cognitive assistant"
- Search button (`⌘F`) - contextual search through conversations
- Filter dropdown: `AI / All / Archived / Drafts`
- Quick New Chat button (+)
- Settings gear → opens Aurora Preferences sheet
- Use `.overlay` tier with `.ultraThinMaterial` background

### 1.3 Create Sidebar Component

**New File:** `Cloutmate/Views/AIAssistant/AIAssistantSidebar.swift`

- Display pinned and recent conversations
- Dynamic grouping by tags, sentiment, and CPS weight
- Hover actions: Pin, Rename, Delete
- ARTE-synced color accent:
  - Focused → blue
  - Reflective → purple
  - Fatigued → gray
- Use `ConversationRow` from existing `AIAssistantView.swift` as base
- Integrate `PriorityEngine.shared.getTopObjects()` for CPS-weighted sorting
- Show ARTE emotional state indicator per conversation

### 1.4 Create Toolbar Component

**New File:** `Cloutmate/Views/AIAssistant/AIAssistantToolbar.swift`

- Floating bar above message composer
- Actions:
  - Smart Recap (generates session summary)
  - Export to Drafts
  - Model Switcher (llama3.1, codellama, vision)
  - Airplane Mode Toggle
  - Voice Input (uses `VoiceTranscriptionService`)
- Use `.overlay` tier with glass styling
- Position above composer with proper spacing

### 1.5 Create Message Composer Component

**New File:** `Cloutmate/Views/AIAssistant/AIMessageComposer.swift`

- Rounded text field (multi-line) using `MentionInputField`
- "Send" button with gradient accent
- Autocomplete for `@Mentions` (already exists in `MentionInputField`)
- Keyboard: `Shift+Enter` = newline, `Enter` = send
- Optional "Confidence Preview" meter (color pulse = model certainty)
- Integrate with `VoiceTranscriptionService` for voice input
- Use `.contentCard` tier styling

---

## Phase 2: Core Features

### 2.1 Enhanced @Mention Linking

**Modify:** `Cloutmate/Services/AIActionRouter.swift`

- Add `resolveEntity(mentionText:modelContext:)` method
- Return entity type, ID, and display name
- Support deep linking to respective tabs:
  - Projects → `.projects` tab
  - Tasks → `.tasks` tab
  - Notes → `.notes` tab
  - Posts → `.posts` tab

**Modify:** `Cloutmate/Views/Components/MentionInputField.swift`

- Enhance autocomplete dropdown with entity type icons
- Show preview summary card on hover (glass popup)
- Make mentions tappable inline chips after send
- On click, trigger deep link via `NotificationCenter`:
  ```swift
  NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.projects)
  NotificationCenter.default.post(name: .openEntity, object: entityId)
  ```


**Add:** `Notification+Names.swift` extension

- Add `.openAIAssistantThread` notification name
- Add `.openEntity` notification name

### 2.2 Conversation Memory Layer

**Modify:** `Cloutmate/Services/AIRecallService.swift`

- Add `generateContextSnapshot(conversationId:modelContext:)` method
- Auto-summarize after 5+ messages
- Store conversation sentiment, tags, and ARTE tone
- Create "Context Snapshot" tile visible in sidebar
- Support multi-thread linking via existing `RecallService.shared`

**Modify:** `Cloutmate/ViewModels/AIAssistantViewModel.swift`

- Add conversation summarization trigger after 5 messages
- Store summary in `AIConversation.summary` field
- Track ARTE emotional state per conversation

### 2.3 Pinning, Tagging, and Filtering

**Enhance:** `AIAssistantSidebar.swift`

- Pin star toggles (persistent at top)
- Tags: "Planning", "Reflection", "Creative", "Support", "Execution"
- Filter dropdown in header for category selection
- Use existing `AIConversation.isPinned` and `AIConversation.tags` properties

### 2.4 Smart Recap & Draft Export

**Modify:** `Cloutmate/ViewModels/AIAssistantViewModel.swift`

- Add `generateSmartRecap(modelContext:)` method
- Generate auto-summary on session end (when conversation closes)
- Export options:
  - **Drafts** (rich text with metadata) - use existing `exportToDraft()` method
  - **Notes** (Markdown summary) - create new `exportToNote()` method
  - **Journal** (emotional reflection only) - create new `exportToJournal()` method
- Use same toast animation as Tasks quick-add

### 2.5 Global Search + Spotlight

**New File:** `Cloutmate/Views/AIAssistant/AIAssistantSpotlightOverlay.swift`

- `⌘+K` → Search all Aurora conversations and entities
- `⌘+⇧+A` → Aurora Spotlight overlay (quick command)
- Spotlight UI mirrors Calendar's overlay - translucent with large text field
- Query parsing: intent classification (`create`, `analyze`, `summarize`, etc.)
- Use `AuroraSpotlightView.swift` as reference for overlay structure
- Integrate with `WorkspaceObjectSearchService` for entity search

**Modify:** `Cloutmate/CloutmateApp.swift`

- Add keyboard shortcut handlers for `⌘+K` and `⌘+⇧+A`
- Show spotlight overlay on shortcut

### 2.6 Cross-Conversation Intelligence

**Enhance:** `Cloutmate/Services/AIRecallService.swift`

- Context recall across multiple sessions
- Highlight repeated entities and common patterns
- Weekly "Learning Loop" summary surfaced in Insights
- Use existing `ConversationArchive` service for cross-conversation memory

### 2.7 Model Switching & Confidence Meter

**Modify:** `Cloutmate/Views/AIAssistant/AIAssistantToolbar.swift`

- Toolbar toggle cycles through models:
  - `llama3.1` (default)
  - `codellama` (dev tasks)
  - `llama3.2-vision` (image analysis)
- Use `AISettings.shared.selectedOllamaModel` for current model
- Call `OllamaBridgeService.shared.setModel(_:)` on switch

**New Component:** Confidence meter in `AIMessageComposer.swift`

- Color pulse below message bubble:
  - Low → orange
  - Medium → purple
  - High → green
- Calculate confidence from model response metadata (if available)

### 2.8 Voice Input Integration

**Enhance:** `Cloutmate/Views/AIAssistant/AIAssistantToolbar.swift`

- Microphone icon in toolbar
- Start live transcription overlay using `VoiceTranscriptionService`
- Real-time text stream in composer
- End automatically on silence threshold
- Use existing `VoiceInputButton` component as reference

### 2.9 Airplane Mode + Offline Cognition

**Modify:** `Cloutmate/Models/AISettings.swift`

- Add `isAirplaneModeEnabled: Bool` property
- Add `@AppStorage` for persistence

**Modify:** `Cloutmate/Views/AIAssistant/AIAssistantToolbar.swift`

- Toggle in toolbar or Settings → AI
- Disables external requests, locks to local Ollama model
- Banner: "Offline cognition active"
- All features remain functional (no internet dependency)

### 2.10 ARTE + Focus Gravity Integration

**Modify:** `Cloutmate/Views/AIAssistant/UnifiedAIAssistantView.swift`

- Gradient tint changes dynamically by emotional tone
- Use `ReactiveThemeManager.shared.currentState` for ARTE state
- Apply gradient overlay to conversation pane:
  ```swift
  .background(
    LinearGradient(
      colors: [arteGradientStart, arteGradientEnd],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .opacity(0.1)
  )
  ```

- Session "energy" derived from Focus Gravity metrics
- Aurora reflections at session end:

> "Your energy is trending steady. Would you like to shift to Focus Mode?"

---

## Phase 3: Motion & Interaction System

### 3.1 Animation Integration

**Use Existing:** `Cloutmate/Utilities/GlassMotion.swift`

- Hover on card: `.floatLift()` (use existing `HoverEffect` modifier)
- Message send: `.GlassMotion.ripple` (use `GlassMotion.Duration.ripple`)
- Sidebar expand: `.spring(duration:0.35)` (use `GlassMotion.Easing.spring`)
- Filter change: `.opacity` fade
- AI summary load: Shimmer gradient sweep (use `GlassMotion.Shimmer`)

### 3.2 ARTE Emotional Animation Speed

**Modify:** `Cloutmate/Views/AIAssistant/UnifiedAIAssistantView.swift`

- Use `GlassMotion.emotionalSpeedMultiplier` for animation speed
- Apply ARTE-modulated animations throughout interface

---

## Phase 4: Design Tokens

### 4.1 Apply Design System

**Use Existing Tokens:**

- Corner Radius: 12pt (from `GlassTierCalculator`)
- Font: SF Pro Rounded / Inter
- Gradients: `kosmicBlue → kosmicPurple` (calm)
- Blur: `.ultraThinMaterial` (from `GlassMaterialTiers`)
- Shadow: `kosmicPurple.opacity(0.15), radius 3`
- Animation: `GlassMotion.spring`
- Color States: ARTE adaptive palette (from `EmotionalState`)

**Reference Files:**

- `CloutmateShared/CloutmateShared/UI/GlassColorSystem.swift`
- `CloutmateShared/CloutmateShared/UI/GlassMaterialTiers.swift`
- `Cloutmate/Models/EmotionalState.swift`

---

## Phase 5: Implementation Files

### New Files:

1. `Cloutmate/Views/AIAssistant/UnifiedAIAssistantView.swift` - Main unified view
2. `Cloutmate/Views/AIAssistant/AIAssistantHeaderView.swift` - Header component
3. `Cloutmate/Views/AIAssistant/AIAssistantSidebar.swift` - Sidebar component
4. `Cloutmate/Views/AIAssistant/AIAssistantToolbar.swift` - Toolbar component
5. `Cloutmate/Views/AIAssistant/AIMessageComposer.swift` - Message composer
6. `Cloutmate/Views/AIAssistant/AIAssistantMessageBubble.swift` - Enhanced message bubble (or enhance existing)
7. `Cloutmate/Views/AIAssistant/AIAssistantSpotlightOverlay.swift` - Spotlight overlay

### Modified Files:

1. `Cloutmate/Services/AIActionRouter.swift` - Add @mention linking + entity deep linking
2. `Cloutmate/Services/VoiceTranscriptionService.swift` - Improved real-time stream (if needed)
3. `Cloutmate/Services/AIRecallService.swift` - Conversation threading + summarization hooks
4. `Cloutmate/ViewModels/AIAssistantViewModel.swift` - Smart recap, export methods, ARTE integration
5. `Cloutmate/Models/AISettings.swift` - Add airplane mode property
6. `Cloutmate/CloutmateApp.swift` - Add keyboard shortcuts for spotlight
7. `Cloutmate/Views/Components/MentionInputField.swift` - Enhanced autocomplete with deep links
8. `Cloutmate/Views/MainWindowView.swift` - Route to new `UnifiedAIAssistantView`

### Notification Extensions:

**Modify:** `Cloutmate/Utilities/Notification+Names.swift` (or create if doesn't exist)

- Add `.openAIAssistantThread` notification
- Add `.openEntity` notification for deep linking

---

## Phase 6: Testing Checklist

- [ ] Header and toolbar alignment across all tiers
- [ ] @Mention autocomplete and deep links functional
- [ ] Smart Recap and Export to Drafts functional
- [ ] Model switching behavior verified
- [ ] Voice Input recording and transcription accuracy
- [ ] ARTE tint updates per emotional state
- [ ] Spotlight and Global Search command routing
- [ ] Calm Mode / Reduce Motion compliance
- [ ] Keyboard navigation: ↑↓ select conversation, Enter open, ⎋ close drawer
- [ ] Airplane mode disables external requests
- [ ] Confidence meter displays correctly
- [ ] Cross-conversation memory recall works

---

## Implementation Order

1. **Phase 1** - Layout Architecture (UnifiedAIAssistantView + components)
2. **Phase 2.1-2.3** - Core features (Mentions, Memory, Pinning/Tagging)
3. **Phase 2.4-2.6** - Smart Recap, Search, Cross-conversation
4. **Phase 2.7-2.10** - Model switching, Voice, Airplane mode, ARTE integration
5. **Phase 3** - Motion & Interaction
6. **Phase 4** - Design tokens application
7. **Phase 6** - Testing

---

## Key Integration Points

- **ARTE:** Use `ReactiveThemeManager.shared` for emotional state
- **CPS:** Use `PriorityEngine.shared.getTopObjects()` for sidebar sorting
- **Recall:** Use `AIRecallService.shared` for conversation context
- **Glass System:** Use `GlassColorSystem`, `GlassMaterialTiers`, `GlassMotion`
- **Voice:** Use `VoiceTranscriptionService.shared`
- **Models:** Use `OllamaBridgeService.shared` and `AISettings.shared`
- **Deep Links:** Use `NotificationCenter` with `.switchTab` and new `.openEntity` notifications

### To-dos

- [ ] Create UnifiedAIAssistantView.swift with HSplitView layout, Glass Tier system, and ARTE integration
- [ ] Create AIAssistantHeaderView.swift with gradient title, search (⌘F), filter dropdown, quick new chat, and settings gear
- [ ] Create AIAssistantSidebar.swift with pinned/recent conversations, ARTE color accents, dynamic grouping by tags/sentiment/CPS, and hover actions
- [ ] Create AIAssistantToolbar.swift with Smart Recap, Export to Drafts, Model Switcher, Airplane Mode Toggle, and Voice Input
- [ ] Create AIMessageComposer.swift with rounded text field, @mention autocomplete, Send button with gradient, keyboard shortcuts (Shift+Enter/Enter), and confidence meter
- [ ] Enhance @mention linking in AIActionRouter.swift and MentionInputField.swift with entity deep linking, preview cards, and tappable chips
- [ ] Add conversation memory layer to AIRecallService.swift with auto-summarization after 5+ messages, context snapshots, and ARTE tone tracking
- [ ] Implement Smart Recap and export functionality in AIAssistantViewModel.swift (Drafts, Notes, Journal exports)
- [ ] Create AIAssistantSpotlightOverlay.swift with ⌘+K global search and ⌘+⇧+A Aurora Spotlight overlay
- [ ] Add model switching UI to toolbar with llama3.1, codellama, and vision model options
- [ ] Add airplane mode toggle to AISettings.swift and toolbar, disabling external requests and locking to local Ollama
- [ ] Integrate ARTE gradient tints into UnifiedAIAssistantView based on ReactiveThemeManager emotional state
- [ ] Add keyboard shortcuts (⌘+K, ⌘+⇧+A) to CloutmateApp.swift for spotlight overlay
- [ ] Apply GlassMotion animations (hover lift, ripple, spring, shimmer) throughout all components
- [ ] Update MainWindowView.swift to route AI Assistant tab to new UnifiedAIAssistantView