<!-- 16bbe53c-8b1d-47e9-93bb-0f98f8e36c58 63fe91c2-dbd5-4b0f-8f54-d8f64a7d88f0 -->
# Fix Button Interactions Across App

## Problem Analysis

Buttons stopped working after OAuth fixes because each view creates its own `ComposerViewModel` instance instead of sharing the one in `MainWindowView` that has the sheet attached. When views call `composerViewModel.present()`, they set `isPresented = true` on their local instance, not the one controlling the sheet in `MainWindowView`.

## Solution

Replace the shared `ComposerViewModel` pattern with local `@State` variables in each view that needs a composer sheet. This is the approach already working in `DashboardView`.

## Files to Fix

### 1. **Cloutmate/Views/List/ListTableView.swift**

- Remove `@State private var composerViewModel = ComposerViewModel()`
- Add `@State private var showComposer = false`
- Change button action from `composerViewModel.present()` to `showComposer = true`
- Change `.sheet(isPresented: $composerViewModel.isPresented)` to `.sheet(isPresented: $showComposer)`

### 2. **Cloutmate/Views/Drafts/DraftsView.swift**

- Check if it uses ComposerViewModel
- If yes, apply same fix as ListTableView

### 3. **Cloutmate/Views/MainWindowView.swift**

- Keep the ComposerViewModel for NotificationCenter integration (Cmd+N shortcut)
- This instance handles keyboard shortcuts and sidebar button
- No changes needed here

### 4. **Cloutmate/Views/Sidebar.swift**

- This receives composerViewModel from MainWindowView as a parameter - correct approach
- No changes needed

### 5. **Cloutmate/Views/Settings/AccountsSection.swift**

- OAuth buttons don't use ComposerViewModel
- They use local `@State private var isAuthenticating`
- Verify buttons work after other fixes

## Implementation Steps

1. Fix ListTableView composer button
2. Fix DraftsView if needed
3. Test all "New Post" buttons across tabs
4. Test Settings OAuth buttons
5. Verify keyboard shortcuts still work (Cmd+N)
6. Verify sidebar "New Post" button works

## Expected Outcome

- All "New Post" buttons will open the ComposerWindow sheet
- Settings OAuth buttons will trigger authentication flow
- No shared state conflicts between views
- Each view manages its own modal presentation

## Technical Notes

- `@Observable` with `@State` works within a single view
- Passing `ComposerViewModel` as a parameter (Sidebar) works
- Creating separate instances in child views breaks sheet presentation
- Local `@State` bool is simpler and more reliable for view-specific sheets