<!-- 5757f18c-bed1-4f3b-b520-3806eb6bb026 140e7357-4c7e-47a5-94d1-261623a10bae -->
# Add Sort Options and Enhanced Filters to All Views

## Overview

Add comprehensive sort options with category dropdowns (same style as Tasks/Projects) and additional filtering capabilities to 6 views: Areas, Notes, Inbox, Resources, Journal, and Drafts.

## Additional Filters for Tasks & Projects

### Tasks (UnifiedTasksView) - Current Filters
- All, Today, Upcoming, Completed

### Tasks - Additional Filter Options
**Priority Filters:**
- High Priority
- Medium Priority  
- Low Priority

**Status Filters:**
- To Do
- In Progress
- Done
- Cancelled

**Relationship Filters:**
- By Project (dropdown to select specific project)
- By Area (dropdown to select specific area)
- Unattached (no project or area)
- Has Project
- Has Area

**Due Date Filters:**
- With Due Date
- Without Due Date
- Overdue
- Due This Week
- Due This Month

**Effort Filters:**
- Small Effort
- Medium Effort
- Large Effort
- No Effort

**Combined Filters:**
- High Priority + Overdue
- Today + High Priority
- Unattached + Overdue

### Projects (UnifiedProjectsView) - Current Filters
- All, Active, Paused, Completed

### Projects - Additional Filter Options
**Due Date Filters:**
- With Due Date
- Without Due Date
- Overdue
- Due This Week
- Due This Month
- Due This Quarter

**Relationship Filters:**
- By Area (dropdown to select specific area)
- Unattached (no area)
- Has Area

**Tag Filters:**
- With Tags
- Without Tags
- By Tag (multi-select dropdown)

**Activity Filters:**
- Recently Updated (last 7 days)
- Recently Created (last 7 days)
- Stale (not updated in 30+ days)

**Combined Filters:**
- Active + Overdue
- Active + With Due Date
- Paused + Recently Updated

## Sort Options Brainstorm

### 1. Areas (UnifiedAreasView)

**Available Fields:** title, notes, createdAt, updatedAt, archivedAt, tags, status, lastReviewDate, stabilityScore, colorAccent, categoryIcon

**Sort Categories:**
- **Date & Time:** updatedAt (newest/oldest), createdAt (newest/oldest), lastReviewDate (recent/old), archivedAt (recent/old)
- **Alphabetical:** title (A→Z, Z→A)
- **Status:** active first, archived first, review needed first
- **Stability:** stabilityScore (high→low, low→high)
- **Tags:** tagCount (most/least)
- **Combined:** status then updatedAt, stability then updatedAt

**Additional Filter Options:**
- Filter by tag (multi-select)
- Filter by colorAccent
- Filter by review status (overdue, due soon, not due)
- Filter by stability range (high/medium/low)
- Filter by categoryIcon

### 2. Notes (UnifiedNotesView)

**Available Fields:** title, markdown, tags, createdAt, updatedAt, archivedAt, isPinned, pinnedAt, projectId, areaId, type, author, source

**Sort Categories:**
- **Date & Time:** updatedAt (newest/oldest), createdAt (newest/oldest), pinnedAt (recent/old)
- **Alphabetical:** title (A→Z, Z→A)
- **Pinned:** pinned first, unpinned first
- **Type:** by ResourceType (note, article, video, etc.)
- **Relationship:** byProject, byArea, unattachedFirst/Last
- **Tags:** tagCount (most/least)
- **Author:** user first, aurora first
- **Combined:** pinned then updatedAt, type then updatedAt

**Additional Filter Options:**
- Filter by specific tag (multi-select)
- Filter by ResourceType (note, article, video, podcast, book, link)
- Filter by author (user, aurora)
- Filter by project (dropdown)
- Filter by area (dropdown)
- Filter by pinned status
- Filter by source (has source, no source)
- Filter by word count range (short/medium/long based on markdown length)

### 3. Inbox (InboxView)

**Available Fields:** content, itemType, createdAt, convertedAt, isFlagged, isArchived, aiImported, convertedToType, convertedToId

**Sort Categories:**
- **Date & Time:** createdAt (newest/oldest), convertedAt (recent/old)
- **Type:** by itemType (text, image, file, url, voice)
- **Status:** flagged first, unflagged first, converted first, unconverted first
- **AI:** aiImported first, user-imported first
- **Combined:** flagged then createdAt, type then createdAt

