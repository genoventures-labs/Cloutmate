<!-- 057c8ba2-1976-4a12-b879-b00c5f25368a b5888b84-ab30-4258-aadd-7d262626b331 -->
# Notion Integration Completion & Aurora Integration

## Overview

Verify and fix the Notion integration to ensure it's fully functional, properly wired, integrated with Aurora's knowledge base, and displays database names correctly.

## Issues Identified

1. **Database Name Display Issue**: `NotionDatabaseSelectorView` may not display database names because `database.title` is optional and extraction logic may fail
2. **Aurora Integration Missing**: Notion database information is not included in `AppContextService` context building
3. **Import Flow Not Complete**: The database selector view doesn't actually trigger imports after mapping
4. **Token Management**: Need to verify KeychainService integration is correct

## Implementation Steps

### 1. Fix Database Name Display (`NotionDatabaseSelectorView.swift`)

- Improve database title extraction to handle cases where `title` array is empty or nil
- Add fallback to use database ID or URL if title unavailable
- Extract title properly from `NotionRichText` array
- Add debug logging to track title extraction

### 2. Complete Import Flow (`NotionDatabaseSelectorView.swift`)

- Wire up `importSelectedDatabases()` to actually call `NotionSyncService`
- Pass `accessToken` and `modelContext` to sync service
- Handle import completion with success/error states
- Show progress during import
- Dismiss selector after successful import

### 3. Add Notion Context to Aurora (`AppContextService.swift`)

- Add section for Notion integration status
- Include connected databases count and types
- List active sync configurations with last sync times
- Add database titles and FocusOS type mappings
- Include sync status (active/paused) and sync intervals

### 4. Verify KeychainService Integration

- Check that `NotionIntegrationSection` properly uses `KeychainService.shared.getToken()`
- Ensure token is stored correctly after OAuth
- Verify token retrieval works for database operations

### 5. Error Handling & Logging

- Add comprehensive error handling for OAuth failures
- Log database fetch errors
- Handle API rate limits and token expiration
- Provide user-friendly error messages

### 6. Testing & Verification

- Verify OAuth flow completes successfully
- Test database list loads with proper names
- Confirm import creates correct FocusOS models
- Verify Aurora receives Notion context in AI payloads
- Test sync configuration persistence

## Files to Modify

1. `FocusOS/Views/Notion/NotionDatabaseSelectorView.swift`

- Fix database title extraction
- Complete import flow wiring
- Add error handling

2. `FocusOS/Services/AppContextService.swift`

- Add Notion integration section to context
- Include database sync information

3. `FocusOS/Views/Settings/NotionIntegrationSection.swift`

- Verify KeychainService usage
- Ensure token is properly loaded on view appear

4. `FocusOS/Services/NotionSyncService.swift`

- Verify import completion properly saves config
- Ensure database title is extracted and stored

## Expected Outcomes

- Database names display correctly in selector view
- Import flow completes successfully with proper feedback
- Aurora receives Notion database information in context payloads
- All OAuth and API operations handle errors gracefully
- Sync configurations persist correctly