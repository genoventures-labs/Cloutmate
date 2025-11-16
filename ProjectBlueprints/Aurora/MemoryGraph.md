# Memory Graph Reference

Aurora's Memory Graph (Phase 6) is a semantic layer that clusters everything the user does—tasks, notes, reflections, focus sessions, conversations—into emergent themes. It powers reflections, predictive cognition, and Flow Companion intelligence.

---

## 1. Data Structures

| Model | Description |
| --- | --- |
| `MemoryNode` | Represents a single memory item (task, note, artifact, concept, conversation summary). Stores embeddings, importance, emotional tone/intensity, recency metadata. |
| `MemoryEdge` | Encodes relationships between nodes (shared tags, conversation mentions, co-occurrence). Tracks weight and context. |
| `ThemeNode` | DBSCAN-derived clusters with salience, keywords, descriptions. |
| `MemorySubgraph` | (See `MemoryGraphService`) persists stable clusters with centroids for predictive queries. |
| `ThemeSummary` / `ThemeNodeDTO` | Lightweight structs passed into `AIPayloadContext` for prompt consumption.

Embeddings are currently synthetic (768d) via `MemoryGraphService.generateSyntheticEmbedding` until Ollama exposes an embedding API, but model names are recorded for future transitions.

---

## 2. Services

| File | Role |
| --- | --- |
| `MemoryGraphService.swift` | CRUD for nodes/edges, caches embeddings, exposes query APIs, triggers hooks. |
| `ThemeExtractionPipeline.swift` | Runs DBSCAN clustering, merges outliers, names clusters. |
| `MemoryConsolidationService.swift` | Periodically consolidates nodes, merges duplicates, prunes stale data. |
| `MemoryCompressionService.swift` | Summarizes heavy nodes to keep storage bounded. |
| `MemoryWeavingService.swift` | Reinforces nodes when referenced in conversations or actions. |
| `MemoryGraphTelemetry.swift` | Captures density, cluster count, embedding health for Insights.

---

## 3. Creation Flow

1. **Event occurs** (task created, reflection logged, concept tracked, doc analyzed).
2. `MemoryGraphService.createNode(for:object)` builds narrative content, analyzes tone via `EmotionAnalyzer`, generates embeddings, and persists the node.
3. **Edges** are created based on shared tags, project IDs, references, or manual linking.
4. **Importance** recalculations consider recency, frequency, CPS ranking, emotional intensity.
5. **Hooks** notify downstream services (PredictiveContextManager, NarrativeEngine, AnalyticsEngine) to refresh cached data.

---

## 4. Consumption

- **Insights → Memory Graph** renders nodes + edges interactively, using `MemoryGraphDebug` + `MemoryGraphTelemetry` outputs for layout.
- **AI Reflection** requests include `memoryThemes` so Aurora can cite salience scores, descriptions, and member counts.
- **PredictiveContextManager** asks for `PredictiveMemorySignal` to align future focus recommendations with dominant themes.
- **NarrativeEngine** blends Memory Graph data with Live Themes from `ConceptTracker` to describe weekly stories.
- **Flow Companion** leverages theme shifts when suggesting prompts (e.g., "You’ve been oscillating between momentum vs. reflection themes").

---

## 5. Feature Flags & Config

- `AIConfig.plist` → `AIMemoryGraphEnabled` must be `true` (see `MEMORY_GRAPH_ENABLED.md`).
- `MemoryGraphService` caches snapshots for five minutes to avoid hammering SwiftData; call `refreshCaches()` (debug-only) if you need immediate updates.
- `ThemeExtractionPipeline` uses DBSCAN defaults tuned for Cloutmate data density. Adjust `minPoints`/`epsilon` carefully if you change data granularity.

---

## 6. Extending the Graph

1. **New node types** – make the model conform to `RecallTrackable`, provide `recallObjectType`, `recallTitle`, `recallSummary` so the service can ingest it.
2. **Custom relationships** – add heuristics in `createNode` or dedicated functions to link nodes when new contexts exist (e.g., linking focus sessions to ritual completions).
3. **Predictive hooks** – register event handlers (`nodeCreatedHooks`, `nodeReinforcedHooks`, etc.) to alert new services.
4. **Visualization** – extend `Insights` views or add GraphQL/JSON exports using `MemoryGraphService.exportGraph()` (if implemented) for external tools.

---

## 7. Troubleshooting Checklist

| Issue | Action |
| --- | --- |
| Aurora says Memory Graph is disabled | Confirm `AIConfig.plist` flag and that `MemoryGraphService` is initialized before AI reflections (see `MEMORY_GRAPH_ENABLED.md`). |
| UI shows empty graph | Make sure enough data exists (DBSCAN needs >3 nodes). Run background operations to populate nodes (tasks, reflections). |
| Stale themes in reflections | Clear caches (restart app) or shrink `cacheValidity` temporarily. |
| Performance | Monitor `MemoryGraphTelemetry` logs; reduce embedding count or extraction frequency if the dataset explodes.

The Memory Graph is Aurora’s long-term intelligence backbone—keep it healthy and she can reference nuanced patterns in every reflection.