**Additional Filter Options:**
- Filter by itemType (text, image, file, url, voice)
- Filter by conversion status (converted, unconverted)
- Filter by convertedToType (task, note, project, draft)
- Filter by date range (today, this week, this month, older)
- Filter by content length (short/medium/long)

### 4. Resources (UnifiedResourcesView)

**Available Fields:** title, markdown, tags, createdAt, updatedAt, archivedAt, type, source, projectId, areaId, author

**Sort Categories:**
- **Date & Time:** updatedAt (newest/oldest), createdAt (newest/oldest)
- **Alphabetical:** title (A→Z, Z→A)
- **Type:** by ResourceType (note, article, video, podcast, book, link)
- **Relationship:** byProject, byArea, unattachedFirst/Last
- **Tags:** tagCount (most/least)
- **Author:** user first, aurora first
- **Combined:** type then updatedAt, author then updatedAt

**Additional Filter Options:**
- Filter by ResourceType (multi-select)
- Filter by specific tag (multi-select)
- Filter by author (user, aurora)
- Filter by project (dropdown)
- Filter by area (dropdown)
- Filter by source (has URL, no URL)
- Filter by media type (has media, no media)

### 5. Journal (UnifiedJournalView)

**Available Fields:** title, content, entryDate, createdAt, updatedAt, entryType, mood, tags, projectId, areaId, author, aiPrompt, aiGeneratedContent

**Sort Categories:**
- **Date & Time:** entryDate (newest/oldest), createdAt (newest/oldest), updatedAt (newest/oldest)
- **Alphabetical:** title (A→Z, Z→A)
- **Entry Type:** by JournalEntryType (reflection, contentIdea, projectTracker)
- **Mood:** by JournalMood (excited, grateful, reflective, etc.)
- **Relationship:** byProject, byArea, unattachedFirst/Last
- **Tags:** tagCount (most/least)
- **Author:** user first, aurora first
- **AI Content:** hasAIGeneratedContent first, noAIGeneratedContent first
- **Combined:** entryType then entryDate, mood then entryDate, author then entryDate

**Additional Filter Options:**
- Filter by JournalEntryType (reflection, contentIdea, projectTracker)
- Filter by JournalMood (multi-select)
- Filter by specific tag (multi-select)
- Filter by author (user, aurora)
- Filter by project (dropdown)
- Filter by area (dropdown)
- Filter by time of day (morning 5-12, afternoon 12-17, evening 17-22, night 22-5)
- Filter by AI content (has AI content, no AI content)
- Filter by date range (today, this week, this month, this year, custom range)

### 6. Drafts (UnifiedDraftsView)

**Available Fields:** title, caption, createdAt, updatedAt, lastEditedAt, archivedAt, isPublished, isArchived, wordCount, tags, source, scheduledOrPublishedDate, convertedAt

**Sort Categories:**
- **Date & Time:** lastEditedAt (newest/oldest), updatedAt (newest/oldest), createdAt (newest/oldest), scheduledOrPublishedDate (upcoming/past)
- **Alphabetical:** title (A→Z, Z→A)
- **Status:** published first, unpublished first, archived first
- **Word Count:** wordCount (high→low, low→high)
- **Tags:** tagCount (most/least)
- **Source:** by source (AI-generated, user-created, etc.)
- **Combined:** status then lastEditedAt, wordCount then lastEditedAt

**Additional Filter Options:**
- Filter by publication status (published, unpublished, scheduled)
- Filter by source (AI-generated, user-created, from notes, from AI assistant)
- Filter by word count range (short <500, medium 500-2000, long >2000)
- Filter by specific tag (multi-select)
- Filter by scheduled date (upcoming, past, none)
- Filter by media (has media, no media)
- Filter by date range (created, last edited)

## Implementation Plan

### Phase 0: Add Additional Filters to Tasks & Projects (Priority)

**For UnifiedTasksView:**
1. Expand `TaskFilter` enum to include:
   - Priority filters: `.highPriority`, `.mediumPriority`, `.lowPriority`
   - Status filters: `.todo`, `.inProgress`, `.cancelled` (separate from completed)
   - Relationship filters: `.unattached`, `.hasProject`, `.hasArea`
   - Due date filters: `.withDueDate`, `.withoutDueDate`, `.overdue`, `.dueThisWeek`, `.dueThisMonth`
   - Effort filters: `.smallEffort`, `.mediumEffort`, `.largeEffort`, `.noEffort`
