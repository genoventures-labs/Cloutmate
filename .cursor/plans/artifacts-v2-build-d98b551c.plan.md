<!-- d98b551c-4cfb-4ee0-b19a-ee1125336235 9a70a330-bd7d-40d7-a997-bd5babad1f95 -->
# Artifacts V2 — Build Plan

## Overview

A unified creative output surface for Cloutmate where every major piece of work (brief, summary, reflection, report, release note) lives, intelligently linked to its originating context (Project, Area, or Focus Session).

---

## Phase 1: Model Enhancements

### 1.1 Extend Artifact Model

**File:** `CloutmateShared/CloutmateShared/CloutmateShared/Models/Artifact.swift`

Add fields for V2 features:

- `focusSessionId: UUID?` - Link to originating Focus Session
- `linkedEntityIds: [UUID]` - Array of mentioned entity IDs (Projects, Areas, Tasks, Focus Sessions)
- `linkedEntityTypes: [String]` - Parallel array storing types ("project", "area", "task", "focusSession")
- `arteToneSnapshot: String?` - ARTE emotional state when artifact was created
- `sentimentSummary: String?` - AI-generated sentiment summary
- `confidenceScore: Double` - Confidence/quality score (0-1)
- `storyTokenIds: [UUID]` - Links to related StoryTokens from Narrative Engine
- `auroraNotes: String?` - Notes from Aurora learning loop
- `forecastSnapshot: Data?` - JSON snapshot of FocusForecast at creation time

### 1.2 Create ArtifactMention Model

**File:** `CloutmateShared/CloutmateShared/CloutmateShared/Models/ArtifactMention.swift`

SwiftData model tracking @mentions within artifacts:

- `artifactId: UUID`
- `mentionedEntityId: UUID`
- `mentionedEntityType: String` ("project", "area", "task", "focusSession")
- `mentionText: String` - The actual @mention text
- `position: Int` - Character position in content

---

## Phase 2: Core View Components

### 2.1 Main Artifacts View

**File:** `Cloutmate/Views/Artifacts/ArtifactsViewV2.swift`

Main orchestration view following `UnifiedProjectsView.swift` pattern:

- Header with title, filter chips (`All`, `Draft`, `Published`, `Archived`), global search bar, "+ New Artifact" button
- Content area with card grid/list layout
- Sidebar integration (`ArtifactSidebar`)
- Detail drawer integration (`ArtifactDetailDrawer`)
- Filter state management (`ArtifactFilter` enum)
- Search with fuzzy matching using `WorkspaceObjectSearchService`

**Key Features:**

- `@Query` for artifacts with sorting by `updatedAt`
- Filter chips using `ArtifactState` enum
- Search bar with debounced fuzzy search
- Selection mode support (like Projects V2)
- Scroll offset tracking for header opacity

### 2.2 Artifact Card Component

**File:** `Cloutmate/Views/Artifacts/ArtifactCardV2.swift`

Following `AreaCardV2.swift` pattern:

- Title + type label (Brief / Reflection / Report / Release Note)
- Linked entity chips (`@Project`, `@Area`, `@FocusSession`) using `BadgePill` pattern
- Status bar (Draft / Finalized / Published) with color coding
- ARTE color strip (thin bar at top using `ReactiveThemeManager.shared.currentState`)
- Updated timestamp + confidence icon
- Hover effects with `GlassMotion.Easing.spring`
- Glass panel background using `GlassPanel(tier: .contentCard)`

**Visual Elements:**

- ARTE tone-based accent color from `EmotionalPalette.palette(for: state)`
- Status indicator badge
- Linked entity count badges
- Confidence meter (circular progress if confidence < 0.8)

### 2.3 Artifact Detail Drawer

**File:** `Cloutmate/Views/Artifacts/ArtifactDetailDrawer.swift`

Slide-out drawer (right side) for artifact editing:

- Rich-text editor with `MentionInputField` integration
- Capture / Craft toggle (reuse `ComposerMode` enum from `ArtifactComposerView`)
- Side metadata panel:
  - Linked items list (Projects, Areas, Tasks, Focus Sessions)
  - Sentiment summary display
  - Aurora notes section
- AI toolbar: Generate Summary • Refine Tone • Export • Forecast
- Predictive cognition forecast meter (energy/stability overlay)
- Glass overlay for live ARTE state visualization

**Editor Integration:**

- Use `RichTextEditor` component with `MentionInputField` for @mentions
- Real-time mention parsing using `MentionParser`
- Auto-save on content change (debounced)

### 2.4 Artifact Sidebar

