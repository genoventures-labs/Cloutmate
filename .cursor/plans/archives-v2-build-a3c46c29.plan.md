<!-- a3c46c29-4e40-4b3f-a7d2-524d0badb153 9a632d38-b284-4cc3-8f0f-806cae8a98c8 -->
# Archives V2 Build Plan

## Overview

Transform the existing table-based ArchivesView into a unified, emotionally-aware archive system that preserves completed or inactive Projects, Areas, Artifacts, Notes, and Drafts with full context from ARTE, Aurora, Predictive Cognition, Memory Graph, and Focus Gravity systems.

## Architecture

**New Files:**

- `FocusOS/Views/Archives/Components/ArchivesHeaderView.swift`
- `FocusOS/Views/Archives/Components/ArchiveCardV2.swift`
- `FocusOS/Views/Archives/Components/ArchiveDetailDrawer.swift`
- `FocusOS/Views/Archives/Components/ArchiveReviewSheet.swift`
- `FocusOS/Views/Archives/Components/ArchivesSidebar.swift`
- `FocusOS/Views/Archives/UnifiedArchivesView.swift`
- `FocusOS/Services/ArchiveReflectionService.swift` (AI reflection generation)
- `FocusOS/Services/ArchiveReintegrationService.swift` (restore logic)

**Modified Files:**

- `FocusOS/Views/Archives/ArchivesView.swift` → Replace with UnifiedArchivesView
- `FocusOS/Services/ProjectFocusGravityService.swift` → Add `reintegrate()` method
- `FocusOS/Services/MemoryGraphService.swift` → Add `retrieveArchivedRelationships()` method
- `FocusOS/Services/ReactiveThemeManager.swift` → Add tone timeline query API

**Models:**

- Add `archivedAt: Date?` to Project, Area, Note, Artifact models (optional, defaults to updatedAt if nil)
- Create `ArchiveReflection` model for AI-generated reflections

---

## Phase 1: Unified Header Zone

**File:** `FocusOS/Views/Archives/Components/ArchivesHeaderView.swift`

**Components:**

1. **Title Section**

   - Gradient text: "Archives" (kosmicBlue → kosmicPurple)
   - Subline: "Everything you've completed, remembered, and learned."
   - Use `.glassPanel(tier: .overlay)` wrapper

2. **Filter Chips**

   - Horizontal scrollable chips: "All • Projects • Areas • Notes • Artifacts • Drafts"
   - Use existing `FilterChip` component pattern
   - Active state: kosmicBlue gradient background
   - `.GlassMotion.spring` transitions on selection

3. **Search Bar**

   - Inline TextField: "Search memories or milestones…"
   - Icon: `magnifyingglass`
   - `.glassPanel(tier: .contentCard)` background
   - Real-time filtering with debounce

4. **Quick Actions**

   - "Review Summary" button (🧭 icon) → Opens `ArchiveReviewSheet`
   - "Restore" button (🔁 icon) → Contextual restore menu
   - Use `GlassButton` component

**Visual:**

- Soft fade header animation matching Calendar V2 pattern
- kosmicBlue → kosmicPurple accent gradient
- `.GlassMotion.spring` transitions

---

## Phase 2: Archive Card System

**File:** `FocusOS/Views/Archives/Components/ArchiveCardV2.swift`

**Card Structure:**

```swift
struct ArchiveCardV2: View {
    let archiveItem: ArchiveItem
    let onTap: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void
}
```

**Layout:**

1. **Base Container**

   - `.glassPanel(tier: .contentCard, cornerRadius: 12)`
   - Padding: 16pt
   - `.floatLift()` on hover

2. **Header Row**

   - Entity icon (🗂 Project / 📄 Note / 🧠 Artifact / 🪞 Area / 📝 Draft)
   - Title (bold rounded font, SF Pro Rounded)
   - Tag badges: "Completed", "Reflective", "Milestone" (from Predictive Cognition)

3. **Body Section**

   - Short excerpt/summary (2-3 lines, truncated)
   - "Captured Insight" line: Aurora summary snippet (if available)
   - Mini ARTE tone bar: Color-coded mood history (horizontal bar with segments)

4. **Footer Row**

   - Archived date: "Aug 18, 2025" format
   - "From" source: Project/Area name (if linked)
   - Action buttons: Restore / Reflect / Delete (icon-only, compact)

**Interactions:**

- Tap → Opens `ArchiveDetailDrawer`
- Hover → `.floatLift()` animation
- Context menu → Restore / Permanently Delete / Share Reflection

**Data Sources:**

- Entity metadata (title, dates, status)
- Aurora summary from `ArchiveReflectionService`
- ARTE tone from `StateTransitionHistory` queries
- Focus Gravity score from `ProjectFocusGravityService`

---

## Phase 3: Archive Detail Drawer

