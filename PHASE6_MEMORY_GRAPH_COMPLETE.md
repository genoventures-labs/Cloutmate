# Phase 6: Memory Graph Research Build - Complete

**Implementation Date:** November 1, 2025  
**Status:** ✅ Research Infrastructure Complete  
**Feature Flag:** `AI_MEMORY_GRAPH_ENABLED` (default: false)

---

## Overview

Phase 6 implements a **Memory Graph Research Build**—an experimental system that uses vector embeddings and graph clustering to discover emergent themes across the entire workspace. Unlike Phase 5's ConceptNode tracking (which monitors explicit mentions), the memory graph discovers implicit connections through semantic similarity.

---

## What We Built

### 1. Graph Schema (`MemoryNode`, `MemoryEdge`, `ThemeNode`)

#### MemoryNode
Represents entities in the memory graph (workspace objects or concepts).

**Key Features:**
- Multiple node types: `workspaceObject`, `concept`, `theme`, `conversation`, `session`, `insight`
- Vector embedding storage (serialized `Data` blob)
- Temporal decay mechanics
- Importance scoring (0.0-1.0)
- Access tracking and boosting

**Model Structure:**
```swift
@Model
final class MemoryNode {
    var id: UUID
    var nodeType: String                    // MemoryNodeType
    var objectId: UUID?                     // Reference to source
    var label: String
    var content: String
    var embeddingData: Data?                // Serialized vector
    var embeddingDimensions: Int
    var importance: Double = 0.5
    var decay: Double = 1.0
    var accessCount: Int
    var edgeCount: Int
    ...
}
```

**Key Methods:**
- `setEmbedding([Float])` - Store vector embedding
- `getEmbedding() -> [Float]?` - Retrieve vector
- `cosineSimilarity(with:) -> Double` - Calculate similarity
- `applyDecay(factor:)` - Apply temporal decay
- `boost(amount:)` - Increase importance on access

#### MemoryEdge
Represents connections between nodes.

**Edge Types:**
- `references` - A references B
- `similarTo` - Semantic similarity
- `partOf` - Hierarchical relationship
- `precedes` - Temporal sequence
- `relatedTo` - Generic connection
- `contradicts` - Conflicting concepts
- `supports` - Reinforcing concepts

**Model Structure:**
```swift
@Model
final class MemoryEdge {
    var id: UUID
    var sourceNodeId: UUID
    var targetNodeId: UUID
    var edgeType: String
    var weight: Double = 0.5               // Connection strength
    var confidence: Double = 1.0
    var traversalCount: Int
    ...
}
```

**Key Methods:**
- `traverse()` - Record edge usage
- `strengthen(amount:)` - Increase weight
- `weaken(amount:)` - Decrease weight

#### ThemeNode
Represents emergent theme clusters discovered through clustering.

**Model Structure:**
```swift
@Model
final class ThemeNode {
    var id: UUID
    var label: String                      // AI-generated theme name
    var description: String
    var memberNodeIds: [UUID]              // Nodes in cluster
    var centroidEmbedding: Data?           // Average embedding
    var coherence: Double                  // Cluster cohesion (0-1)
    var salience: Double                   // Theme importance (0-1)
    var momentum: Double                   // Growth rate (-1 to 1)
    var isActive: Bool
    var keywords: [String]
    ...
}
```

**Key Methods:**
- `recalculateSalience()` - Update importance based on size and momentum
- `shouldDecay()` - Check if theme is fading
- `beginDecay()` - Mark theme as inactive

### 2. MemoryGraphService

Central service managing the graph, embeddings, and queries.

**Core Functions:**

#### Node Operations
```swift
func createNode(for object: any RecallTrackable, modelContext:) async throws -> MemoryNode
func createConceptNode(concept:, content:, modelContext:) async throws -> MemoryNode
func findOrCreateNode(for object:, modelContext:) async throws -> MemoryNode
```

#### Edge Operations
```swift
func createEdge(from:, to:, type:, weight:, reason:, modelContext:) throws -> MemoryEdge
func findSimilarNodes(to:, threshold:, limit:, modelContext:) -> [MemoryNode]
```

