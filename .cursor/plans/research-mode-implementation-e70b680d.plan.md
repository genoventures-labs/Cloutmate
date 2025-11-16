<!-- e70b680d-a95a-40f2-9c15-66b0306f346c 19ba4544-09c8-49c6-b4b6-11e9b4261ad5 -->
# Research Progress Indicator Implementation

## Overview

Replace the standard ThinkingIndicator with a simple updating card when Aurora is running deep research mode. The card shows the current action and source count in the format "[What Aurora is doing] - [# of sources]", updating dynamically as research progresses.

## Files to Modify

### 1. `Cloutmate/ViewModels/AIAssistantViewModel.swift`

- Add `currentResearchAction: String?` to track current action text (e.g., "Searched for: [query]")
- Add `currentResearchSourceCount: Int` to track number of sources
- Add methods: `updateResearchProgress(action: String, sourceCount: Int)`, `clearResearchProgress()`

### 2. `Cloutmate/Services/CoreResponseService.swift`

- Modify `generateResearchResponse` to emit progress updates via MainActor
- Add progress updates at key stages:
- Web search: "Searched for: [query]" with source count from search results
- Local analysis: "Analyzing locally..." (no source count)
- Cloud analysis: "Analyzing with cloud model..." (no source count)
- Reading sources: "Read: [Page Title] ([source])" with source count as each source is processed

### 3. `Cloutmate/Services/HybridBridgeService.swift`

- Update `generateCloudResponseWithAppContextAndWebSearch` to emit web search progress
- Emit progress when web search completes with query and result count
- Emit progress for each source being read/analyzed

### 4. `Cloutmate/Views/AIAssistant/Components/ResearchProgressIndicator.swift` (NEW)

- Create new component to replace ThinkingIndicator during research mode
- Simple compact card design matching image reference:
- Rounded corners, light background with V2 glass panel styling
- Horizontal layout: action text on left, source count on right
- Format: "[Action text] - [#] sources" or "[Action text]" if no sources
- Examples:
 - "Searched for: retail foot traffic 2022... - 3 sources"
 - "Read: Page Title (source pill) - 1 source"
 - "Analyzing with DeepSeek R1..."
- Source count displayed in kosmicBlue color
- Smooth fade transitions when text updates (0.2s ease-in-out)
- No progress bar - clean, minimal design
- Optional subtle icon (magnifyingglass for search, book.open for read)

### 5. `Cloutmate/Views/AIAssistant/AIAssistantView.swift` or `AuroraChatContainer.swift`

- Conditionally show `ResearchProgressIndicator` instead of `ThinkingIndicator` when `viewModel.isResearchMode && viewModel.isLoading`
- Pass `viewModel.currentResearchAction` and `viewModel.currentResearchSourceCount` to the indicator

### 6. `Cloutmate/ViewModels/AIAssistantViewModel.swift` (continued)

- In `sendMessage`, initialize research progress tracking when research mode is detected
- Clear research progress after response completes

## Implementation Details

### Progress Tracking Flow

1. User triggers `/research` command
2. `AIAssistantViewModel` detects research mode and initializes progress tracking
3. `CoreResponseService.generateResearchResponse` starts execution
4. At each stage, progress updates are emitted via MainActor to `AIAssistantViewModel`:

- Web search completes: "Searched for: [query]" with result count
- Each source processed: "Read: [title] ([source])" with updated count
- Model analysis: "Analyzing with [model]..." (no source count)

5. `ResearchProgressIndicator` observes updates and animates text changes
6. Progress clears when response completes

### Visual Design

- Compact card matching image reference:
- White/light gray background with rounded corners
- Action text (dark color) on left
- Source count (kosmicBlue) on right, same line
- Truncated text with ellipsis if needed
- Simple, clean layout
- Text transitions: Fade out old (0.15s), fade in new (0.15s)
- No progress bar, percentages, or complex animations

### Animation Strategy

- Text updates: Smooth fade transition (0.15s fade out, 0.15s fade in)
- Source count: Smooth number updates with fade
- Optional icon: Subtle pulse for active steps (if icon is shown)
- Overall: Minimal, focused on text updates

## Key Considerations

- Progress updates must be thread-safe (use MainActor)
- Indicator should gracefully handle rapid updates
- Should not block UI thread during heavy research operations
- Fallback to standard ThinkingIndicator if progress tracking fails
- Source count should be displayed only when relevant (search/read steps)

### To-dos

- [ ] Add /research case to SlashCommand enum with label and icon
- [ ] Add deepseek-r1:1.5b to ModelTierMap with thinking support
- [ ] Add research mode state tracking in AIAssistantViewModel
- [ ] Detect /research in sendMessage() and set research mode flag
- [ ] Create generateResearchResponse() that runs local then cloud model sequentially
- [ ] Add web search support to HybridBridgeService cloud requests
- [ ] Create SourceExtractor to extract URLs from responses and web search
- [ ] Add research mode pill indicator in AIMessageComposer
- [ ] Add researchSources property to AIMessage model
- [ ] Create SourcePillView component with max 3 visible and view all button
- [ ] Format research response as two sections with divider (no labels)
- [ ] Reset research mode flag after response completes
- [ ] Update handleSlashCommand() to handle .research case