<!-- b06ce7bf-23a1-41a3-a92b-175c7ed6ec46 aa3998f1-df65-46b9-9bd8-80704d6cfe72 -->
# Aurora Quality of Life Improvements

## Overview

Enhance Aurora's internal cognitive environment with tactical improvements that reduce memory pressure, increase self-awareness, enable proactive capabilities, and improve decision confidence. These changes make Aurora's operation more graceful without requiring architectural overhauls.

## Phase 1: Cognitive Load Management (Memory Clarity)

### 1. Intelligent Context Window Governance

**Problem**: Aurora currently takes last 30 messages from conversation history with no compression. Long conversations consume excessive context tokens.

**Solution**: Add adaptive summarization for conversation history.

**Implementation**:

- Create `ConversationCompressionService.swift` to summarize old messages when conversation exceeds threshold
- Modify `GeminiService.analyzeDocument` and image analysis methods to use compressed history
- Add message count threshold (e.g., >40 messages triggers compression of messages 10-30 into summary)
- Compressed summaries preserve emotional tone, key decisions, and action items
- Keep last 10 messages + compressed summary of older messages

**Files**:

- New: `FocusOS/Services/ConversationCompressionService.swift`
- Update: `FocusOS/Services/GeminiService.swift` (lines 575-577 where history is sliced)
- Update: `FocusOS/ViewModels/AIAssistantViewModel.swift` (add compression trigger)

### 2. Ambient Forgetting Rules

**Problem**: Recall index grows indefinitely without decay for stale memories.

**Solution**: Add time-based importance decay and memory pruning.

**Implementation**:

- Add `lastAccessedDate` tracking to RecallIndexEntry (already has `lastViewedAt`)
- Implement decay function: `importance *= exp(-age_in_days / 90)` for unaccessed memories
- Run weekly background task to prune entries with importance < 0.1
- Add "forgotten memory" count to Aurora's diagnostic output

**Files**:

- Update: `FocusOS/Services/AIRecallService.swift` (add decay logic to scoring)
- Update: `FocusOS/Models/RecallIndexEntry.swift` (schema already supports this)

## Phase 2: Self-Awareness & Diagnostics

### 3. Response Confidence Scoring

**Problem**: Aurora doesn't know when she's uncertain. No confidence metadata on responses.

**Solution**: Add confidence scoring based on recall quality, context freshness, and pattern strength.

**Implementation**:

- Create `ConfidenceScorer` struct with scoring logic:
  - Recall confidence: based on top recall snippet score (0.7+ = high, 0.4-0.7 = medium, <0.4 = low)
  - Context freshness: time since last context refresh (<5min = fresh, 5-30min = stale, >30min = very stale)
  - Intent confidence: from existing `IntentClusterSummary.confidence`
- Aurora expresses uncertainty naturally: "I'm pretty confident..." vs "I think..." vs "I'm not totally sure, but..."
- Store confidence score in `AIMessage` model as optional `Double`

**Files**:

- New: `FocusOS/Services/ConfidenceScorer.swift`
- Update: `FocusOS/Models/AIMessage.swift` (add `confidenceScore: Double?`)
- Update: `FocusOS/ViewModels/AIAssistantViewModel.swift` (compute confidence, include in system prompt)
- Update: `FocusOS/Services/GeminiService.swift` (add confidence context to prompts)

### 4. Memory Health Dashboard (Aurora's Self-Introspection)

**Problem**: Aurora has no visibility into her own memory state.

**Solution**: Add memory diagnostics Aurora can reference and surface to user.

**Implementation**:

- Create `CognitiveHealthService` with metrics:
  - Total recall entries count
  - Memory density score (entries per day of use)
  - Stale memory percentage (not accessed in 60+ days)
  - Context window pressure (messages approaching limit)
  - Conceptual coherence (average theme salience from ConceptTracker)
- Aurora can say: "Heads up: my recall index is getting dense (2,400 entries). Want me to summarize some older threads?"
- Add compact health indicator to AIPayloadContext

**Files**:

- New: `FocusOS/Services/CognitiveHealthService.swift`
- Update: `FocusOS/Services/AIRecallService.swift` (add `getCognitiveHealthMetrics()` method)
- Update: `FocusOS/ViewModels/AIAssistantViewModel.swift` (include health in context)

## Phase 3: Capability Enhancement (Initiative & Autonomy)

### 5. Proactive Memory Linking Suggestions

**Problem**: Aurora waits for user to ask. She doesn't suggest connections between memories.

**Solution**: Detect semantic clusters and proactively suggest grouping.

**Implementation**:

- Enhance `ConceptTracker` to detect cross-object clusters
- When 3+ recall entries share concepts but aren't explicitly linked: suggest grouping
- Aurora: "I've noticed you're referencing your workspace architecture in 3 different notes. Want me to link those together?"
- Only suggest once per cluster to avoid spam
- Track `suggestedLinkingClusters` in UserPreferences to avoid repeat suggestions

**Files**:

- Update: `FocusOS/Services/ConceptTracker.swift` (add cluster detection)
- Update: `FocusOS/Services/AIRecallService.swift` (add linking suggestion logic)
- Update: `FocusOS/ViewModels/AIAssistantViewModel.swift` (check for linking opportunities)
- Update: `FocusOS/Models/UserPreferences.swift` (track suggested clusters)

