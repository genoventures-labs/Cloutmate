<!-- 9131076a-09fb-497f-a605-b5688760b32a 0c2f5f65-c6ba-42d6-a439-c8f3bae2a355 -->
# Fix Auto Layout Constraint Conflicts

## Problem Analysis

The constraint conflicts are occurring in split views where SwiftUI is creating conflicting horizontal spacing constraints:

- `H:|-(208)-[NSLayoutGuide]` conflicts with `H:|-(0)-[NSLayoutGuide]`
- This happens in `HSplitView` (DraftsView) and `NavigationSplitView` (MainWindowView, TemplateManagementView)

## Root Cause

Multiple `.frame()` modifiers and implicit constraints from SwiftUI's layout system are creating conflicting requirements. The system is auto-recovering but generating warnings.

## Files to Fix

### 1. **DraftsView.swift** (Line 23-50)

**Issue**: `HSplitView` with multiple frame modifiers creating conflicts

- Line 33: `.frame(minWidth: 380, idealWidth: 420)` on sidebar
- Line 47: `.frame(minWidth: 500)` on editor
- Line 49: `.frame(minWidth: 900, idealWidth: 1000)` on entire HSplitView
- Line 50: `.fixedSize(horizontal: false, vertical: false)` potentially conflicting

**Fix**: Simplify frame constraints, remove redundant `.fixedSize()`, ensure only minimum widths are set on split view panes

### 2. **MainWindowView.swift** (Line 36-41)

**Issue**: `NavigationSplitView` with column width constraints

- Line 38: `.navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)`

**Fix**: This is actually correct. The issue might be coming from child views (DraftsView when it's shown). No change needed here.

### 3. **TemplateManagementView.swift** (Line 21-62)

**Issue**: `NavigationSplitView` with multiple frame modifiers

- Line 38: `.frame(minWidth: 300, idealWidth: 350)` on sidebar
- Line 62: `.frame(minWidth: 600, idealWidth: 800)` on entire view

**Fix**: Remove the frame on the entire view, let the sheet handle sizing

## Implementation Strategy

1. **DraftsView**: Remove the outer frame and fixedSize constraints on HSplitView
2. **TemplateManagementView**: Remove the frame on the entire NavigationSplitView
3. Test to ensure split views still behave correctly with drag resizing

## Changes to Make

### DraftsView.swift

- Remove line 49: `.frame(minWidth: 900, idealWidth: 1000)`
- Remove line 50: `.fixedSize(horizontal: false, vertical: false)`
- Keep individual pane min widths (they're fine)

### TemplateManagementView.swift

- Remove line 62: `.frame(minWidth: 600, idealWidth: 800)`
- The sheet presentation in DraftsView.swift line 76 already specifies frame, so the inner view doesn't need it