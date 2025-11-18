<!-- cc608071-f070-4f9c-892c-76aad3adea69 b3565cd4-08bf-494c-a00d-a9acb31eab77 -->
# AI Conversation Enhancements - Implementation Plan

## Overview

Transform the AI Assistant tab from a simple chat interface into an intelligent creative workspace with pinned conversations, auto-summaries, tagging, and seamless draft integration.

## Phase 1: Core Organizational Features (Immediate Priority)

### 1. Pinned Conversations

**File: `FocusOS/Models/AIMessage.swift` (AIConversation)**

- Add properties:
```swift
@Attribute var isPinned: Bool = false
@Attribute var pinnedAt: Date?
```


**File: `FocusOS/ViewModels/AIAssistantViewModel.swift`**

- Add method: `togglePin(_ conversation: AIConversation, modelContext: ModelContext)`
- Update `filteredConversations` to sort pinned conversations first

**File: `FocusOS/Views/AIAssistant/AIAssistantView.swift` (ConversationRow)**

- Add star icon overlay for pinned conversations
- Add "Pin to Top" / "Unpin" in context menu
- Visual distinction: subtle blue glow or star badge

### 2. Auto-Generated Conversation Summaries

**File: `FocusOS/Models/AIMessage.swift` (AIConversation)**

- Add properties:
```swift
@Attribute var summary: String?
@Attribute var lastSummaryGeneratedAt: Date?
```


**File: `FocusOS/Services/GeminiService.swift`**

- Add method: `generateConversationSummary(messages: [AIMessage]) async throws -> String`
- Prompt: "Summarize this conversation in 2-3 sentences focusing on key topics and outcomes"

**File: `FocusOS/ViewModels/AIAssistantViewModel.swift`**

- Add method: `generateSummary(for conversation: AIConversation, modelContext: ModelContext) async`
- Auto-trigger when: conversation has 5+ messages and hasn't been updated in 24 hours
- Add method: `refreshSummary(_ conversation: AIConversation, modelContext: ModelContext) async`

**File: `FocusOS/Views/AIAssistant/AIAssistantView.swift` (ConversationRow)**

- Display summary below title as secondary text
- Add "Refresh Summary" button in context menu

### 3. Topic Tagging & Auto-Categorization

**File: `FocusOS/Models/AIMessage.swift` (AIConversation)**

- Add property:
```swift
@Attribute var tagsData: Data? // Encoded [String]
var tags: [String] {
    get { decode tagsData }
    set { encode to tagsData }
}
```


**File: `FocusOS/Services/GeminiService.swift`**

- Add method: `categorizeCo

nversation(title: String, summary: String?) async throws -> [String]`

- Return 1-3 soft categories (e.g., "Facebook strategy", "Copywriting", "Analytics")

**File: `FocusOS/ViewModels/AIAssistantViewModel.swift`**

- Add method: `autoTag(_ conversation: AIConversation, modelContext: ModelContext) async`
- Trigger after summary generation
- Add `selectedTags: Set<String>` property for filtering
- Update `filteredConversations` to filter by tags

**File: `FocusOS/Views/AIAssistant/Components/ConversationSearchBar.swift`**

- Add tag chips filter UI below search
- Display active tags with X to remove
- Add "All Tags" dropdown menu

**File: `FocusOS/Views/AIAssistant/AIAssistantView.swift` (ConversationRow)**

- Display tag chips beside title using HStack with colored badges

## Phase 2: Workflow Integration (High Priority)

### 4. Export to Drafts

**File: `FocusOS/ViewModels/AIAssistantViewModel.swift`**

- Add method: `exportToDraft(messages: [AIMessage], modelContext: ModelContext) -> Draft`
- Extract all assistant messages as draft content
- Include conversation title as notes

**File: `FocusOS/Views/AIAssistant/AIAssistantView.swift`**

- Add "Export to Drafts" in ConversationRow context menu
- Add "Export Current Chat" button in chat area toolbar
- Show success toast: "Exported to Drafts"
- Optional: Jump to Drafts tab after export

**File: `FocusOS/Views/AIAssistant/AIAssistantView.swift` (mainChatArea)**

- Add floating action button: "Export Chat to Drafts"
- Only show when messages exist

### 5. Quick Actions (Hover Menu)

**File: `FocusOS/Views/AIAssistant/AIAssistantView.swift` (ConversationRow)**

- Add hover state: `@State private var isHovered = false`
- On hover, show action buttons overlay:
  - "Continue" → loads conversation
  - "Summarize" → generates/shows summary
  - "Export" → exports to drafts
  - "Share" → future feature placeholder

**Implementation approach:**