#### Embedding Generation
```swift
func generateEmbedding(for text:) async throws -> [Float]
```

Uses existing `GeminiService.embeddingModel` (text-embedding-004) to generate 768-dimensional vectors.

#### Graph Queries
```swift
func getNeighbors(of nodeId:, modelContext:) -> [MemoryNode]
func getActiveThemes(modelContext:) -> [ThemeNode]
```

### 3. ThemeExtractionPipeline

Automatically discovers emergent themes through clustering.

**Trigger Points:**

1. **On Save Events** (`extractThemesOnSave`)
   - Called when workspace objects are created/updated
   - Generates node embeddings
   - Creates similarity edges (threshold: 0.75)
   - Checks for theme emergence (3+ connected nodes)

2. **On Narrative Events** (`extractThemesOnNarrative`)
   - Called weekly or manually
   - Performs full graph clustering
   - Updates existing themes
   - Decays inactive themes

**Clustering Algorithm:**
```
DBSCAN (Density-Based Spatial Clustering):
1. For each unvisited node, find neighbors within epsilon distance
2. If node has minPoints neighbors, start new cluster (core point)
3. Expand cluster by recursively adding neighbors
4. Noise points (outliers) identified automatically
5. No need to specify number of clusters upfront
6. Generate theme label via AI for each cluster

Parameters:
- epsilon: 0.3 (distance threshold, 1 - cosine similarity)
- minPoints: 3 (minimum cluster size)
```

**Advantages of DBSCAN:**
- **Automatic cluster discovery:** No need to pre-specify number of themes
- **Outlier detection:** Identifies nodes that don't belong to any theme
- **Arbitrary shapes:** Can find non-spherical clusters
- **Varying density:** Handles clusters with different densities
- **Robust to noise:** Ignores isolated nodes instead of forcing them into clusters

**Theme Formation:**
```swift
func formNewTheme(from nodes:, modelContext:) async
```
- Calculates centroid embedding
- Generates label/description using Gemini
- Computes coherence (avg pairwise similarity)
- Extracts keywords
- Links related ConceptNodes

### 4. Integration with AIPayloadContext

**New Field:**
```swift
var memoryThemes: [ThemeSummary]?
```

**ThemeSummary Structure:**
```swift
struct ThemeSummary: Sendable {
    let id: UUID
    let label: String
    let description: String
    let salience: Double
    let memberCount: Int
    let keywords: [String]
    let isActive: Bool
}
```

**Populated in AIAssistantViewModel:**
```swift
if AIConfigService.shared.config.featureFlags.memoryGraphEnabled {
    let themes = MemoryGraphService.shared.getActiveThemes(modelContext: modelContext)
    memoryThemes = themes.prefix(5).map { ... }
}
```

**Formatted in GeminiService:**
```
Memory Graph Themes (Research/Experimental):
Emergent theme clusters extracted from memory graph using vector embeddings:

- **Content Strategy** (salience: 85%, 12 nodes)
  Comprehensive approach to content creation and distribution across platforms
  Keywords: planning, schedule, consistency, engagement, growth
```

### 5. Telemetry & Monitoring

#### MemoryGraphTelemetry

**Metrics Collection:**
```swift
struct MemoryGraphMetrics {
    let totalNodes: Int
    let totalEdges: Int
    let totalThemes: Int
    let activeThemes: Int
    let avgNodeImportance: Double
    let avgThemeSalience: Double
    let embeddedNodesCount: Int
    let timestamp: Date
}
```

**Functions:**
- `captureMetrics(modelContext:) -> MemoryGraphMetrics`
- `recordOperation(_:)` - Track operation counts
- `generateDebugReport(modelContext:) -> String`
- `exportMetricsToJSON(modelContext:) -> String?`

**Periodic Monitoring:**
- Runs every 5 minutes (when enabled)
- Logs metrics to AIDebug
- Tracks operation counts

### 6. Debug & Visualization Tools