**File:** `FocusOS/Views/Archives/Components/ArchiveDetailDrawer.swift`

**Layout:**

- Width: 480px
- Background: `.ultraThinMaterial`
- Slide-in animation: `.transition(.move(edge: .trailing))`

**Sections:**

1. **Header**

   - Title (editable for renamed archives)
   - Entity type badge + original creation date
   - Action buttons: "Restore" (primary), "View Linked Items"

2. **Body (ScrollView)**

   - **Full Summary**
     - AI-generated if missing (via `ArchiveReflectionService`)
     - Markdown rendering support

   - **Mood History Timeline**
     - ARTE tone graph: Query `StateTransitionHistory` for entity's lifetime
     - Color-coded segments (Calm/Reflective/Focused/Energized/Fatigued)
     - Mini sparkline visualization

   - **Reflection Notes**
     - Auto-generated reflection (from `ArchiveReflectionService`)
     - Manual notes section (editable)

   - **Aurora Commentary**
     - AI insight card: "This project stabilized your learning patterns."
     - Generated on archive, cached in `ArchiveReflection`

3. **Sidebar Section**

   - **Related Items**
     - From Memory Graph: `MemoryGraphService.retrieveArchivedRelationships()`
     - Shows linked entities with relationship types

   - **Tag List**
     - Auto-tags from Predictive Cognition context
     - Manual tags (editable)

**Features:**

- AI Reflection auto-generates on archive (via `ArchiveReflectionService`)
- Reopening archived items triggers `ArchiveReintegrationService.reintegrate()`

---

## Phase 4: Review Summary Mode

**File:** `FocusOS/Views/Archives/Components/ArchiveReviewSheet.swift`

**Function:**

- Full-screen sheet (or large drawer)
- Timeline view of recently archived entities
- Analytics and insights

**Layout:**

1. **Header**

   - "Review Summary" title
   - Date range selector (This Week / This Month / All Time)
   - Close button

2. **Charts Section**

   - **Weekly Completion Overview**
     - Bar chart: Focus Mode sessions + Tasks completed
     - Data from `AnalyticsEngine` + `FocusSessionService`

   - **ARTE Emotional Distribution**
     - Pie/bar chart: Tone frequency (Calm/Reflective/Focused/Energized/Fatigued)
     - Data from `StateTransitionHistory` queries

   - **Top Learning Themes**
     - List: Predictive Cognition pattern mining
     - Data from `CognitionPredictor` + `ConceptTracker`
     - Shows recurring themes with frequency

3. **Collapsible Sections**

   - "Projects" (recently archived)
   - "Notes" (recently archived)
   - "Artifacts" (recently archived)
   - Each shows card previews

4. **Aurora Insight Card**

   - `.glassPanel(tier: .overlay)`
   - AI summary: "You've been most consistent with calm focus, and growth peaks occurred midweek."
   - Generated via `CoreResponseService.shared.generateResponse()`

**Visual:**

- `.glassPanel(tier: .overlay)` containers
- Charts use `ChartGenerator` service patterns
- `.GlassMotion.spring` slide-in animation

---

## Phase 5: Sidebar

**File:** `FocusOS/Views/Archives/Components/ArchivesSidebar.swift`

**Sections:**

1. **Filters**

   - By Type: Projects / Areas / Notes / Artifacts / Drafts
   - By Date Range: This Week / This Month / This Year / All Time
   - By ARTE Tone: Calm / Reflective / Focused / Energized / Fatigued
   - By Source Tab: (if tracked)

2. **Insights**

   - **Most Common Completion Tone**
     - From ARTE summary: Query `StateTransitionHistory` for archived items
     - Shows dominant tone with percentage

   - **Average Focus Session Length**
     - From CPS data: `FocusSessionService` + `AnalyticsEngine`
     - Shows average duration for archived projects

   - **Reflection Density**
     - Ratio: Notes per archive (manual + AI-generated)
     - Shows engagement level

3. **Aurora Notes**

   - AI summaries of emotional continuity
   - Example: "You've closed 17 items with calm energy this month."
   - Generated periodically via `ArchiveReflectionService`

**Visual:**

- `.glassPanel(tier: .contentCard)` containers
- Gentle kosmicGreen pulse when new archive created
- Collapsible sections

---

## Phase 6: Data + Integration

### 6.1 Archive Reflection Service

**File:** `FocusOS/Services/ArchiveReflectionService.swift`

**Purpose:** Generate AI reflections when items are archived

**Methods:**

```swift
@MainActor
final class ArchiveReflectionService {
    static let shared = ArchiveReflectionService()
    
    func generateReflection(
        for item: ArchiveItem,
        modelContext: ModelContext
    ) async throws -> ArchiveReflection
    
    func getOrCreateReflection(
        for itemId: UUID,
        modelContext: ModelContext
    ) async -> ArchiveReflection?
}
```

