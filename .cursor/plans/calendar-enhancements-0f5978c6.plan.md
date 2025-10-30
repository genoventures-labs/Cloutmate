<!-- 0f5978c6-5b4d-4386-a455-15ff34cea308 520bb524-9bec-411e-8f96-26a861ea0d32 -->
# Calendar Tab Enhancements

## 1. Double-Click to Schedule Posts on Future Dates

### CalendarView.swift

- Pass a binding for `showingComposer` and `prefilledDate` from `CalendarView` to both child views
- Add state variables for composer presentation with optional pre-filled date

### MonthlyCalendarView.swift

- Add `@State` for `showingComposer: Bool` and `prefilledScheduleDate: Date?`
- Add `.sheet` modifier to present `ComposerWindow(prefilledDate: prefilledScheduleDate)`
- Modify `CalendarDayCell` to accept `onDoubleClick: (Date) -> Void` callback
- Add `.onTapGesture(count: 2)` to `CalendarDayCell` that:
- Checks if date is in the future (`date > Date()`)
- If future date, triggers callback to open composer with that date
- If past date, does nothing

### WeeklyCalendarView.swift

- Add same composer presentation logic as monthly view
- Modify `DayColumn` to accept `onDoubleClick: (Date) -> Void` callback
- Add double-tap detection on the day header area (not on existing posts)
- Same future date validation

### ComposerWindow.swift

- Add optional `prefilledDate: Date?` parameter to initializer
- In `.onAppear`, if `prefilledDate` is provided:
- Set `isScheduled = true`
- Set `scheduledDate = prefilledDate`

## 2. Post Preview Modal with Edit/Delete

### Create New File: PostPreviewSheet.swift

- Create `PostPreviewSheet` view that accepts a `Post` binding
- Display post details in read-only format:
- Caption in scrollable text view
- Platform badges with icons
- Scheduled date/time (formatted nicely)
- Post status with appropriate color
- Tags list
- Media attachments (if any) in scrollable horizontal stack
- Engagement metrics if published (likes, comments, reach, etc.)
- Action buttons at bottom:
- "Edit" button: opens `ComposerWindow` pre-filled with post data
- "Delete" button: shows confirmation alert, then deletes post from model context
- "Close" button to dismiss sheet
- Use similar styling to `ComposerWindow` with Form and Sections

### MonthlyCalendarView.swift

- Add `@State` for `selectedPost: Post?` and `showingPostPreview: Bool`
- Add `.sheet(isPresented: $showingPostPreview)` for `PostPreviewSheet`
- Modify `CalendarDayCell` to show post count/indicators but make them clickable
- Pass `onPostClick: (Post) -> Void` callback to cell
- When post clicked in cell, set `selectedPost` and present sheet

### WeeklyCalendarView.swift

- Add same post preview presentation logic
- Modify `PostCard` to be tappable (add `.onTapGesture`)
- Pass `onPostClick` callback from parent

### ComposerWindow.swift

- Add optional `existingPost: Post?` parameter for editing
- In `.onAppear`, if `existingPost` is provided, pre-fill all fields from post data
- Update `savePost()` to update existing post instead of creating new one if editing

## 3. Enhanced UI Styling

### MonthlyCalendarView.swift

**Calendar Grid:**

- Add subtle background gradient to calendar container
- Increase cell padding and spacing for better breathing room
- Add hover effects to cells with scale animation
- Enhance `CalendarDayCell` styling:
- Add subtle shadow to non-empty date cells
- Gradient backgrounds for today/selected states
- Smooth corner radius (increased to 12)
- Better color contrast for current month vs other months
- Animated transitions when selecting dates

**Post Indicators:**

- Larger, more visible platform icons
- Add subtle glow effect to post indicators
- Animated appearance for post counts

### WeeklyCalendarView.swift

**Header:**

- Add gradient background to week header
- Larger, bolder date range text
- Enhanced navigation buttons with hover effects

**Day Columns:**

- Card-style design with shadows and borders
- Gradient backgrounds for selected days
- Better visual separation between days

**Post Cards:**

- Enhanced `PostCard` styling:
- Glassmorphic background effect
- Larger corner radius (12)
- Hover effect with slight elevation
- Better platform badge visibility
- Time badge with gradient background
- Smooth shadow effects

### Shared Improvements

- Add animation modifiers for smooth transitions
- Use SF Symbols with better sizing
- Consistent spacing using multiples of 4/8
- Enhanced color palette with opacity variations
- Add `.hoverEffect()` where applicable for macOS

### To-dos

- [ ] Update ComposerWindow to accept optional prefilledDate and existingPost parameters for pre-filling fields
- [ ] Create PostPreviewSheet view with post details display and edit/delete actions
- [ ] Add double-click handler to MonthlyCalendarView cells to open composer for future dates
- [ ] Add post click handler to MonthlyCalendarView to show post preview sheet
- [ ] Add double-click handler to WeeklyCalendarView day columns to open composer for future dates
- [ ] Add post click handler to WeeklyCalendarView cards to show post preview sheet
- [ ] Apply modern UI enhancements to MonthlyCalendarView (gradients, shadows, animations, hover effects)
- [ ] Apply modern UI enhancements to WeeklyCalendarView (gradients, shadows, animations, hover effects)