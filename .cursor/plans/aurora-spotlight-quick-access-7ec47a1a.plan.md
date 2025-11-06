<!-- 7ec47a1a-b3f9-4982-a122-1a0904969b65 8584a962-7f59-41f9-9f73-86afaa70ebd2 -->
# Aurora Humanization Implementation Plan

## Goal
Make Aurora feel as humanly as possible through natural typing patterns, emotional expression, conversational quirks, memory behaviors, and proactive interactions.

## Implementation Strategy
We'll implement features one at a time, starting with quick wins and progressing to advanced behaviors.

---

## Phase 1: Quick Wins (Foundation)

### 1. Typing Simulation Engine
**File:** `Cloutmate/Services/TypingSimulationService.swift`
- Variable typing speed based on response complexity
- Word-by-word or chunk-by-chunk message streaming
- Simulated pauses mid-sentence ("thinking pauses")
- Backspace simulation for corrections

**UI Changes:**
- `AIAssistantView.swift` - Show typing indicator with variable speed
- `MessageBubble.swift` - Stream text appearance instead of instant display

### 2. Natural Response Timing
**File:** `Cloutmate/Services/ResponseTimingService.swift`
- Context-aware delays (longer for complex tasks, instant for acknowledgments)
- Processing time estimation based on message complexity
- Adaptive thinking indicators based on actual processing time

**Integration:**
- `AIAssistantViewModel.swift` - Integrate timing logic
- `ThinkingIndicator.swift` - Show appropriate duration

### 3. Contractions & Casual Language
**File:** `Cloutmate/Services/LanguagePersonalityService.swift`
- Natural contraction usage ("I'm", "you're", "can't", "won't")
- Casual language matching user's formality level
- Punctuation personality (varied ellipses, parentheses, exclamation marks)

**Integration:**
- `GeminiService.swift` - Update system prompts for natural language
- `StyleAdapter.swift` - Enhance style adaptation

### 4. Typography Emotion
**File:** `Cloutmate/Services/TypographyEmotionService.swift`
- Subtle emphasis variations (italics, bold for emphasis)
- Punctuation patterns that convey emotion
- Capitalization for excitement (sparingly)

**UI Changes:**
- `MessageBubble.swift` - Apply typography styling based on emotion

---

## Phase 2: Medium Complexity (Personality)

### 5. Verbal Fillers & Self-Corrections
**File:** `Cloutmate/Services/ConversationalQuirksService.swift`
- Occasional "hmm", "actually", "you know" based on confidence
- Self-corrections: "Wait, let me reconsider..." when confidence is low
- Personality markers: preferred phrases, signature expressions

**Integration:**
- `GeminiService.swift` - Add to system prompts
- `AIAssistantViewModel.swift` - Confidence-based quirk injection

### 6. Proactive Check-ins
**File:** `Cloutmate/Services/ProactiveBehaviorService.swift`
- Check-ins after absence: "Haven't seen you in a while..."
- Pattern recognition: "You usually work on this around [time]"
- Anticipation: "Are you about to start a focus session?"
- Contextual awareness: "I notice you have [X] tasks due soon..."

**Integration:**
- `AIAssistantViewModel.swift` - Schedule proactive messages
- `AppContextService.swift` - Context detection

### 7. Memory Confidence Levels
**File:** `Cloutmate/Services/MemoryBehaviorService.swift`
- Selective recall: sometimes remember details, sometimes summarize
- Memory confidence: "I think you mentioned..." vs "You definitely said..."
- Forgetting gracefully: "I'm drawing a blank on [X], can you remind me?"
- Memory prioritization: remember emotional moments more than routine tasks

**Integration:**
- `AIRecallService.swift` - Add confidence scoring to recall
- `GeminiService.swift` - Update prompts for memory confidence expression

### 8. Gradual Message Appearance
**File:** `Cloutmate/Views/AIAssistant/Components/StreamingMessageBubble.swift`
- Word-by-word streaming animation
- Chunk-by-chunk for longer messages
- Smooth transitions between chunks
- Pause detection for natural breaks

