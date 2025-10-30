<!-- e4f4444c-cd23-4ffb-8315-9f3a855bbcbc f4c76243-baa2-4565-acf9-2c0567425aa0 -->
# Adding AI Assistant Execution Capabilities

## Overview

Enable the AI assistant to execute actions across the app using Gemini's Function Calling API: archiving tasks, summarizing posts, generating reports, and predicting scheduling needs.

## Current State Analysis

**Current AI capabilities:**

- Context-aware responses via AppContextService
- Intent detection for creation (tasks, projects, posts)
- Preference updates
- Post scheduling

**Missing capabilities:**

- Bulk operations (archive/update multiple tasks)
- Data analysis and summarization
- Report generation
- Predictive scheduling

## Implementation Plan

### 1. Add Execution Functions to GeminiService

**File:** `Cloutmate/Services/GeminiService.swift`

Add Gemini Function definitions using Function Calling API:

- `archive_tasks(criteria: string, age_days: int, modelContext: ModelContext)` - Archive matching tasks
- `summarize_posts(filter: string, modelContext: ModelContext)` - Summarize posts by filter
- `generate_report(report_type: string, timeframe: string, modelContext: ModelContext)` - Generate progress reports
- `predict_scheduling(timeframe: string, modelContext: ModelContext)` - Predict future scheduling needs

### 2. Create Execution Service

**New file:** `Cloutmate/Services/AIExecutionService.swift`

Service with execution methods:

- `archiveTasks(criteria: ArchiveCriteria, context: ModelContext) -> ExecutionResult`
- `summarizePosts(filter: String, context: ModelContext) -> ExecutionResult`
- `generateProgressReport(type: ReportType, timeframe: TimeFrame, context: ModelContext) -> ExecutionResult`
- `predictSchedulingNeeds(timeframe: String, context: ModelContext) -> ExecutionResult`

### 3. Update AIAssistantViewModel for Function Calling

**File:** `Cloutmate/ViewModels/AIAssistantViewModel.swift`

- Integrate Gemini Function Calling in processMessage()
- Detect when Gemini calls execution functions
- Execute functions and return results to AI
- Display execution results in chat

### 4. Add Execution Feedback & Auto-Execute

**User Choice:** Auto-execute operations with structured feedback

- Auto-execute operations (no blocking confirmations per user preference)
- Provide detailed success feedback in chat with counts and summaries
- Track execution results (count of items affected, changes made)
- Show warnings only for very large operations (>100 items)
- Use undo capability for destructive operations

### 5. Enhance App Context with More Detail

**File:** `Cloutmate/Services/AppContextService.swift`

Add richer context:

- Recent post performance metrics
- Task completion patterns
- Upcoming deadlines
- Historical analytics data

### 6. Define Function Schemas

Create structured Function schemas for Gemini:

- Define parameter types and constraints
- Add descriptions for each function
- Specify return value structure
- Implement error handling

## Key Considerations

**Safety:**

- Auto-execute operations with clear feedback
- Log all executions for audit trail
- Return detailed execution results in chat
- Validate parameters before execution

**Reliability:**

- Use Gemini's Function Calling (Tools API) for structured execution
- Validate parameters before execution
- Handle errors gracefully with rollback where possible
- Use atomic operations for bulk updates

**User Experience:**

- Natural language understanding for execution commands
- Structured feedback showing what was executed and results
- Display counts, summaries, and details in chat conversation
- Use markdown formatting for readable reports

## Technical Approach

Using Gemini Function Calling API:

1. Define execution functions with structured schemas
2. Pass function definitions to Gemini in prompts
3. AI decides when to call functions based on user input
4. Execute function calls and return results
5. AI incorporates results into natural language response
6. Display complete interaction in chat

This approach keeps execution cohesive with AI reasoning while providing structured, reliable operations.

### To-dos

- [ ] Add ExecutionIntent struct and inferExecutionIntent() method to GeminiService
- [ ] Create AIExecutionService with methods for archiving, summarizing, reporting, and predicting
- [ ] Update AIAssistantViewModel to detect and handle execution intents
- [ ] Add confirmation dialogs for destructive operations in AIAssistantView
- [ ] Enhance AppContextService with richer analytics and historical data
- [ ] Add execution tool descriptions to Gemini prompts