```swift
.overlay(alignment: .trailing) {
    if isHovered {
        HStack(spacing: 8) {
            QuickActionButton(icon: "arrow.forward", action: onContinue)
            QuickActionButton(icon: "doc.text", action: onSummarize)
            QuickActionButton(icon: "square.and.arrow.up", action: onExport)
        }
        .padding(.trailing, 8)
        .transition(.opacity)
    }
}
.onHover { isHovered = $0 }
```

### 6. Smart Conversation Recap

**File: `FocusOS/Views/AIAssistant/AIAssistantView.swift` (mainChatArea)**

- Add "Summarize Chat" floating button (visible when 10+ messages)
- Generate inline summary using Gemini
- Insert as system message (distinct styling)
- Make collapsible

**File: `FocusOS/Models/AIMessage.swift`**

- Add `isSystemMessage: Bool = false` to differentiate summaries

**File: `FocusOS/Services/GeminiService.swift`**

- Add method: `summarizeRecentMessages(_ messages: [AIMessage], count: Int = 15) async throws -> String`

## Phase 3: Advanced Intelligence (Future Phase)

### 7. Memory Recall System (Lightweight Vector Search)

**Approach:** Use Gemini's semantic similarity

- Store conversation summaries
- When user asks a question, compare against all summaries
- If similarity > threshold, suggest related conversation
- Display: "Found a related idea from Oct 10 — want to reference it?"

**Implementation complexity:** Medium-High

**Decision:** Defer to Phase 3 (requires semantic search infrastructure)

### 8. Cross-Conversation Insights

**File: `FocusOS/Views/AIAssistant/AIAssistantView.swift`**

- Add "Reflection" panel in sidebar header
- Weekly/monthly auto-summary of recurring topics
- Display: "You often discuss engagement optimization — want to combine these?"

**Implementation:** Use Gemini to analyze conversation titles + tags

**Decision:** Defer to Phase 3 (analytics layer needed)

### 9. Global Search Command (⌘+K)

**Implementation:**

- New overlay view with search
- Search across: Conversations, Drafts, Posts, Insights
- Jump to specific message/entity

**Decision:** Defer to Phase 3 (requires app-wide search infrastructure)

## Implementation Priority

### Immediate (Phase 1 - This Session)

1. ✅ Pinned Conversations
2. ✅ Auto-Generated Summaries
3. ✅ Topic Tagging & Filtering

### High Priority (Phase 2 - Next Session)

4. Export to Drafts
5. Quick Actions (Hover Menu)
6. Smart Recap Button

### Future Enhancements (Phase 3 - Later)

7. Memory Recall System
8. Cross-Conversation Insights
9. Global Search Command

## Technical Decisions

**Data Storage:**

- Use SwiftData for persistence (already configured)
- `isPinned`, `summary`, `tags` as AIConversation attributes
- CloudKit compatibility maintained (all optional attributes)

**Gemini Integration:**

- Reuse existing `GeminiService` actor
- Add new methods for summaries, categorization
- Keep prompts concise to minimize API usage

**UI/UX:**

- Glassmorphic design consistency
- Subtle animations (fade, scale)
- Context menus for power users
- Hover states for discoverability

## Files to Create

- None (all modifications to existing files)

## Files to Modify (Phase 1)

- `FocusOS/Models/AIMessage.swift` (AIConversation model)
- `FocusOS/Services/GeminiService.swift` (new methods)
- `FocusOS/ViewModels/AIAssistantViewModel.swift` (pin, summary, tag logic)
- `FocusOS/Views/AIAssistant/Components/ConversationSearchBar.swift` (tag filter UI)
- `FocusOS/Views/AIAssistant/AIAssistantView.swift` (ConversationRow updates)

### To-dos

- [ ] Add isPinned and pinnedAt properties to AIConversation model
- [ ] Add summary and lastSummaryGeneratedAt properties to AIConversation model
- [ ] Add tags (encoded as Data) property to AIConversation model with Codable helpers
- [ ] Add togglePin method to AIAssistantViewModel and update filteredConversations sorting
- [ ] Add generateConversationSummary method to GeminiService
- [ ] Add categorizeConversation method to GeminiService for auto-tagging
- [ ] Add summary generation and refresh methods to AIAssistantViewModel
- [ ] Add auto-tagging and tag filtering logic to AIAssistantViewModel
- [ ] Add pin icon, summary display, tag chips, and updated context menu to ConversationRow
- [ ] Add tag filter chips and dropdown to ConversationSearchBar
- [ ] Implement exportToDraft method and add context menu action
- [ ] Add hover state and quick action buttons to ConversationRow
- [ ] Add 'Summarize Chat' floating button and inline system message display