### 6. Weighted Relevance (User Interaction Signals)

**Problem**: Recall scoring uses semantic similarity + time/frequency but doesn't factor actual user behavior (what they clicked, expanded, referenced).

**Solution**: Boost recall importance based on user engagement signals.

**Implementation**:

- Track user interactions: opening tasks/notes from recall, following Aurora's suggestions
- Add `userEngagementBoost` to recall scoring formula: `finalScore = baseScore * (1 + engagementBoost)`
- Engagement boost increases when:
  - User opens an item Aurora suggested (+0.2)
  - User references it in conversation (+0.1)
  - User completes a task Aurora prioritized (+0.3)
- Decay engagement boost over time (half-life: 14 days)

**Files**:

- Update: `FocusOS/Models/RecallIndexEntry.swift` (add `engagementScore` and `lastEngagementDate`)
- Update: `FocusOS/Services/AIRecallService.swift` (update scoring formula)
- Update: `FocusOS/Services/PriorityEngine.swift` (track engagement when items accessed)

### 7. Aurora's Initiative System (Autonomous Suggestions)

**Problem**: Aurora only responds, never initiates.

**Solution**: Allow Aurora to proactively surface insights based on SmartAutomationEngine patterns.

**Implementation**:

- When pattern confidence >0.7 and hasn't been suggested yet: Aurora opens conversation with suggestion
- Example: Next time user opens chat, first message from Aurora: "btw, I've noticed you create 'Weekly standup' tasks every Monday. Want me to automate that?"
- Store `pendingProactiveSuggestions` in conversation metadata
- User can dismiss or accept suggestions
- Limit: max 1 proactive suggestion per day to avoid interruption

**Files**:

- Update: `FocusOS/Services/SmartAutomationEngine.swift` (add `getPendingSuggestions()` method)
- Update: `FocusOS/Models/AIConversation.swift` (add `pendingSuggestion` field)
- Update: `FocusOS/ViewModels/AIAssistantViewModel.swift` (check for pending suggestions on load)
- Update: `FocusOS/Views/AIAssistant/AIAssistantView.swift` (render proactive messages)

## Phase 4: Blindspot Reduction (Environmental Awareness)

### 8. Emotional Weight Tracking

**Problem**: Aurora knows object types but not their emotional significance to the user.

**Solution**: Track user's emotional state when interacting with objects.

**Implementation**:

- When user opens/edits task/note/project: sample emotional tone from recent messages
- Store `userEmotionalContext` on workspace objects (happy, stressed, excited, frustrated)
- Include in recall scoring: boost emotionally significant items by 1.3x
- Aurora: "I know that project felt heavy last time you touched it. Want to break it down differently?"

**Files**:

- Update: `FocusOS/Models/Task.swift`, `Note.swift`, `Project.swift` (add `emotionalContext: String?`)
- Update: `FocusOS/Services/EmotionAnalyzer.swift` (add context sampling method)
- Update: `FocusOS/Services/AIRecallService.swift` (factor emotional weight into scoring)

## Technical Notes

**Context Window Management**: GeminiService currently uses `.suffix(30)` for conversation history. Compression service will intelligently reduce this to preserve context quality while reducing token usage.

**Recall Scoring Formula (Current)**:

```
score = (recency * 0.5) + (frequency * 0.3) + (importance * 0.2)
```

**Enhanced Scoring Formula**:

```
baseScore = (recency * 0.5) + (frequency * 0.3) + (importance * 0.2)
decayedImportance = importance * exp(-age_in_days / 90)
engagementMultiplier = 1 + engagementBoost
emotionalMultiplier = hasEmotionalWeight ? 1.3 : 1.0
finalScore = baseScore * decayedImportance * engagementMultiplier * emotionalMultiplier
```

**SmartAutomationEngine Integration**: Already detects patterns with confidence scores. New initiative system piggybacks on existing pattern detection.

**Memory Models**: RecallIndexEntry already has fields for most enhancements (lastViewedAt, importance, emotion). Minimal schema changes needed.

## Implementation Order

1. Confidence scoring (foundational for self-awareness)
2. Memory health dashboard (visibility into state)
3. Weighted relevance (immediate recall improvement)
4. Context compression (reduces pressure)
5. Ambient forgetting (cleanup)
6. Proactive linking (capability gap)
7. Initiative system (autonomy)
8. Emotional weight (final blindspot fix)

Each feature is independently valuable and doesn't block others.

### To-dos

- [ ] Implement ConfidenceScorer and integrate confidence signals into Aurora's responses
- [ ] Build CognitiveHealthService with memory diagnostics and self-introspection
- [ ] Add user engagement tracking and boost recall scoring based on interaction signals
- [ ] Create ConversationCompressionService for intelligent conversation history summarization
- [ ] Implement time-based importance decay and memory pruning for stale entries
- [ ] Enable Aurora to detect semantic clusters and suggest memory connections
- [ ] Wire SmartAutomationEngine patterns into proactive suggestion system
- [ ] Track and factor emotional significance into recall relevance