**File:** `Cloutmate/Views/Artifacts/ArtifactSidebar.swift`

Following `AreasSidebar.swift` pattern:

- Filters section:
  - Type filter (OutputFormat enum)
  - ARTE tone filter (EmotionalState enum)
  - Recency filter (Today, This Week, This Month)
  - Mentions filter (Show artifacts with @mentions)
- Smart suggestions:
  - "Artifacts needing review" (drafts older than 7 days)
  - "Unlinked drafts" (artifacts with no @mentions)
- Aurora "Echo Card":
  - Short insight from learning loop
  - Uses `AIFeedbackLogger` recent summaries
  - Example: "Most reflections this week show higher focus clarity than last."

**Components:**

- `DashboardSectionPanel` for collapsible sections
- Chart integration for artifact frequency over time
- Aurora insight card with `GlassPanel(tier: .contentCard)`

### 2.5 Artifact Editor Toolbar

**File:** `Cloutmate/Views/Artifacts/ArtifactEditorToolbar.swift`

AI-powered toolbar for artifact refinement:

- **Generate Summary**: Uses `AICreativeService` to generate artifact summary
- **Refine Tone**: Adjusts writing tone based on ARTE state
- **Export**: PDF / Markdown / Plaintext export
- **Forecast**: Shows predictive reflection forecast badge

**Integration Points:**

- `AICreativeService.shared.executeTool()` for AI operations
- `ArtifactExportService` for export functionality
- `CognitionPredictor` for forecast data

### 2.6 Artifact Quick Add Sheet

**File:** `Cloutmate/Views/Artifacts/ArtifactQuickAddSheet.swift`

Modal sheet for quick artifact creation:

- Reuse `ArtifactComposerView` but with V2 enhancements
- Pre-fill linked context if created from Project/Area/Focus Session
- Capture mode by default with smooth fade-in animation
- Glass overlay effect

---

## Phase 3: Service Layer

### 3.1 Artifact Analytics Service

**File:** `Cloutmate/Services/ArtifactAnalyticsService.swift`

Analytics and insights for artifacts:

- `streakCount(for: modelContext:)` - Consecutive days with artifacts
- `frequencyStats(modelContext:)` - Artifacts per week/month
- `toneDeviation(artifact: modelContext:)` - Compare artifact tone vs ARTE tone
- `linkedEntityStats(artifact: modelContext:)` - Count linked entities
- `confidenceTrend(limit: modelContext:)` - Confidence score trends over time

**Integration:**

- Uses `ReactiveThemeManager` for ARTE tone comparison
- Queries `Artifact` model with SwiftData

### 3.2 Artifact Predictive Bridge

**File:** `Cloutmate/Services/ArtifactPredictiveBridge.swift`

Bridges artifacts to Predictive Reflection Engine:

- `getForecastForArtifact(_: modelContext:)` - Returns `FocusForecast` snapshot
- `updateForecastBadge(_: modelContext:)` - Updates artifact's forecast badge
- `suggestRevisionTiming(_: modelContext:)` - Suggests when to revise based on drift
- `checkEnergyPatternMatch(_: modelContext:)` - Compares artifact creation time to forecast

**Integration:**

- `CognitionPredictor.shared.getLatestForecast()`
- `DriftMonitor.shared.driftPublisher` for drift detection
- Stores forecast snapshot in `Artifact.forecastSnapshot`

### 3.3 Artifact Export Service

**File:** `Cloutmate/Services/ArtifactExportService.swift`

Export functionality:

- `exportToPDF(_: url:)` - PDF export with formatting
- `exportToMarkdown(_:)` - Markdown export
- `exportToPlaintext(_:)` - Plain text export
- `exportToDrafts(_:)` - Copy to Drafts tab

**Formatting:**

- Includes linked entities as footnotes
- Includes ARTE tone snapshot
- Includes sentiment summary
- Includes Aurora notes

### 3.4 Artifact Mention Service

**File:** `Cloutmate/Services/ArtifactMentionService.swift`

Manages @mention parsing and CPS updates:

- `parseMentions(in: artifact:)` - Extract @mentions from content
- `updateLinkedEntities(for: artifact: modelContext:)` - Update `linkedEntityIds`
- `boostCPSForMentions(in: artifact: modelContext:)` - Boost CPS scores for mentioned entities
- `getMentionedEntities(for: artifact: modelContext:)` - Retrieve full entity objects

**Integration:**

- Uses `MentionParser` for parsing
- Uses `PriorityEngine.shared.boostScore()` for CPS updates
- Creates `ArtifactMention` records

---

