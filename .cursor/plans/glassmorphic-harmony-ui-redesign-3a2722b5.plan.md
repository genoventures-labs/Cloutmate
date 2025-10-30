<!-- 3a2722b5-563a-4b25-8e38-75492e05274e 340dc01f-4d51-4b98-b7f8-831351e7f0b1 -->
# Enhanced Features Implementation

## 1. Drafts Tab Enhancements

### 1.1 Draft Lifecycle Management
Update `Draft.swift` model to track conversion state:
- Add `associatedPostID: UUID?` to link draft to created post
- Add `convertedAt: Date?` to track when converted
- Add `scheduledOrPublishedDate: Date?` for display in tag

### 1.2 Post-Conversion Confirmation Dialog
Create `DraftConversionAlert.swift` component:
- Show confirmation alert after composer saves post
- "You've scheduled/published this post. Remove draft?"
- Options: "Keep Draft" or "Remove"
- If kept, update draft with conversion metadata

Update `ComposerWindow.swift`:
- Add completion callback parameter to notify when post is saved
- Pass back post status (scheduled/published) and date
- Trigger confirmation dialog in DraftsView

### 1.3 Auto-Clean Preference
Update `DraftsView.swift`:
- Add UserDefaults key `autoCleanDrafts` (default: false)
- Add toggle in toolbar with info icon popover
- Info text: "Automatically removes drafts after they've been scheduled or published"
- When enabled, skip confirmation and delete draft immediately

### 1.4 Draft Status Tags
Update `DraftRow.swift` in `DraftsView.swift`:
- Replace "Ready/Empty" tags with dynamic status
- Show "Scheduled [date]" or "Published [date]" tag for converted drafts
- Format: "Scheduled 12/25 3pm" using short date/time
- Use blue color for scheduled, green for published
- Keep draft editable and allow re-conversion

### 1.5 Archive Functionality
Create separate "Active" and "Archive" sections:
- When user chooses to keep draft, move to "Archive" section
- Archive section collapsible, below active drafts
- Archive drafts show full conversion history in expanded view

## 2. Lists Tab Enhancements

### 2.1 Functional Delete Operations
Update `ListTableView.swift`:
- Add "Delete All" button in toolbar (only appears when posts exist)
- Show confirmation alert: "Clear all X posts from list?"
- Delete all filtered posts based on current search/filters
- Add individual delete button in row context menu or swipe action

### 2.2 Enhanced Column Functionality
Make all table columns sortable and interactive:
- Add `.defaultSortOrder` to each TableColumn
- Caption column: clickable to open post detail sheet
- Platform column: clickable chips filter by that platform
- Status column: clickable badge filters by status
- Scheduled column: sortable by date
- Engagement column: sortable by rate

### 2.3 Bulk Actions Menu
Expand the existing "Actions" menu:
- Export (existing)
- Delete (existing - rename to "Delete Selected")
- Archive (existing)
- Add: "Reschedule Selected" - batch reschedule dialog
- Add: "Duplicate Selected" - create copies

### 2.4 Draft Posts Integration
Drafts already appear with `.draft` status:
- Ensure drafts with `associatedPostID` are properly linked
- Show "(from draft)" indicator in caption column
- Add action: "Edit in Drafts" for draft-status posts

## 3. Insights Tab Data Validation

### 3.1 Engagement Metrics Validation
Update `InsightsView.swift`:
- Check if posts have null/undefined engagement data
- Show info banner at top if > 50% posts lack metrics
- Banner: "Limited data available. Connect platforms to see full insights."
- Gracefully handle zero/null values in all calculations

### 3.2 Chart Data Validation
All chart components already have empty states (implemented):
- `EngagementTrendsChart.swift` - validates `sortedPosts`
- `PlatformComparisonChart.swift` - validates chart data
- `ContentPerformanceChart.swift` - validates chart data
- Ensure computed metrics handle edge cases (divide by zero, empty arrays)

### 3.3 Metric Card Fallbacks
Update metric calculations in `InsightsView.swift`:
- For all computed properties (avgEngagement, bestPostingHour, etc.)
- Return "N/A" or "--" instead of "0.0%" when no data
- Show "Collecting data..." for newly connected accounts