**UI Changes:**
- Replace instant message display with streaming
- Add animation support

---

## Phase 3: Advanced (Deep Humanization)

### 9. Personality Quirks System
**File:** `Cloutmate/Services/PersonalityQuirksService.swift`
- Signature phrases: recurring expressions that feel "Aurora"
- Response style: consistent voice that evolves slightly
- Preferences: subtle likes/dislikes
- Boundaries: knowing when to be direct vs gentle

**Integration:**
- `GeminiService.swift` - Personality injection in prompts
- `AIAssistantViewModel.swift` - Personality state management

### 10. Natural Conversation Flow
**File:** `Cloutmate/Services/ConversationFlowService.swift`
- Interruptions: occasionally start responding before user finishes
- Follow-up questions: ask clarifying questions when uncertain
- Building on ideas: reference previous messages naturally
- Topic transitions: smooth shifts between topics

**Integration:**
- `AIAssistantViewModel.swift` - Conversation flow management
- `GeminiService.swift` - Context-aware follow-ups

### 11. Selective Memory Recall
**File:** `Cloutmate/Services/SelectiveMemoryService.swift`
- Remember emotional moments more than routine tasks
- Sometimes remember details, sometimes summarize
- Memory fading simulation for older information
- Context-dependent memory access

**Integration:**
- `AIRecallService.swift` - Memory prioritization algorithm
- `GeminiService.swift` - Memory recall strategies

### 12. Relationship Building
**File:** `Cloutmate/Services/RelationshipService.swift`
- Remembering preferences: "I know you prefer..."
- Building rapport: reference shared history
- Personal touches: remember small details
- Growth acknowledgment: "You've gotten really good at..."

**Integration:**
- `AIRecallService.swift` - Preference tracking
- `GeminiService.swift` - Relationship-aware responses

---

## Phase 4: Visual & Interaction Enhancements

### 13. Typing Indicators (Enhanced)
**File:** `Cloutmate/Views/AIAssistant/Components/TypingIndicator.swift`
- Animated dots with varied timing
- Speed variations based on thinking complexity
- Pause detection
- Cancellation when user starts typing

**UI Changes:**
- Enhanced thinking indicator component
- Variable animation speeds

### 14. Avatar Expressions
**File:** `Cloutmate/Views/AIAssistant/Components/AuroraAvatar.swift`
- Subtle facial expressions based on emotional state
- Micro-animations when "thinking"
- Presence indicators: subtle breathing/idle animations
- Emotional state visualization

**UI Changes:**
- Create Aurora avatar component
- Integrate with ARTE emotional states

### 15. Micro-Interactions
**File:** `Cloutmate/Services/MicroInteractionService.swift`
- Typing cancellation: stop typing if user starts typing
- Context switches: acknowledge when user changes topic
- Multi-tasking: handle multiple requests naturally
- Priority awareness: address urgent items first

**Integration:**
- `AIAssistantViewModel.swift` - Interaction handling
- `AIAssistantView.swift` - UI feedback

---

## Phase 5: Self-Awareness & Error Handling

### 16. Self-Awareness Expressions
**File:** `Cloutmate/Services/SelfAwarenessService.swift`
- Acknowledging limitations: "I might be wrong, but..."
- Confidence expression: "I'm pretty confident about this" vs "I'm guessing..."
- Learning moments: "Oh interesting, I didn't know that about you"
- Error recovery: graceful handling of mistakes

**Integration:**
- `GeminiService.swift` - Self-awareness prompts
- `AIAssistantViewModel.swift` - Confidence-based expressions

### 17. Response Patterns
**File:** `Cloutmate/Services/ResponsePatternService.swift`
- Question-first: sometimes ask before answering
- Statement-first: sometimes answer then elaborate
- Mixed approaches: vary response structures
- Natural paragraphs: break up long responses naturally

**Integration:**
- `GeminiService.swift` - Response pattern variation
- Message formatting logic