**Data Sources:**

- Entity content (title, description, notes)
- ARTE tone history (`StateTransitionHistory`)
- Focus Gravity metrics (`ProjectFocusGravityService`)
- Memory Graph relationships (`MemoryGraphService`)
- Predictive Cognition themes (`CognitionPredictor`)

**AI Prompt:**

- Use `CoreResponseService.shared.generateResponse()`
- Include context: "Generate a reflection for this archived [Project/Note/Artifact]. Consider its emotional journey, completion patterns, and learning outcomes."

### 6.2 Archive Reintegration Service

**File:** `FocusOS/Services/ArchiveReintegrationService.swift`

**Purpose:** Handle restoration of archived items

**Methods:**

```swift
@MainActor
final class ArchiveReintegrationService {
    static let shared = ArchiveReintegrationService()
    
    func reintegrate(
        item: ArchiveItem,
        modelContext: ModelContext
    ) async throws
}
```

**Logic:**

- Restore entity status (Project.status = .active, Note.isArchived = false, etc.)
- Trigger `FocusGravityService.reintegrate()` if applicable
- Update Memory Graph relationships
- Clear `archivedAt` date
- Generate reintegration reflection (optional)

### 6.3 Focus Gravity Integration

**File:** `FocusOS/Services/ProjectFocusGravityService.swift`

**Add Method:**

```swift
func reintegrate(project: Project, modelContext: ModelContext) {
    // Reset focus metrics cache
    cache.removeValue(forKey: project.id)
    // Recalculate priority score
    // Update CPS ranking
}
```

### 6.4 Memory Graph Integration

**File:** `FocusOS/Services/MemoryGraphService.swift`

**Add Method:**

```swift
func retrieveArchivedRelationships(
    for objectId: UUID,
    modelContext: ModelContext
) -> [MemoryEdge] {
    // Query edges where sourceNodeId or targetNodeId matches
    // Filter to active (non-archived) relationships
    // Return with relationship types
}
```

### 6.5 ARTE Tone Timeline

**File:** `FocusOS/Services/ReactiveThemeManager.swift`

**Add Method:**

```swift
func toneTimeline(
    for objectId: UUID,
    startDate: Date,
    endDate: Date,
    modelContext: ModelContext
) -> [ToneSnapshot] {
    // Query StateTransitionHistory for time range
    // Map to tone snapshots with dates
    // Return color-coded timeline data
}
```

**Data Structure:**

```swift
struct ToneSnapshot {
    let date: Date
    let tone: EmotionalState
    let confidence: Double
    let color: Color // From EmotionalPalette
}
```

---

## Phase 7: Accessibility & Calm Mode

**Accessibility:**

- Large cards (minimum 44pt touch targets)
- High contrast text (use `glassColorSystem` adaptive colors)
- VoiceOver: Reads title + type + summary + archived date in logical order
- Dynamic Type support for text sizes

**Calm Mode:**

- Detect via `UserDefaults.standard.bool(forKey: "calmModeEnabled")`
- Desaturated gradients (reduce saturation by 30%)
- Slower animations (`GlassMotion.emotionalSpeedMultiplier *= 0.7`)
- Disable shimmer effects
- Reduce motion: Disable `floatLift` and shimmer when `UIAccessibility.isReduceMotionEnabled`

**Implementation:**

- Check `UIAccessibility.isReduceMotionEnabled` for animations
- Use `@Environment(\.accessibilityReduceMotion)` if available
- Calm Mode toggle in Settings → Archives preferences

---

## Phase 8: Motion & Feedback

**Animations:**

1. **Hover**

   - `.floatLift()` modifier
   - Scale: `GlassMotion.Transform.hoverScale` (1.015)
   - Shadow: 0.05 → 0.15 opacity, 4pt → 12pt radius

2. **Archive New Item**

   - `.GlassMotion.ripple` effect
   - Color: kosmicPurple.opacity(0.3)
   - Duration: `GlassMotion.Duration.ripple` (0.3s)
   - Triggered when item archived

3. **Restore Item**

   - `.transition(.move(edge: .leading))`
   - Slide animation: `GlassMotion.Easing.spring`
   - Duration: 0.4s
   - Card slides out left, then removed from list

4. **Filter Change**

   - `.opacity` fade: 0.3 → 1.0
   - Duration: `GlassMotion.Duration.tabSwitch` (0.25s)
   - Smooth context switch

5. **Review Summary Open**

   - `.spring(duration: 0.4)` slide-in
   - From bottom (sheet) or trailing (drawer)
   - Backdrop blur fade-in

**Feedback:**

- Haptic feedback on restore/delete actions (if available)
- Visual pulse on successful archive
- Loading states during AI reflection generation

---

## Data Model Updates

### ArchiveReflection Model

