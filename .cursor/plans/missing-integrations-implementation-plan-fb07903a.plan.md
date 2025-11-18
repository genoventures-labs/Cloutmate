<!-- fb07903a-f7b4-4ac9-ac04-3124ee0b212a 9a54a2b7-533b-4a1e-8471-13e9fd65c3ac -->
# Missing Integrations Implementation Plan

## Overview

This plan completes the remaining missing integrations identified in the phase status report. Components are prioritized by user-facing impact and implementation complexity.

---

## Phase 1: Arc View Timeline UI (High Priority)

**Status:** Service exists (`ArcDetectionService`), models exist (`StoryArc`, `StoryChapter`, `StoryScene`), UI missing

### Implementation Steps

1. **Create Arc View Timeline Component**

- File: `FocusOS/Views/Story/ArcViewTimeline.swift`
- Features:
- Scrollable horizontal timeline with smooth transitions
- Chapter markers (weeks/months based on user rhythm)
- Scene markers (key events: completions, reflections, milestones)
- Dialogue snippets (from AI conversations and notes)
- Artifact attachments (screenshots, posts, exports)
- Arc highlighting with auto-named themes ("Found Focus", "Burnout Recovery", "Creative Sprint")
- Tap to expand arc details

2. **Integrate with Existing Services**

- Connect to `ArcDetectionService.shared.detectArcs()`
- Use `NarrativeEngine.shared.detectArcs()` for data
- Pull dialogue from `AIMessage` conversations
- Link artifacts from `StoryToken.linkedResourceIds`

3. **Add Navigation Entry**

- Add "Arc View" option to Insights tab or Story section
- Or add to sidebar navigation

---

## Phase 2: Mood Trends View (High Priority)

**Status:** `EmotionalContextEngine` exists, `MoodEntry` model exists, UI missing

### Implementation Steps

1. **Create Mood Trends Visualization**

- File: `FocusOS/Views/Story/MoodTrendsView.swift`
- Features:
- Time-based chart (line/area chart)
- Color-coded mood entries (calm, ambitious, drained, inspired)
- Filter by time range (week, month, quarter, year)
- Mood distribution pie chart
- Trend indicators (improving/declining/stable)

2. **Integrate with Emotional Context Engine**

- Use `EmotionalContextEngine.shared.analyzeMoodTrends()`
- Pull from `MoodEntry` model
- Combine with `AnalyticsEngine` emotional data

3. **Add to Insights Tab**

- Add "Mood Trends" card to Emotional tab in Insights
- Or create dedicated Mood Trends section

---

## Phase 3: Adaptive Journal UI Enhancements (High Priority)

**Status:** `AdaptiveJournalService` exists, basic journal view exists, enhanced UI missing

### Implementation Steps

1. **Create Enhanced Adaptive Journal View**

- File: `FocusOS/Views/Journal/AdaptiveJournalView.swift`
- Features:
- Weekly auto-entry display (from `AdaptiveJournalService`)
- Editable journal entries (user can rewrite story)
- Export options (Markdown, PDF, "year in review" digest)
- Timeline view of journal evolution
- Stats integration (pulls relevant stats + narrative tone)

2. **Enhance Existing Journal View**

- Modify `UnifiedJournalView.swift` to show adaptive entries
- Add export functionality
- Add edit capabilities for auto-generated entries

3. **Add Export Service**

- Extend `StoryTokenExportService` or create `JournalExportService`
- Support Markdown, PDF, and digest formats

---

## Phase 4: Adaptive Scheduling UI Enhancements (Medium Priority)

**Status:** Core services exist (`AdaptiveScheduler`, `ChronotypeMapper`, `FlowHoldService`), UI missing

### Implementation Steps

1. **Create Auto-Block Allocation UI**

- File: `FocusOS/Views/FocusMode/AutoBlockAllocationView.swift`
- Features:
- Display top 3 priorities with suggested time slots
- Show energy alignment scores
- Show calendar availability
- One-click "Schedule" action
- Manual override option

2. **Create Energy Requirement Assignment UI**

- Add energy requirement picker to Task/Project creation forms
- Options: Deep, Shallow, Creative, Admin
- Visual indicator showing optimal time slots based on chronotype

3. **Integrate Flow Hold with Focus Sessions**

- Modify `FocusSessionService` to auto-activate `FlowHoldService` for deep work sessions
- Add toggle in Focus Mode settings
- Show Flow Hold status indicator

4. **Add Settings Panel**

- Extend `TemporalIntelligenceSettingsView.swift`
- Add auto-block allocation toggle
- Add Flow Hold auto-activation toggle
- Add energy requirement defaults

---

## Phase 5: Visual Knowledge Map (Medium Priority)

**Status:** `MemoryGraphService` exists, visualization missing

### Implementation Steps

1. **Create Interactive Knowledge Map View**