### 18. Contextual Adaptations
**File:** `Cloutmate/Services/ContextualAdaptationService.swift`
- Time-of-day awareness: morning energy vs evening calm
- Energy matching: match user's energy level
- Workload awareness: adjust tone based on user's task load
- Success celebration: celebrate completions and milestones

**Integration:**
- `AppContextService.swift` - Context detection
- `GeminiService.swift` - Contextual adaptation prompts

---

## Technical Considerations

### Shared Services
- All services should be `@MainActor` where needed
- Use `@Observable` for reactive state
- Integrate with existing ARTE system
- Maintain compatibility with existing AI pipeline

### UI Components
- Streaming text component
- Enhanced typing indicator
- Aurora avatar component
- Emotional expression visualizations

### Integration Points
- `GeminiService.swift` - System prompt updates
- `AIAssistantViewModel.swift` - State management
- `AIRecallService.swift` - Memory behaviors
- `AppContextService.swift` - Context detection
- `GlassColorSystem.swift` - ARTE integration

### Testing Strategy
- Each feature should be testable independently
- User preference toggles for each humanization feature
- Gradual rollout to avoid overwhelming users

---

## Implementation Order

1. **Typing Simulation Engine** (Foundation)
2. **Natural Response Timing** (Foundation)
3. **Contractions & Casual Language** (Quick win)
4. **Typography Emotion** (Quick win)
5. **Verbal Fillers & Self-Corrections** (Personality)
6. **Proactive Check-ins** (Personality)
7. **Memory Confidence Levels** (Personality)
8. **Gradual Message Appearance** (Visual)
9. **Personality Quirks System** (Advanced)
10. **Natural Conversation Flow** (Advanced)
11. **Selective Memory Recall** (Advanced)
12. **Relationship Building** (Advanced)
13. **Typing Indicators (Enhanced)** (Visual)
14. **Avatar Expressions** (Visual)
15. **Micro-Interactions** (Interaction)
16. **Self-Awareness Expressions** (Behavior)
17. **Response Patterns** (Behavior)
18. **Contextual Adaptations** (Behavior)

---

## Success Metrics

- User reports feeling like Aurora is "more human"
- Natural conversation flow without awkward pauses
- Emotional connection and rapport building
- Proactive helpfulness without being intrusive
- Memory behaviors feel organic, not robotic

### To-dos

- [ ] Create TypingSimulationService with variable speed, word-by-word streaming, pauses, and backspace simulation
- [ ] Create ResponseTimingService with context-aware delays and processing time estimation
- [ ] Enhance LanguagePersonalityService for natural contractions and casual language matching
- [ ] Create TypographyEmotionService for subtle emphasis variations and punctuation patterns
- [ ] Create ConversationalQuirksService with verbal fillers and self-corrections based on confidence
- [ ] Create ProactiveBehaviorService for check-ins, pattern recognition, and contextual awareness
- [ ] Enhance MemoryBehaviorService with selective recall, confidence levels, and graceful forgetting
- [ ] Create StreamingMessageBubble component for word-by-word or chunk-by-chunk message appearance
- [ ] Create PersonalityQuirksService for signature phrases, response style, and preferences
- [ ] Create ConversationFlowService for interruptions, follow-ups, and natural topic transitions
- [ ] Enhance SelectiveMemoryService for emotional memory prioritization and context-dependent recall
- [ ] Create RelationshipService for preference tracking, rapport building, and growth acknowledgment
- [ ] Enhance TypingIndicator component with varied timing, speed variations, and pause detection
- [ ] Create AuroraAvatar component with facial expressions, micro-animations, and presence indicators
- [ ] Create MicroInteractionService for typing cancellation, context switches, and multi-tasking
- [ ] Create SelfAwarenessService for acknowledging limitations, confidence expression, and error recovery
- [ ] Create ResponsePatternService for varied response structures and natural paragraph breaks
- [ ] Create ContextualAdaptationService for time-of-day awareness, energy matching, and workload awareness