**File:** `FocusOS/Models/ArchiveReflection.swift`

```swift
@Model
final class ArchiveReflection {
    @Attribute(.unique) var id: UUID
    var entityId: UUID
    var entityType: String // "Project", "Note", "Artifact", etc.
    var reflectionText: String
    var auroraCommentary: String?
    var generatedAt: Date
    var arteToneSnapshot: String? // EmotionalState.rawValue
    var focusGravityScore: Double?
    var learningThemes: [String] // From Predictive Cognition
}
```

### Model Extensions

Add `archivedAt: Date?` to:

- `FocusOSShared/Project.swift`
- `FocusOSShared/Area.swift`
- `FocusOSShared/Note.swift`
- `FocusOSShared/Artifact.swift`
- `FocusOS/Models/Draft.swift`

**Migration:** Set `archivedAt = updatedAt` for existing archived items on first launch.

---

## Integration Points

| System | Integration Method | Purpose |

|--------|-------------------|---------|

| **CPS / Focus Gravity** | `ProjectFocusGravityService.focusMetrics()` | Rank importance in timeline view |

| **ARTE Emotional Continuity** | `ReactiveThemeManager.toneTimeline()` | Visual tone indicators |

| **Predictive Cognition** | `CognitionPredictor` + `ConceptTracker` | Generate "Top Learning Themes" |

| **Memory Graph Service** | `MemoryGraphService.retrieveArchivedRelationships()` | Display linked items + reflections |

| **Aurora Insights** | `CoreResponseService.shared.generateResponse()` | Generate reflections + auto tags |

---

## Testing Checklist

- [ ] Filter by type and tone accuracy
- [ ] Restore logic reconnects entities correctly
- [ ] ARTE tone graph renders without flicker
- [ ] Predictive Cognition suggestions appear properly
- [ ] Timeline syncs with Focus Gravity data
- [ ] VoiceOver reads card in logical order
- [ ] Calm Mode gradients and motion validated
- [ ] AI reflection generation works offline (Airplane Mode)
- [ ] Archive card hover animations smooth
- [ ] Review Summary charts render correctly
- [ ] Memory Graph relationships display accurately

---

## Design Tokens

| Token | Value |

|-------|-------|

| Corner radius | 12pt |

| Blur | `.ultraThinMaterial` |

| Typography | SF Pro Rounded / Inter |

| Gradient | kosmicBlue → kosmicPurple (tone-adaptive) |

| Shadow | kosmicPurple.opacity(0.15), radius 3 |

| Animation | `GlassMotion.spring` |

| Color Themes | ARTE-adaptive tones (Calm / Creative / Reflective / Fatigued) |

---

## Implementation Order

1. **Phase 6** (Data Services) - Foundation first
2. **Phase 1** (Header) - Visual structure
3. **Phase 2** (Cards) - Core content display
4. **Phase 3** (Drawer) - Detail view
5. **Phase 5** (Sidebar) - Filtering and insights
6. **Phase 4** (Review Sheet) - Analytics view
7. **Phase 7** (Accessibility) - Polish
8. **Phase 8** (Motion) - Final animations

---

## Emotional Identity

Archives V2 is serene finality — it's the breath between cycles. It shouldn't feel "done," it should feel "kept."

> "Everything you complete still speaks."

### To-dos

- [ ] Phase 6: Create data services (ArchiveReflectionService, ArchiveReintegrationService) and extend existing services (FocusGravityService.reintegrate(), MemoryGraphService.retrieveArchivedRelationships(), ReactiveThemeManager.toneTimeline())
- [ ] Create ArchiveReflection SwiftData model and add archivedAt: Date? field to Project, Area, Note, Artifact, Draft models
- [ ] Phase 1: Build ArchivesHeaderView with title, filters, search bar, and quick actions using GlassMotion design
- [ ] Phase 2: Build ArchiveCardV2 component with entity icons, summaries, ARTE tone bars, and action buttons
- [ ] Phase 3: Build ArchiveDetailDrawer with full summary, mood history timeline, reflection notes, Aurora commentary, and related items sidebar
- [ ] Phase 5: Build ArchivesSidebar with filters (type, date, tone, source), insights (completion tone, focus session length, reflection density), and Aurora notes
- [ ] Phase 4: Build ArchiveReviewSheet with weekly completion overview chart, ARTE emotional distribution chart, top learning themes, and Aurora insight card
- [ ] Create UnifiedArchivesView that combines header, cards grid, sidebar, and replaces existing ArchivesView
- [ ] Phase 7: Implement accessibility (VoiceOver, Dynamic Type, high contrast) and Calm Mode (desaturated gradients, slower animations, reduced motion)
- [ ] Phase 8: Implement motion and feedback (hover floatLift, archive ripple, restore slide transitions, filter opacity fades, review sheet spring animations)