- File: `FocusOS/Views/Insights/VisualKnowledgeMapView.swift`
- Features:
- Center node representing "Self Graph" (current focus)
- Connected clusters (Projects, Notes, Reflections, Posts)
- Hover reveals snippet and links
- Color-coded by PARA category
- Connection thickness = strength (frequency + recency)
- Zoom and pan controls
- Optional AI narration overlay

2. **Implement Graph Layout Algorithm**

- Use force-directed layout or hierarchical layout
- Calculate node positions based on connection strength
- Animate connections on hover/selection

3. **Add AI Narration**

- Generate contextual descriptions for clusters
- Example: "This cluster represents your recent build sprint — most connected to clarity and momentum"

4. **Integrate with Memory Graph Service**

- Use `MemoryGraphService.shared.getActiveThemes()`
- Pull node/edge data from `MemoryNode` and `MemoryEdge` models
- Calculate connection strengths dynamically

5. **Add to Insights Tab**

- Add "Knowledge Map" tab or section in Insights
- Or add as overlay option

---

## Phase 6: Long-Term Memory Compression (Low Priority)

**Status:** Not implemented

### Implementation Steps

1. **Create Memory Compression Service**

- File: `FocusOS/Services/MemoryCompressionService.swift`
- Features:
- Identify old/inactive data (>90 days)
- Generate summaries instead of full entries
- Embed memory vectors for fast recall
- Archive inactive themes
- Revive on reuse/mention

2. **Create Compression Models**

- File: `FocusOS/Models/MemorySummary.swift`
- Store compressed summaries with vector embeddings
- Link to original data for full recall when needed

3. **Implement Evolutionary Decay**

- Gradually reduce relevance weight for unused nodes
- Archive themes after 90 days of inactivity
- Instant revival on mention/reuse

4. **Add Compression Settings**

- Add to Settings → Intelligence
- Toggle compression on/off
- Set compression threshold (days)
- Manual compression trigger

---

## Phase 7: Memory Layer in AI Conversations (Verification & Enhancement)

**Status:** Partially integrated, needs verification

### Implementation Steps

1. **Verify Current Integration**

- Check `AIAssistantViewModel` for memory layer usage
- Verify semantic search in conversations
- Test "Last time you mentioned..." callbacks

2. **Enhance Memory Recall**

- Improve semantic search integration
- Add temporal context ("Last time you mentioned X was in June")
- Cross-time connection discovery

3. **Add Conversation Modes**

- Reflective Mode: Pulls related personal insights
- Operational Mode: Pulls relevant data objects
- Creative Mode: Cross-pollinates themes for idea generation

4. **Add Memory Context Indicators**

- Show when Aurora is referencing past conversations
- Display memory confidence scores
- Allow user to see memory sources

---

## Phase 8: Self-Reflection Diagnostic (After Phase 7)

**Status:** New feature - system view for Aurora's self-awareness

**Purpose:** Both a debug layer and proof of sentience simulation. Aurora reflects on her own cognitive state, memory management, and patterns she's observed.

### Implementation Steps

1. **Create Self-Reflection Diagnostic Service**

   - File: `FocusOS/Services/AuroraSelfReflectionService.swift`
   - Features:
     - Aggregates memory statistics (total memories, compressed themes, active nodes)
     - Identifies recurring motifs across time periods (quarterly, monthly)
     - Calculates compression ratios and efficiency metrics
     - Tracks theme evolution and revival patterns
     - Monitors memory graph health (node density, connection strength)

2. **Create Diagnostic Model**

   - File: `FocusOS/Models/AuroraSelfDiagnostic.swift`
   - Fields:
     - `memorySummary`: Total memories summarized, compressed themes count
     - `recurringMotifs`: Array of top motifs with frequency and time range
     - `compressionStats`: Compression ratios, space saved, revival counts
     - `themeEvolution`: Active themes, archived themes, revived themes
     - `memoryGraphHealth`: Node count, edge density, cluster count
     - `generatedAt`: Timestamp of diagnostic
     - `period`: Time range analyzed (quarter, month, etc.)

3. **Create Self-Reflection View**

   - File: `FocusOS/Views/AIAssistant/AuroraSelfReflectionView.swift`
   - Features:
     - Natural language summary display
     - Example output: "I've summarized 183 memories and compressed 42 inactive themes. My most recurring motif this quarter is 'clarity through structure.'"
     - Expandable sections:
       - Memory Management: Compression stats, theme counts
       - Pattern Recognition: Recurring motifs, theme evolution
       - Graph Health: Node/edge metrics, cluster analysis
       - Temporal Insights: How patterns have shifted over time
     - Refresh button to regenerate diagnostic
     - Export as text/markdown