## 4. Calendar Tab Post Visualization

### 4.1 Enhanced Day Cell Indicators
Update `GlassCalendarDayCell.swift`:
- Currently shows 3 colored dots for posts
- Add count badge overlay if > 3 posts: "+X" badge
- Position badge in top-right corner of cell
- Use glassmorphic badge with blur background

### 4.2 Published Posts Indicators
Update `indicatorColor(for post: Post)` in `GlassCalendarDayCell.swift`:
- Currently handles scheduled/published/failed posts
- Add visual distinction for published vs scheduled
- Published: solid green circle with checkmark icon
- Scheduled: outlined blue circle with clock icon
- Use SF Symbols for icons at small scale

### 4.3 Post List Modal
Create new `CalendarPostListSheet.swift`:
- Modal sheet triggered by clicking date cell
- Show all posts for selected date
- Group posts by platform (Threads, Facebook sections)
- Each platform section shows posts in chronological order
- Display: time, caption preview (1 line), status badge, engagement if available
- Actions: tap to open full post preview, long-press for quick actions

### 4.4 Calendar Integration
Update `MonthlyCalendarView.swift` and `WeeklyCalendarView.swift`:
- Add single-click handler to show post list sheet
- Pass selected date and filtered posts to sheet
- Keep existing double-click behavior for creating new post
- Sheet includes published posts (not just scheduled)

Update `CalendarView.swift`:
- Query posts with both `scheduledDate` and `publishedDate`
- Filter logic: show post on scheduled date OR published date
- Update `postsForDate()` to check both date fields

## 5. Glassmorphic Design Consistency

### 5.1 Confirmation Dialogs
All new alerts/dialogs use glassmorphic styling:
- Draft conversion confirmation
- Delete all confirmation
- Use `.alert` with custom button styling
- Match existing glass button styles

### 5.2 Post List Sheet
`CalendarPostListSheet.swift` design:
- Full glassmorphic background with `.ultraThinMaterial`
- Section headers with gradient text (blue to purple)
- Each post row as `GlassCard` with hover effects
- Platform badges with platform colors and glass panel
- Smooth animations for sheet presentation

### 5.3 Archive Section
Draft archive section styling:
- Collapsible header with chevron icon
- Archive icon with muted colors
- Archived drafts use reduced opacity glass panels
- Smooth expand/collapse animation

### 5.4 Info Popovers
Auto-clean toggle info icon:
- Use `.popover` with glass background
- Info icon with SF Symbol: "info.circle"
- Popover content in clean glass panel
- Max width: 250pt for readability

## Implementation Order

1. Draft model updates and conversion tracking
2. Composer callback and draft confirmation dialog
3. Draft status tags and archive section
4. Auto-clean preference toggle
5. Lists delete operations and column interactions
6. Calendar day cell indicators and count badges
7. Calendar post list sheet with platform sections
8. Calendar query updates for published posts
9. Insights data validation and fallbacks
10. Final glassmorphic polish and animations

### To-dos

- [ ] Update Draft model with associatedPostID, convertedAt, and scheduledOrPublishedDate fields
- [ ] Add completion callback to ComposerWindow to notify when post is saved with status and date
- [ ] Create DraftConversionAlert component and integrate into DraftsView
- [ ] Update DraftRow to show scheduled/published tags with dates for converted drafts
- [ ] Add auto-clean toggle with info popover in DraftsView toolbar
- [ ] Create collapsible Archive section for kept converted drafts in DraftsView
- [ ] Add Delete All button with confirmation and individual row delete actions in ListTableView
- [ ] Make table columns sortable and interactive (clickable filters) in ListTableView
- [ ] Expand Actions menu with Reschedule and Duplicate options in ListTableView
- [ ] Enhance GlassCalendarDayCell with count badges and icon-based status indicators
- [ ] Create CalendarPostListSheet with platform-sectioned post list
- [ ] Update MonthlyCalendarView, WeeklyCalendarView, and CalendarView to show post list on click
- [ ] Add data validation, null checks, and fallback displays in InsightsView
- [ ] Apply glassmorphic styling consistency to all new components and animations