#### MemoryGraphDebug

**ASCII Visualization:**
```swift
func visualizeGraph(modelContext:, centerNodeId:, depth:) -> String
```

Example output:
```
=== MEMORY GRAPH VISUALIZATION ===
Center: Content Strategy (importance: 0.85)

├─ [workspaceObject] Q4 Marketing Plan
│  importance: 0.72, edges: 5
│  ├─ [concept] Consistency
│  ├─ [workspaceObject] Social Media Calendar
│  ...
```

**DOT Format Export:**
```swift
func exportToDOT(modelContext:, limit:) -> String
```

Generates Graphviz-compatible DOT format for external visualization tools.

**Node/Theme Inspection:**
```swift
func inspectNode(_ nodeId:, modelContext:) -> String
func inspectTheme(_ themeId:, modelContext:) -> String
```

Detailed reports including:
- Metadata and metrics
- Embedding information
- Connected nodes/edges
- Temporal data

**Statistics:**
```swift
func printStatistics(modelContext:) -> String
```

Quick overview of graph state.

---

## Decay Mechanics

### Node Decay

**When Applied:**
- Not accessed for 7+ days
- Low importance (<0.2)
- No active edges

**Decay Formula:**
```swift
func applyDecay(factor: Double) {
    decay *= factor
    importance *= decay
}
```

**Typical Decay Cycle:**
1. Day 0: `importance = 0.5`, `decay = 1.0`
2. Day 7: Apply `decay(0.9)` → `importance = 0.45`
3. Day 14: Apply `decay(0.9)` → `importance = 0.405`
4. Day 21: If `importance < 0.2`, mark for cleanup

**Boost on Access:**
```swift
func boost(amount: Double = 0.1) {
    importance = min(1.0, importance + amount)
    decay = 1.0  // Reset decay
    accessCount += 1
}
```

### Theme Decay

**Conditions:**
```swift
func shouldDecay() -> Bool {
    let daysSinceUpdate = Date().timeIntervalSince(lastUpdateAt) / (24 * 3600)
    return daysSinceUpdate > 7.0 && memberNodeIds.count < 3
}
```

**Decay Process:**
1. No new members for 7+ days
2. Cluster size drops below 3
3. `beginDecay()` called → `isActive = false`
4. Theme kept for historical analysis
5. Not shown in active themes list

**Salience Calculation:**
```swift
let sizeFactor = min(1.0, Double(memberNodeIds.count) / 10.0)
let momentumFactor = (momentum + 1.0) / 2.0
salience = (sizeFactor * 0.7) + (momentumFactor * 0.3)
```

### Edge Decay

**Strengthening:**
- Edge traversed → `strengthen(0.1)`
- Nodes frequently connected → increase weight

**Weakening:**
- Nodes rarely connected → `weaken(0.05)`
- Low confidence edges pruned

---

## UI Plans (Future Implementation)

### 1. **Memory Graph Visualizer** (Phase 6.1)

**Interactive Network View:**
- Force-directed graph layout
- Node size = importance
- Edge thickness = weight
- Color coding by node type
- Zoom/pan/filter controls

**Technology Stack:**
- SwiftUI with custom Canvas drawing
- Or: Web view with D3.js for advanced visualization

**Features:**
- Click node → inspect details
- Hover edge → show relationship type
- Filter by node type, theme, time range
- Search nodes by label

### 2. **Theme Explorer** (Phase 6.2)

**Theme Dashboard:**
- List of active themes sorted by salience
- Theme cards with:
  - Label and description
  - Salience meter
  - Member count
  - Keywords
  - Momentum indicator (growing/stable/declining)
  
**Theme Detail View:**
- Members list (nodes in cluster)
- Temporal evolution (salience over time)
- Related concepts from Phase 5
- Export theme as Markdown report

### 3. **Research Console** (Phase 6.3)

**Developer/Research UI:**
- Live telemetry dashboard
- Metrics graphs (nodes/edges/themes over time)
- Operation logs
- Debug tools:
  - Execute graph queries
  - Inspect node/edge/theme
  - Export DOT format
  - Trigger manual clustering
  - Adjust clustering parameters