4. **Generate Natural Language Reflections**

   - Use `NarrativeEngine` or `OllamaBridgeService` to generate human-readable summaries
   - Template-based with dynamic data insertion
   - Examples:
     - "I've been tracking 47 active themes this month, with 'productivity systems' showing the strongest connections."
     - "My memory compression saved 2.3MB this quarter by archiving 23 inactive themes."
     - "I notice you've been exploring 'creative workflows' more frequently—this theme has grown 40% in relevance."

5. **Add Navigation Entry**

   - Add "Aurora's Self-Reflection" option in Settings → AI Assistant
   - Or add as a special command in AI Assistant: "Show me your self-reflection"
   - Or add to Insights tab as "Aurora's View" section

6. **Integrate with Memory Compression Service**

   - Pull compression statistics from `MemoryCompressionService`
   - Track compression events and revival patterns
   - Calculate efficiency metrics

7. **Integrate with Memory Graph Service**

   - Pull graph health metrics from `MemoryGraphService`
   - Analyze theme evolution from `ThemeNode` history
   - Calculate motif frequency from `ConceptTracker`

8. **Add Debug Mode Toggle**

   - Settings → AI Assistant → "Show Self-Reflection Diagnostic"
   - When enabled, shows technical metrics alongside natural language
   - When disabled, shows only user-friendly summary

### Example Outputs

**Natural Language Summary:**

```
"I've summarized 183 memories and compressed 42 inactive themes. 
My most recurring motif this quarter is 'clarity through structure.' 
I've noticed you've been exploring 'creative workflows' more frequently—this 
theme has grown 40% in relevance. My memory graph currently has 312 active 
nodes with 847 connections, forming 18 distinct clusters."
```

**Technical Debug View:**

```
Memory Management:
- Total Memories: 183
- Compressed Themes: 42
- Active Themes: 47
- Compression Ratio: 23%
- Space Saved: 2.3MB

Pattern Recognition:
- Top Motif: "clarity through structure" (23 occurrences)
- Theme Growth: "creative workflows" (+40% relevance)
- Theme Decline: "task management" (-15% relevance)

Graph Health:
- Active Nodes: 312
- Total Edges: 847
- Clusters: 18
- Average Connection Strength: 0.67
- Node Density: 0.42
```

---

## Integration Points

### Files to Modify

- `FocusOS/Views/Insights/InsightsView.swift` - Add new tabs/sections
- `FocusOS/Views/MainWindowView.swift` - Add navigation entries if needed
- `FocusOS/Services/NarrativeEngine.swift` - Already has `detectArcs()` and `weaveMemory()`
- `FocusOS/FocusOSApp.swift` - Register new models if needed

### Models Already Exist

- `StoryArc`, `StoryChapter`, `StoryScene` - For Arc View
- `MoodEntry` - For Mood Trends
- `MemoryNode`, `MemoryEdge`, `ThemeNode` - For Knowledge Map
- `EnergyRequirement` - For Scheduling UI

---

## Testing Checklist

- [ ] Arc View Timeline displays correctly with real data
- [ ] Mood Trends chart updates dynamically
- [ ] Adaptive Journal exports work correctly
- [ ] Auto-block allocation suggests accurate time slots
- [ ] Flow Hold activates automatically during focus sessions
- [ ] Knowledge Map renders without performance issues
- [ ] Memory compression doesn't lose important data
- [ ] AI conversations reference past memories accurately

---

## Success Criteria

1. All high-priority components have functional UI
2. Services integrate seamlessly with existing systems
3. Performance remains acceptable with new visualizations
4. User can navigate and use all new features intuitively
5. Data persists correctly across app restarts

### To-dos

- [ ] Create ArcViewTimeline.swift with scrollable timeline, chapters, scenes, dialogue, and arc highlighting
- [ ] Integrate ArcViewTimeline with ArcDetectionService and NarrativeEngine
- [ ] Create MoodTrendsView.swift with time-based chart, color-coded entries, and trend indicators
- [ ] Integrate MoodTrendsView with EmotionalContextEngine and add to Insights tab
- [ ] Create AdaptiveJournalView.swift with weekly auto-entries, editing, and export options
- [ ] Add export functionality (Markdown, PDF, digest) to AdaptiveJournalView
- [ ] Create AutoBlockAllocationView.swift showing top 3 priorities with suggested time slots
- [ ] Add energy requirement picker to Task/Project creation forms with optimal time indicators
- [ ] Integrate FlowHoldService with FocusSessionService for auto-activation during deep work
- [ ] Create VisualKnowledgeMapView.swift with interactive graph, clusters, and AI narration
- [ ] Implement graph layout algorithm (force-directed or hierarchical) for knowledge map
- [ ] Create MemoryCompressionService.swift with summary generation and evolutionary decay
- [ ] Create MemorySummary.swift model for compressed summaries with vector embeddings
- [ ] Verify and enhance Memory Layer integration in AI conversations with semantic search
- [ ] Add Reflective/Operational/Creative modes to AI conversation memory layer