## Phase 4: Integration Points

### 4.1 @Mention Integration

**Enhancement:** Extend `MentionInputField` to support Focus Sessions

- Update `WorkspaceObjectSearchService` to include `FocusSession` in search results
- Add Focus Session to `WorkspaceObjectResult` type enum
- Update autocomplete UI to show Focus Session icon

**Files Modified:**

- `Cloutmate/Services/WorkspaceObjectSearchService.swift`
- `Cloutmate/Views/Components/MentionAutocompleteView.swift`

### 4.2 Predictive Reflection Engine Hooks

**Integration:** Connect artifacts to `CognitionPredictor` and `DriftMonitor`

- When artifact is created, capture current `FocusForecast` snapshot
- Display forecast badge on artifact card (Focus Peak, Fatigue Risk, Energy Trend)
- `DriftMonitor` suggests revisions when energy pattern mismatches

**Files Modified:**

- `Cloutmate/Services/ArtifactPredictiveBridge.swift` (new)
- `Cloutmate/Views/Artifacts/ArtifactCardV2.swift`

### 4.3 ARTE Synchronization

**Integration:** Apply ARTE tone to artifacts

- Store ARTE tone snapshot on artifact creation (`ReactiveThemeManager.shared.currentState`)
- Apply tone-based visual themes to artifact cards
- Show emotional summary bar comparing writing tone vs ARTE tone

**Files Modified:**

- `Cloutmate/Views/Artifacts/ArtifactCardV2.swift`
- `Cloutmate/Views/Artifacts/ArtifactDetailDrawer.swift`

### 4.4 Cross-Conversation Memory

**Integration:** Pull excerpts from AI Assistant chats

- When editing artifact, show related conversation excerpts
- Suggest continuity prompts: "You discussed this topic in last week's reflection — want to import context?"

**Files Modified:**

- `Cloutmate/Views/Artifacts/ArtifactDetailDrawer.swift`
- Uses `ConversationArchive.shared.searchConversations()`

### 4.5 Narrative Engine Integration

**Integration:** Emit StoryTokens from artifacts

- When artifact is finalized, extract concepts using `ConceptTracker`
- Create `StoryToken` entries for artifact themes
- Feed artifact concepts to `NarrativeEngine` for weekly summaries

**Files Modified:**

- `Cloutmate/Services/ArtifactMentionService.swift`
- Uses `ConceptTracker.shared.trackConcepts()`

### 4.6 Smart Automation

**Integration:** Detect patterns and suggest templates

- Detect repetition ("weekly reports") → suggest templates
- Offer scheduling automation ("Generate reflection every Friday 5pm")

**Files Modified:**

- `Cloutmate/Services/SmartAutomationEngine.swift`
- Add artifact pattern detection methods

### 4.7 Export & Publishing

**Integration:** Export to external formats

- PDF / Markdown / Plaintext export
- Local-only by default; can push to Notion if enabled

**Files Modified:**

- `Cloutmate/Services/ArtifactExportService.swift` (new)

---

## Phase 5: UI/UX Enhancements

### 5.1 Visual Design

- Glass layers using `GlassPanel(tier:)` with consistent corner radius (12px)
- Blurred panels for overlays
- ARTE color strips on cards (thin horizontal bar at top)
- Smooth animations using `GlassMotion.Easing.spring`
- Haptic feedback on interactions (`NSHapticFeedbackManager`)

### 5.2 Animations

- Create Artifact: Modal fade-in with `GlassMotion.Easing.modalOpen`
- Switch to Craft: Editor transition with focus animation
- Save: Shimmer effect + haptic pulse
- Link via @: Inline highlight + quick preview
- Forecast Update: Smooth gauge fill animation
- Reflection Posted: "Echo" appears in sidebar with fade-in

### 5.3 Accessibility

- VoiceOver labels for all interactive elements
- Keyboard navigation support
- Dynamic Type support
- Reduced motion support

---

## Phase 6: Navigation Integration

### 6.1 Main Window Integration

**File:** `Cloutmate/Views/MainWindowView.swift`

Add Artifacts tab to main navigation:

- New tab item "Artifacts" with icon
- Route to `ArtifactsViewV2`
- Badge count for drafts needing review

### 6.2 Context Menu Integration

Add "Create Artifact" to:

- Project context menu
- Area context menu
- Focus Session completion screen
- Task context menu

---

## Phase 7: Testing & Polish

### 7.1 Unit Tests

- `ArtifactAnalyticsService` tests
- `ArtifactPredictiveBridge` tests
- `ArtifactMentionService` tests
- `ArtifactExportService` tests