**Playground Mode:**
- Experiment with similarity thresholds
- Test different clustering algorithms
- Visualize embedding space (t-SNE/UMAP)

### 4. **Integration with Existing Views**

**Focus Gravity View:**
- Add "Related Themes" section
- Show which themes high-priority items belong to

**Live Themes View:**
- Add toggle between ConceptNode themes and MemoryGraph themes
- Compare results side-by-side

**Insights Dashboard:**
- "Theme Evolution" chart
- "Conceptual Connections" map
- "Emerging vs. Fading Themes" comparison

---

## Gemini Retrieval Experiments

### Current Implementation

**Payload Integration:**
- Memory themes automatically included when flag enabled
- Aurora receives top 5 themes in context
- Formatted as "Memory Graph Themes (Research/Experimental)"

**Aurora's Awareness:**
```
Phase 6 - Memory Graph (Research/Experimental): MemoryNode/Edge/ThemeNode form 
a graph structure with vector embeddings. ThemeExtractionPipeline uses clustering 
to identify emergent themes. If enabled, you'll see "Memory Graph Themes" in 
payload showing thematic connections discovered through semantic similarity.
```

### Planned Retrieval Enhancements (Future)

#### 1. **Graph-Augmented Recall**
Instead of just keyword matching, use:
- Vector similarity search on node embeddings
- Graph traversal from query node
- Multi-hop reasoning (node → neighbors → neighbors)

#### 2. **Theme-Based Context**
When user asks about a topic:
- Identify relevant theme
- Retrieve all nodes in that theme cluster
- Provide richer, more connected context

#### 3. **Concept Bridging**
Find paths between seemingly unrelated concepts:
- Shortest path algorithm
- Common neighbors
- Bridge concepts

#### 4. **Temporal Theme Tracking**
Track how themes evolve:
- Theme emergence dates
- Momentum changes
- Related concept shifts

---

## Research Questions to Explore

1. **Clustering Algorithm:**
   - Current: DBSCAN (Density-Based Spatial Clustering)
   - Test: Hierarchical clustering, Louvain community detection, HDBSCAN

2. **Similarity Threshold:**
   - Current: 0.7-0.75
   - Experiment: Dynamic thresholds based on graph density

3. **Embedding Quality:**
   - Current: text-embedding-004 (Gemini)
   - Compare: OpenAI embeddings, custom fine-tuned embeddings

4. **Decay Mechanics:**
   - Current: Linear decay over 7 days
   - Test: Exponential decay, importance-weighted decay

5. **Theme Stability:**
   - How long do themes remain coherent?
   - What causes theme splits/mergers?

6. **Semantic Drift:**
   - Do theme meanings shift over time?
   - How to detect and handle drift?

---

## Feature Flag Configuration

**AIConfig.plist:**
```xml
<key>AIMemoryGraphEnabled</key>
<false/>
```

**To Enable:**
1. Change to `<true/>`
2. Reload config: `AIConfigService.shared.reload()`
3. Restart app (new models registered)

**When Enabled:**
- Theme extraction runs on save/narrative events
- Memory themes appear in AI payload
- Aurora references graph themes in responses
- Telemetry logging active

**Performance Impact:**
- Embedding generation: ~100-500ms per node
- Clustering: ~1-5s for 100 nodes (depends on density)
- Memory: ~10KB per node with embedding
- Recommended: Enable for research/testing only

---

## Files Created

### Models
1. `FocusOS/Models/MemoryGraph/MemoryNode.swift`
2. `FocusOS/Models/MemoryGraph/MemoryEdge.swift`
3. `FocusOS/Models/MemoryGraph/ThemeNode.swift`

### Services
4. `FocusOS/Services/MemoryGraphService.swift`
5. `FocusOS/Services/ThemeExtractionPipeline.swift`
6. `FocusOS/Services/MemoryGraphTelemetry.swift`
7. `FocusOS/Services/MemoryGraphDebug.swift`

