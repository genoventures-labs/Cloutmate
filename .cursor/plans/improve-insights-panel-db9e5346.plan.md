<!-- db9e5346-fbdc-48f9-87f7-a0cf8cdbdc04 9335e913-ca17-4ff3-82c0-5050180d10a2 -->
# Improve Insights Panel

## Overview
Transform the insights panel into a professional, sleek dashboard with modern glass-morphism effects, structured layouts, improved spacing, and enhanced interactivity.

## Key Changes

### 1. Fix Time Range Picker (InsightsView.swift)
- Replace the cramped segmented picker with a custom styled picker
- Add proper spacing and larger touch targets
- Implement modern button-style segments with smooth transitions
- Increase width and add better visual hierarchy

### 2. Enhanced Metric Cards (InsightsView.swift - MetricCard)
- Add glass-morphism effects with subtle blur and shadows
- Implement hover states with scale animations
- Add trend indicators (up/down arrows with percentages)
- Improve typography with better spacing and hierarchy
- Add subtle gradient backgrounds
- Include smooth transitions on value changes

### 3. Professional Layout Structure
- Add card containers with proper borders and dividers
- Increase spacing between sections (32-40pt instead of 24pt)
- Implement consistent padding and margins throughout
- Add section headers with refined styling
- Group related elements with visual separators

### 4. Performance Chart Improvements (PerformanceChart.swift)
- Add gradient fill under the line chart
- Implement chart legends with platform colors
- Add grid lines for better readability
- Include data point markers on hover
- Smooth line interpolation
- Better axis labeling with formatted values

### 5. Platform Comparison Enhancement (PlatformComparisonView.swift)
- Fix StatRow layout with proper spacing
- Add visual separators between stats
- Implement mini bar charts for quick visual comparison
- Add hover effects on platform cards
- Better color coding and iconography
- Include percentage comparisons between platforms

### 6. Reflection Summary Styling (ReflectionSummary.swift)
- Redesign with card-based layout
- Add icon indicators for insights
- Better typography with increased line height
- Implement accordion/expandable sections for detailed insights
- Add subtle background gradients

### 7. Interactive Enhancements (All Components)
- Add smooth fade-in animations on load
- Implement loading skeletons during refresh
- Add micro-interactions on hover and click
- Smooth number count-up animations for metrics
- Refresh button with rotation animation

### 8. Data Visualization Polish
- Add empty state illustrations when no data
- Implement tooltips on chart hover
- Add export/share capabilities styling
- Better color palette for accessibility
- Consistent icon usage throughout

## Files to Modify
- `FocusOS/Views/Insights/InsightsView.swift` - Main layout, picker, metric cards
- `FocusOS/Views/Insights/PerformanceChart.swift` - Chart styling and interactivity
- `FocusOS/Views/Insights/PlatformComparisonView.swift` - Platform cards and stats
- `FocusOS/Views/Insights/ReflectionSummary.swift` - Summary card design


### To-dos

- [ ] Redesign time range picker with custom styled buttons and proper spacing
- [ ] Add glass-morphism effects, hover states, and animations to metric cards
- [ ] Restructure overall layout with better spacing, borders, and dividers
- [ ] Add gradients, legends, grid lines, and hover interactions to performance chart
- [ ] Fix StatRow spacing and add visual enhancements to platform cards
- [ ] Improve reflection summary with better typography and card design
- [ ] Implement smooth animations and micro-interactions throughout