2. Add state for advanced filters:
   - `@State private var selectedProjectFilter: UUID?` (for "By Project" dropdown)
   - `@State private var selectedAreaFilter: UUID?` (for "By Area" dropdown)
3. Update `filteredTasks` to handle all new filter cases
4. Add filter UI components:
   - Expand filter panel with additional filter sections
   - Add dropdowns for project/area selection
   - Group filters by category (Priority, Status, Relationship, Due Date, Effort)
   - Use FilterPill components for simple filters, dropdowns for selections

**For UnifiedProjectsView:**
1. Expand `ProjectFilter` enum to include:
   - Due date filters: `.withDueDate`, `.withoutDueDate`, `.overdue`, `.dueThisWeek`, `.dueThisMonth`, `.dueThisQuarter`
   - Relationship filters: `.unattached`, `.hasArea`
   - Tag filters: `.withTags`, `.withoutTags`
   - Activity filters: `.recentlyUpdated`, `.recentlyCreated`, `.stale`
2. Add state for advanced filters:
   - `@State private var selectedAreaFilter: UUID?` (for "By Area" dropdown)
   - `@State private var selectedTags: Set<String> = []` (for tag multi-select)
3. Update `filteredProjects` to handle all new filter cases
4. Add filter UI components:
   - Expand filter panel with additional filter sections
   - Add dropdown for area selection
   - Add tag multi-select component
   - Group filters by category (Due Date, Relationship, Tags, Activity)

### Phase 1: Create Sort Option Enums
1. Create `AreaSortOption.swift` with categories and all sort options
2. Create `NoteSortOption.swift` with categories and all sort options
3. Create `InboxSortOption.swift` with categories and all sort options
4. Create `ResourceSortOption.swift` with categories and all sort options
5. Create `JournalSortOption.swift` with categories and all sort options
6. Create `DraftSortOption.swift` with categories and all sort options

### Phase 2: Add Sort State & Persistence
1. Add `@AppStorage` properties for each view mode in all 6 views
2. Add `currentSortOption` computed properties
3. Create `sortedFilteredItems` computed properties that apply both filter and sort

### Phase 3: Implement Sorting Logic
1. Add `sortAreas()` method to UnifiedAreasView
2. Add `sortNotes()` method to UnifiedNotesView
3. Add `sortInboxItems()` method to InboxView
4. Add `sortResources()` method to UnifiedResourcesView
5. Add `sortJournals()` method to UnifiedJournalView
6. Add `sortDrafts()` method to UnifiedDraftsView

### Phase 4: Add Sort UI to Filter Panels
1. Update filter panels in all 6 views to include category dropdowns (same style as Tasks/Projects)
2. Add horizontal scrollable row of category dropdowns
3. Style active dropdowns with accent colors

### Phase 5: Add Additional Filters
1. **Areas:** Add tag filter, color filter, review status filter, stability filter
2. **Notes:** Add tag multi-select, type filter, author filter, project/area filters
3. **Inbox:** Add itemType filter, conversion status filter, date range filter
4. **Resources:** Add type multi-select, tag multi-select, author filter
5. **Journal:** Add entryType filter, mood multi-select, time of day filter, date range filter
6. **Drafts:** Add publication status filter, source filter, word count range filter

### Phase 6: Update View References
1. Update all view modes in each view to use sorted data
2. Ensure sorting works with existing filters
3. Add view mode change handlers

## Files to Create

1. `FocusOS/Views/Areas/AreaSortOption.swift`
2. `FocusOS/Views/Notes/NoteSortOption.swift`
3. `FocusOS/Views/Inbox/InboxSortOption.swift`
4. `FocusOS/Views/Resources/ResourceSortOption.swift`
5. `FocusOS/Views/Journal/JournalSortOption.swift`
6. `FocusOS/Views/Drafts/DraftSortOption.swift`

## Files to Modify

1. `FocusOS/Views/Areas/UnifiedAreasView.swift`
2. `FocusOS/Views/Notes/UnifiedNotesView.swift`
3. `FocusOS/Views/Inbox/InboxView.swift`
4. `FocusOS/Views/Resources/UnifiedResourcesView.swift`
5. `FocusOS/Views/Journal/UnifiedJournalView.swift`
6. `FocusOS/Views/Drafts/UnifiedDraftsView.swift`

## Additional Filter Components (Optional)

Consider creating reusable filter components for:
- Multi-select tag picker
- Date range picker
- Range slider (for word count, stability score)
- Dropdown selectors (for projects, areas, types)