<!-- cd5fe289-867e-46b8-aff3-7ec445dd96af 66308acb-1d78-4b41-bb3c-f6739cfabba9 -->
# Implement Hybrid Journal System for FocusOS

## Overview

Create a comprehensive journaling system that allows users to capture personal reflections, content ideas, and project insights, with full AI assistance, filtering, and integration with the existing PARA system (Notes, Areas, Projects).

## Architecture

### Model Structure

**New File:** `FocusOS/Models/Journal.swift`

- SwiftData model similar to Note but with journal-specific fields
- Fields: `id`, `title`, `content`, `mood`, `tags`, `entryDate`, `createdAt`, `updatedAt`, `projectId`, `areaId`, `linkedNoteIds`, `linkedAreaIds`, `linkedProjectIds`, `aiPrompt`, `aiGeneratedContent`, `isArchived`
- Links to Notes via `linkedNoteIds`, Areas via `areaId` and `linkedAreaIds`, Projects via `projectId` and `linkedProjectIds`

### View Structure

**New Files:**

- `FocusOS/Views/Journal/JournalView.swift` - Main journal list/table view
- `FocusOS/Views/Journal/CreateJournalEntrySheet.swift` - Create/edit journal entry
- `FocusOS/Views/Journal/JournalDetailView.swift` - Detail view with AI controls
- `FocusOS/Views/Journal/Components/JournalFiltersView.swift` - Filter chips and search
- `FocusOS/Views/Journal/Components/AIPromptPanel.swift` - AI prompt suggestions and generation

### Service Integration

**New Files:**

- `FocusOS/Services/JournalAIService.swift` - AI prompts, content generation, reflection analysis
- Uses existing `GeminiService` for AI functionality

### UI Updates

**Files to Modify:**

1. `FocusOS/Views/MainWindowView.swift` - Add `.journal` tab identifier and view case
2. `FocusOS/Views/Sidebar.swift` - Update sections: move Inbox/Notes/Journal to CAPTURE section
3. `FocusOS/FocusOSApp.swift` - Ensure Journal model is in model container

## Implementation Details

### Journal Model

- Inherits SwiftData @Model pattern
- Supports multiple entry types (reflection, content-idea, project-tracker)
- Rich linking system to Notes, Areas, Projects
- Tag support for organization
- Mood tracking for reflections
- AI prompt field for storing user prompts
- AI-generated content field for storing AI responses

### JournalView Layout

- Similar to NotesView/AreasView structure
- Search bar with filter chips
- Table view with columns: Title, Preview, Tags, Mood, Date, Linked Items
- Context menu for edit, duplicate, archive, delete
- Toolbar with "New Entry" and bulk actions
- Export to CSV capability

### AI Features

- Context-aware prompt suggestions based on date, time of day, recent activity
- Generate content: "Brainstorm content ideas for my area X"
- Reflect on entries: "What patterns do you notice in my recent entries?"
- Mood-based prompts: "Write about something that made you grateful today"
- Leverage existing GeminiService and AICreativeService patterns

### Linking System

- Visual indicators showing linked Notes/Areas/Projects
- Click to navigate to linked items
- Add/remove links in detail view
- Backlink support (show journal entries that link to current item)

### Color Theme

- Use existing GlassColorSystem
- Match glassmorphic design of other views
- Purple/pink accent for journal entries (differentiate from Notes' blue)

## Key Features

1. **Three Entry Types:**

- Personal Reflection: mood tracking, daily thoughts
- Content Ideas: capture inspiration, link to content areas
- Project Tracker: log progress, insights for specific projects

2. **AI-Assisted Workflow:**

- Smart prompt suggestions based on context
- Generate content from prompts
- Analyze entries for patterns/insights
- Summarize multiple entries

3. **Advanced Filtering:**

- By tags, entry type, mood, date range
- By linked items (show entries linked to specific Area/Project)
- Search across content and AI-generated text

4. **Integration:**

- Journal entries can link to Notes (cross-reference ideas)
- Link to Areas (track area-related insights)
- Link to Projects (document project learning)
- Bi-directional linking (backlinks visible)

### To-dos

- [ ] Create Journal.swift model with entry types, mood, tags, and linking fields (linkedNoteIds, linkedAreaIds, linkedProjectIds, projectId, areaId)
- [ ] Build JournalView.swift with table layout, search, and filters matching NotesView/AreasView structure
- [ ] Create CreateJournalEntrySheet.swift and JournalDetailView.swift for entry creation/editing with AI controls
- [ ] Build JournalAIService.swift for prompt suggestions, content generation, and entry analysis using GeminiService
- [ ] Add .journal tab to TabIdentifier enum and MainWindowView contentView switch statement
- [ ] Reorganize sidebar: create CAPTURE section with Inbox, Notes, Journal tabs
- [ ] Add Journal to model container in FocusOSApp.swift
- [ ] Add linking controls to JournalDetailView with visual indicators for linked Notes/Areas/Projects
- [ ] Add CSV export functionality for journal entries matching ListTableView export pattern