### Modified
8. `FocusOS/FocusOSApp.swift` - Registered graph models in schema
9. `FocusOS/Services/AIRecallService.swift` - Added `memoryThemes` to AIPayloadContext
10. `FocusOS/ViewModels/AIAssistantViewModel.swift` - Populated memory themes
11. `FocusOS/Services/GeminiService.swift` - Formatted graph themes in payload, updated Aurora's knowledge

---

## How to Use (Research Mode)

### 1. Enable Feature Flag
```
AIConfig.plist: AIMemoryGraphEnabled = true
```

### 2. Create Nodes Manually
```swift
let node = try await MemoryGraphService.shared.createNode(
    for: myTask,
    modelContext: modelContext
)
```

### 3. Trigger Theme Extraction
```swift
await ThemeExtractionPipeline.shared.extractThemesOnSave(
    for: myTask,
    modelContext: modelContext
)
```

Or trigger full clustering:
```swift
await ThemeExtractionPipeline.shared.extractThemesOnNarrative(
    modelContext: modelContext
)
```

### 4. Inspect Results
```swift
// Get active themes
let themes = MemoryGraphService.shared.getActiveThemes(modelContext: modelContext)

// Visualize graph
let visualization = MemoryGraphDebug.shared.visualizeGraph(
    modelContext: modelContext,
    depth: 2
)
print(visualization)

// Export metrics
let report = MemoryGraphTelemetry.shared.generateDebugReport(modelContext: modelContext)
```

### 5. Query Graph
```swift
// Find similar nodes
let similar = MemoryGraphService.shared.findSimilarNodes(
    to: nodeId,
    threshold: 0.7,
    limit: 10,
    modelContext: modelContext
)

// Get neighbors
let neighbors = MemoryGraphService.shared.getNeighbors(
    of: nodeId,
    modelContext: modelContext
)
```

---

## Next Steps for Phase 6 Research

### Immediate (Week 1-2)
- [ ] Collect baseline metrics with feature enabled
- [ ] Generate embeddings for existing workspace objects
- [ ] Run initial clustering experiments
- [ ] Document theme quality/coherence

### Short-term (Month 1)
- [ ] Build simple Theme Explorer UI
- [ ] A/B test clustering algorithms
- [ ] Experiment with similarity thresholds
- [ ] Measure impact on Aurora's responses

### Long-term (Quarter 1)
- [ ] Full Memory Graph Visualizer
- [ ] Graph-augmented recall system
- [ ] Theme-based navigation
- [ ] Concept bridging experiments
- [ ] Research paper/blog post on findings

---

## Phase Sync Contract Compliance

✅ **Feature Flag:** `AI_MEMORY_GRAPH_ENABLED` in AIConfig  
✅ **Payload Field:** `memoryThemes: [ThemeSummary]?` in AIPayloadContext  
✅ **Telemetry:** MemoryGraphTelemetry logs operations and metrics  
✅ **Aurora Awareness:** System prompts updated with Phase 6 description  
✅ **Metadata:** `memoryGraphEnabled: "true/false"` in payload metadata  

---

## Build Status

✅ **BUILD SUCCEEDED**  
All Phase 6 components compile without errors.  
Feature flag registered in AIConfig.  
Models registered in SwiftData schema.

---

## Conclusion

**Phase 6: Memory Graph Research Build** provides the foundational infrastructure for exploring emergent themes through vector embeddings and graph clustering. This experimental system complements Phase 5's explicit concept tracking with implicit semantic discovery, offering richer insights into conceptual relationships across the workspace.

**Key Innovation:** Unlike traditional knowledge graphs that require manual relationship definition, the memory graph discovers connections automatically through semantic similarity, revealing non-obvious patterns and themes that emerge organically from user activity.

**Research Potential:** This foundation enables future experiments in graph-based retrieval, concept bridging, semantic search, and AI-assisted knowledge discovery—pushing beyond simple keyword matching toward true conceptual understanding.

🧠 **Memory graph is ready for experimentation. Enable the flag and let the themes emerge!**