### 7.2 Integration Tests

- @Mention parsing and CPS updates
- ARTE tone synchronization
- Forecast badge updates
- Cross-conversation memory retrieval

### 7.3 UI Polish

- Smooth transitions
- Loading states
- Error handling
- Empty states

---

## File Structure

```
Cloutmate/Views/Artifacts/
├── ArtifactsViewV2.swift          (Main view)
├── ArtifactCardV2.swift           (Card component)
├── ArtifactDetailDrawer.swift     (Detail drawer)
├── ArtifactEditorToolbar.swift    (AI toolbar)
├── ArtifactSidebar.swift          (Sidebar filters)
└── ArtifactQuickAddSheet.swift    (Quick add modal)

Cloutmate/Services/
├── ArtifactAnalyticsService.swift      (Analytics)
├── ArtifactPredictiveBridge.swift      (Predictive hooks)
├── ArtifactExportService.swift          (Export)
└── ArtifactMentionService.swift         (Mention handling)

CloutmateShared/.../Models/
├── Artifact.swift (enhanced)
└── ArtifactMention.swift (new)
```

---

## Dependencies

- Existing: `GlassColorSystem`, `GlassPanel`, `GlassMotion`, `ReactiveThemeManager`, `CognitionPredictor`, `DriftMonitor`, `ConversationArchive`, `ConceptTracker`, `PriorityEngine`, `MentionParser`, `WorkspaceObjectSearchService`
- New: None (all services exist)

---

## Success Criteria

1. ✅ Artifacts can be created with @mentions to Projects, Areas, Tasks, Focus Sessions
2. ✅ CPS scores update when artifacts mention entities
3. ✅ ARTE tone is captured and displayed on artifact cards
4. ✅ Forecast badges show on artifacts (Focus Peak, Fatigue Risk, Energy Trend)
5. ✅ Cross-conversation memory suggests related context
6. ✅ Artifacts emit StoryTokens to Narrative Engine
7. ✅ Export functionality works (PDF, Markdown, Plaintext)
8. ✅ Smart automation detects patterns and suggests templates
9. ✅ UI follows Areas/Projects V2 design language
10. ✅ All animations are smooth and haptic feedback works

### To-dos

- [ ] Extend Artifact model with focusSessionId, linkedEntityIds, arteToneSnapshot, sentimentSummary, confidenceScore, storyTokenIds, auroraNotes, forecastSnapshot fields
- [ ] Create ArtifactMention SwiftData model for tracking @mentions within artifacts
- [ ] Build ArtifactsViewV2.swift main orchestration view with header, filters, search, and card grid/list layout
- [ ] Build ArtifactCardV2.swift component with title, type label, linked entity chips, status bar, ARTE color strip, timestamp, confidence icon
- [ ] Build ArtifactDetailDrawer.swift with rich-text editor, Capture/Craft toggle, side metadata panel, AI toolbar, forecast meter, ARTE overlay
- [ ] Build ArtifactSidebar.swift with filters (Type, ARTE tone, Recency, Mentions), smart suggestions, Aurora Echo Card
- [ ] Build ArtifactEditorToolbar.swift with Generate Summary, Refine Tone, Export, Forecast actions
- [ ] Build ArtifactQuickAddSheet.swift modal for quick artifact creation
- [ ] Create ArtifactAnalyticsService.swift for streaks, frequency, tone deviation, confidence trends
- [ ] Create ArtifactPredictiveBridge.swift to connect artifacts to CognitionPredictor and DriftMonitor
- [ ] Create ArtifactExportService.swift for PDF, Markdown, Plaintext export functionality
- [ ] Create ArtifactMentionService.swift for parsing @mentions and updating CPS scores
- [ ] Extend MentionInputField and WorkspaceObjectSearchService to support Focus Sessions in @mention autocomplete
- [ ] Integrate ARTE tone synchronization: capture snapshot on creation, apply visual themes, show emotional summary bar
- [ ] Integrate Predictive Reflection Engine: capture FocusForecast snapshot, display forecast badges, DriftMonitor revision suggestions
- [ ] Integrate Cross-Conversation Memory: show related conversation excerpts, suggest continuity prompts
- [ ] Integrate Narrative Engine: extract concepts from artifacts, create StoryTokens, feed to weekly summaries
- [ ] Add artifact pattern detection to SmartAutomationEngine for template suggestions and scheduling
- [ ] Add Artifacts tab to MainWindowView navigation with badge count for drafts needing review
- [ ] Add 'Create Artifact' context menu items to Project, Area, Focus Session, Task views