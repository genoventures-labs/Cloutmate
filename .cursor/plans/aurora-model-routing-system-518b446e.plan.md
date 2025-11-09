<!-- 518b446e-4c31-4c41-96ce-ff2f5ea9383c 111d200c-8ffe-4de6-bc73-bc525cd1a338 -->
# Aurora Local Model Routing with Thinking Support

## Overview

Switch Aurora's core routing to use local models with intelligent thinking mode. Implement casual conversation detection, thinking support via Ollama API, visual thinking indicators, and model name badges in chat UI.

## Model Routing Strategy

### New Local Models

1. **qwen3:1.7b** - Main model (no thinking for casual, thinking enabled for non-casual)
2. **deepseek-r1:1.5b** - Deep reasoning model (above casual logic)
3. **granite3.2:2b** - Fallback model

### Routing Logic

1. **Casual conversations** → `qwen3:1.7b` (no thinking)
2. **Non-casual logic** → `qwen3:1.7b` WITH thinking enabled
3. **Deep reasoning** → `deepseek-r1:1.5b`
4. **Fallback** → `granite3.2:2b`

## Implementation Details

### 1. Update ModelTierMap

- Replace cloud models with local models
- Add model display names (Qwen3, DeepSeek, Granite3)
- Update routing logic to use local models
- Add thinking capability flag per model

### 2. Casual Conversation Detection

- Detect casual vs non-casual based on:
- Message length (< 50 chars = likely casual)
- Question complexity (simple questions = casual)
- Intent cluster (Empathy/Support = casual)
- User style (high energy, casual punctuation = casual)

### 3. Per-Model Cooldown/Stickiness

- Track model usage per conversation context in ModelRoutingEngine
- When DeepSeek (or any model) handles a reasoning task, tag that context
- Maintain model stickiness for next 2-3 turns after model usage
- Prevents mid-thought model switches (e.g., DeepSeek → Qwen3 mid-reasoning)
- Makes Aurora's "voice" feel steadier during deep dives
- Cooldown expires after 2-3 turns or when topic significantly changes
- Per-model tracking: each model maintains its own cooldown window
- Add `thinking` parameter to OllamaRequest
- Ollama API supports `options.thinking` boolean
- Parse thinking content from response (separate from main response)
- Store thinking content in AIMessage model

### 4. UI Updates

#### Thinking Indicator

- Show thinking animation only when actually thinking
- Add collapsible thinking view in MessageBubble
- Display thinking content in expandable section

#### Model Badge

- Add small pill/tag at bottom of assistant messages
- Show model display name (Qwen3, DeepSeek, Granite3, Gemini)
- Position at bottom of message bubble
- Subtle styling, not intrusive

### 5. AIMessage Model Updates

- Add `thinkingContent: String?` field
- Add `modelUsed: String?` field (store display name)
- Add `wasThinking: Bool` field

### 6. Routing Engine Updates

- Update ModelRoutingEngine to use local models
- Add casual conversation detection
- Route based on complexity and intent

## Files to Create/Modify

### Modified Files

- `Cloutmate/Models/ModelTierMap.swift` - Update with local models
- `Cloutmate/Services/ModelRoutingEngine.swift` - Add casual detection and local routing
- `Cloutmate/Services/OllamaBridgeService.swift` - Add thinking parameter support
- `Cloutmate/Services/HybridBridgeService.swift` - Update to use local models primarily
- `Cloutmate/Models/AIMessage.swift` - Add thinkingContent, modelUsed, wasThinking fields
- `Cloutmate/Views/AIAssistant/Components/MessageBubble.swift` - Add thinking view and model badge
- `Cloutmate/Views/Spotlight/AuroraSpotlightBubble.swift` - Add thinking view and model badge

### New Files

- `Cloutmate/Services/CasualConversationDetector.swift` - Detect casual vs non-casual conversations

## UI Components

### Thinking View

- Collapsible DisclosureGroup
- Show thinking content in monospace font
- Subtle background color
- "Show thinking" / "Hide thinking" toggle

### Model Badge

- Small pill shape at bottom of message
- Display name only (no version numbers)
- Color-coded by model type
- Position: bottom-right of message bubble