<!-- 518b446e-4c31-4c41-96ce-ff2f5ea9383c 51f8b195-b52f-465a-9f67-dd412c519b00 -->
# Aurora Model Routing Logic Implementation

## Overview

Implement a hybrid cognition stack that routes Aurora's requests through a unified `HybridBridgeService`, dynamically selecting between cloud models (deepseek-v3.1:671b-cloud, gpt-oss:20b-cloud, etc.) and local Ollama based on intent clusters, confidence scores, and performance history.

## Architecture

### Core Components

1. **HybridBridgeService** (`Cloutmate/Services/HybridBridgeService.swift`)

- Unified relay managing both local (Ollama) and cloud routing
- Integrates with existing `CoreResponseService` as the primary routing layer
- Handles model selection, fallback, and performance tracking

2. **ModelTierMap** (`Cloutmate/Models/ModelTierMap.swift`)

- Defines cloud model tiers and their capabilities
- Maps intent clusters to preferred model routes
- Configuration for API endpoints and model identifiers

3. **CloudModelAdapter** (`Cloutmate/Services/CloudModelAdapter.swift`)

- Abstract protocol for cloud model API communication
- Handles request/response transformation
- Manages API authentication and error handling

4. **PerformanceMemory** (`Cloutmate/Models/PerformanceMemory.swift`)

- Tracks model performance per task type and intent cluster
- Stores success rates, latency, and quality metrics
- Informs routing decisions based on historical performance

5. **ModelRoutingEngine** (`Cloutmate/Services/ModelRoutingEngine.swift`)

- Implements confidence-weighted routing logic
- Handles escalation (confidence < 0.6 → higher tier)
- Manages timeout-based fallback (2 timeouts → escalate)
- Applies performance memory insights

### Integration Points

- **CoreResponseService**: Replace direct `OllamaBridgeService` calls with `HybridBridgeService` routing
- **ConversationArchive.extractIntentClusters**: Already provides intent cluster data via `AIPayloadContext`
- **FallbackRoutingService**: Extend to work with cloud models, not just document analysis
- **AISettings**: Add cloud model configuration (API keys, endpoints, enabled models)

## Implementation Details

### 1. Model Tier Mapping

Define cloud models with their capabilities:

- `deepseek-v3.1:671b-cloud` → analytical + reasoning (Reflection, Execution)
- `gpt-oss:20b-cloud` → lightweight general chat (Execution, quick responses)
- `gpt-oss:120b-cloud` → orchestration, emotional tone (Orchestration)
- `kimi-k2:1t-cloud` → creative, summarization (Creative)
- `qwen3-coder:480b-cloud` → code generation (Coding tasks)
- `glm-4.6:cloud` → structured reasoning, math (Reflection)
- `minimax-m2:cloud` → fallback conversational (lightweight chats, rituals)

### 2. Intent Cluster → Model Routing

Dynamic mapping based on `IntentClusterSummary`:

- **Creative** → `kimi-k2:1t-cloud`
- **Execution** → `deepseek-v3.1:671b-cloud` or `gpt-oss:20b-cloud` (based on complexity)
- **Reflection** → `deepseek-v3.1:671b-cloud`
- **Orchestration** → `gpt-oss:120b-cloud`
- **Coding** → `qwen3-coder:480b-cloud`
- **Empathy/Support** → Default to `gpt-oss:20b-cloud` or Ollama

### 3. Confidence-Weighted Routing

- Confidence < 0.6: Promote to next higher tier
- Latency threshold (default 6s): If response takes longer than threshold, proactively escalate to higher tier before timeout (keeps Aurora "snappy")
- 2 consecutive timeouts: Auto-escalate to more capable tier
- Confidence > 0.85: Consider dropping to faster model (resource optimization)
- All routing decisions logged to PerformanceMemory

### 3a. Intent Cluster Model Caching

- Cache last-used model per intent cluster in memory (e.g., `[IntentCluster: String]` dictionary)
- When switching between tasks (e.g., Reflection → Execution → Reflection), reuse cached model for same cluster
- Avoids unnecessary model reinitialization and reduces latency
- Cache cleared on app restart or when model availability changes

### 4. Fallback Chain

1. Try cloud model based on intent cluster
2. On timeout/failure: Escalate to higher tier OR fallback to Ollama
3. If Ollama unavailable: Use Apple LLM (if available) or offline template
4. Network unavailable: Force Ollama (local-first)

### 5. Performance Memory

Track per intent cluster + model combination:

- Success rate
- Average latency
- Response quality (user feedback if available)
- Timeout frequency

Use this data to refine routing decisions over time.

## Files to Create/Modify

### New Files

- `Cloutmate/Services/HybridBridgeService.swift` - Main routing service
- `Cloutmate/Models/ModelTierMap.swift` - Model tier definitions
- `Cloutmate/Services/CloudModelAdapter.swift` - Cloud API abstraction
- `Cloutmate/Models/PerformanceMemory.swift` - Performance tracking
- `Cloutmate/Services/ModelRoutingEngine.swift` - Routing logic engine

### Modified Files

- `Cloutmate/Services/CoreResponseService.swift` - Route through HybridBridgeService
- `Cloutmate/Models/AISettings.swift` - Add cloud model configuration
- `Cloutmate/Services/FallbackRoutingService.swift` - Extend for cloud models
- `Cloutmate/Services/OllamaBridgeService.swift` - Keep as local-only fallback

## Configuration

Add to `AISettings`:

- `useHybridBridge: Bool` - Feature flag to toggle hybrid vs local-only (default: true)
- `ollamaCloudAPIKey: String?` - API key for Ollama Cloud authentication (optional, prompts user if needed)
- `preferredCloudModel: String?` - User-selected preferred cloud model (acts as default/fallback, but dynamic routing still applies)
- When `useHybridBridge` is false: Always use local Ollama (existing behavior)
- When `useHybridBridge` is true: Use hybrid routing with automatic fallback to local

### Settings UI Updates

Update `AIAssistantSection.swift` to include:

- Toggle for `useHybridBridge` feature flag
- Text field for `ollamaCloudAPIKey` (secure entry, masked)
- Picker for `preferredCloudModel` showing all available cloud models:
- `deepseek-v3.1:671b-cloud`
- `gpt-oss:20b-cloud`
- `gpt-oss:120b-cloud`
- `kimi-k2:1t-cloud`
- `qwen3-coder:480b-cloud`
- `glm-4.6:cloud`
- `minimax-m2:cloud`
- "Auto (Intent-Based)" option (default, uses dynamic routing)
- Help text explaining that preferred model acts as default, but system routes dynamically based on intent clusters

## Testing Considerations

- Test routing decisions with various intent clusters
- Verify fallback chain works correctly (cloud → local Ollama → Apple LLM → offline)
- Test performance memory persistence (SwiftData storage/retrieval)
- Ensure Ollama fallback works when cloud unavailable or API key missing
- Test airplane mode (force local-only)
- Test feature flag toggle (hybrid ON/OFF)
- Verify unified API handler works for both local and cloud endpoints

## Migration Path

1. Implement HybridBridgeService alongside existing OllamaBridgeService (no breaking changes)
2. Add `useHybridBridge` feature flag in AISettings (default: true)
3. Modify CoreResponseService to check feature flag and route accordingly
4. When flag ON: Use HybridBridgeService (with cloud fallback to local)
5. When flag OFF: Use OllamaBridgeService directly (existing behavior)
6. Monitor performance and adjust routing logic based on PerformanceMemory data
7. Default to hybrid ON ensures users get cloud benefits while maintaining local fallback