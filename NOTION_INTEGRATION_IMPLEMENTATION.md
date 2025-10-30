# Notion Integration Implementation Summary

## Overview
Successfully implemented Notion OAuth integration for Cloutmate, allowing users to import and sync their databases (projects, tasks, notes, areas) from Notion into the app with intelligent property mapping and relationship preservation.

## Implementation Status

### ✅ Completed Components

#### 1. Core Services
- **NotionService.swift** - OAuth flow and Notion API client
  - OAuth 2.0 authentication
  - Token exchange and refresh
  - Database search and querying
  - Page retrieval
  
- **NotionSyncService.swift** - Data import and conversion
  - Import Notion pages as Projects, Tasks, Notes, or Areas
  - Property mapping and conversion
  - Status/priority mapping
  - Date handling
  - Smart string extraction
  - Relationship building (projects ↔ tasks ↔ notes)

#### 2. Data Models
- **NotionModels.swift** - Complete Notion API response models
  - NotionDatabase, NotionPage, NotionProperty structures
  - Property value handling (title, text, select, relation, etc.)
  - Rich text parsing
  - Comprehensive error handling

- **NotionSyncConfig.swift** - Sync configuration model
  - Stored sync settings per database
  - Property mappings
  - Sync intervals (hourly/daily)
  - Last sync timestamps
  - Active/inactive toggles

#### 3. UI Components
- **NotionMappingSheet.swift** - Property mapping interface
  - Smart auto-matching by property name
  - User-editable mappings
  - Preview of mappings
  - Field selection interface

- **NotionDatabaseSelectorView.swift** - Database selection
  - List of user's Notion databases
  - Multi-select for batch import
  - Auto-detection of Cloutmate type
  - Configure and import actions

- **NotionIntegrationSection.swift** - Settings integration
  - Connect/disconnect Notion account
  - View active syncs
  - Manual sync trigger
  - Sync status indicators
  - Database management

#### 4. Background Sync
- **Note**: Background periodic sync is not yet implemented in the helper app
- Manual sync can be triggered from Settings
- Future enhancement: Add NotionSyncScheduler to CloutmateHelper target

#### 5. Infrastructure Updates
- **Logger.swift** - Added notion category
- **CloutmateApp.swift** - Added NotionSyncConfig to schema
- **SettingsView.swift** - Integrated Notion settings section

## Key Features

### Smart Property Matching
Automatically matches Notion properties to Cloutmate fields based on:
- Property names (e.g., "Name" → title, "Due Date" → dueDate)
- Property types
- Context (project vs task vs note)

### Relationship Handling
- Tasks automatically linked to their parent projects
- Notes linked to projects and areas
- Bidirectional relationship updates
- Handles Notion relation properties

### Sync Configuration
- Per-database sync settings
- Configurable sync intervals (hourly, daily, or custom)
- Enable/disable auto-sync
- Track last sync time
- Manual sync triggers

### Periodic Sync
- Background sync service in helper app
- Respects user-configured intervals
- Updates existing items
- Optionally creates new items
- Optionally deletes removed Notion items

## Required Configuration

### Info.plist Keys
Create a Notion OAuth integration to get your Client ID and Client Secret.

Add these keys to your app's Info.plist:
```xml
<key>NotionOAuthClientId</key>
<string>your_notion_oauth_client_id</string>

<key>NotionOAuthClientSecret</key>
<string>your_notion_oauth_client_secret</string>
```

Or set environment variables:
- `NotionOAuthClientId`
- `NotionOAuthClientSecret`

**Note:** OAuth credentials (Client ID and Client Secret) are used for user workspace connections. Make sure to configure the redirect URI (`https://oauth.kosmicapps.com/auth/callback`) in your Notion OAuth app settings.

### Redirect URI
The app uses the same callback URI as Facebook/Meta:
- **Production**: `https://oauth.kosmicapps.com/auth/callback`
- Your server handles routing based on the `state` parameter prefix
- Notion uses the prefix `notion:` in the state parameter for routing

## Usage Flow

### 1. Connect to Notion
1. User goes to Settings → Notion Integration
2. Clicks "Connect Notion"
3. OAuth flow opens in browser
4. User authorizes access
5. Returns to app with access token

### 2. Import Databases
1. User sees list of their Notion databases
2. Selects databases to import
3. For each database:
   - Auto-detects Cloutmate type (Project/Task/Note/Area)
   - Shows property mapping sheet
   - Smart matching pre-filled
   - User adjusts mappings as needed
   - Confirms import

### 3. Automatic Sync
- Helper app runs periodic syncs
- Respects configured intervals
- Updates existing items
- Shows last sync time in settings

### 4. Manual Management
- Users can pause/resume syncs
- Trigger manual syncs
- Remove databases
- Adjust sync settings

## Property Mapping Examples

### Projects
- Notion: "Name" → Cloutmate: `title`
- Notion: "Status" (select) → Cloutmate: `statusRaw`
- Notion: "Goal" (text) → Cloutmate: `goal`
- Notion: "Due Date" → Cloutmate: `dueDate`
- Notion: "Tags" (multi-select) → Cloutmate: `tags`

### Tasks
- Notion: "Task" → Cloutmate: `title`
- Notion: "Project" (relation) → Cloutmate: `projectId`
- Notion: "Status" → Cloutmate: `statusRaw`
- Notion: "Priority" → Cloutmate: `priorityRaw`
- Notion: "Notes" (text) → Cloutmate: `notes`
- Notion: "Due Date" → Cloutmate: `dueDate`

### Status Mapping
- Notion "active" → Cloutmate `active`
- Notion "in progress" → Cloutmate `inProgress`
- Notion "done" → Cloutmate `done`
- Case-insensitive matching

## Architecture Notes

### Import Process
1. Fetch Notion database structure
2. Query all pages from database
3. Convert each page to Cloutmate model based on mappings
4. Build relationships after all items imported
5. Save sync configuration

### Relationship Building
- Tracks imported items by Notion page ID
- Looks for relation properties in property mappings
- Links tasks to projects
- Updates project's taskIds array
- Handles formula/rollup properties

### Error Handling
- Network errors logged
- API errors with details
- Invalid property types handled gracefully
- Missing mappings default to empty

## Future Enhancements

Potential improvements for future iterations:
1. Two-way sync (push changes back to Notion)
2. Real-time sync via Notion webhooks
3. Conflict resolution for concurrent edits
4. More granular sync options (specific properties)
5. Sync history and logs
6. Batch import/export
7. Template-based mappings
8. Support for Notion database templates

## Files Created/Modified

### New Files
- `Cloutmate/Services/NotionService.swift`
- `Cloutmate/Services/NotionSyncService.swift`
- `Cloutmate/Models/NotionModels.swift`
- `Cloutmate/Models/NotionSyncConfig.swift`
- `Cloutmate/Views/Notion/NotionMappingSheet.swift`
- `Cloutmate/Views/Notion/NotionDatabaseSelectorView.swift`
- `Cloutmate/Views/Settings/NotionIntegrationSection.swift`
- `CloutmateHelper/NotionSyncScheduler.swift`

### Modified Files
- `Cloutmate/Utilities/Logger.swift` - Added notion logger
- `Cloutmate/CloutmateApp.swift` - Added NotionSyncConfig to schema
- `Cloutmate/Views/Settings/SettingsView.swift` - Added Notion integration section

## Testing Checklist

- [ ] OAuth flow completes successfully
- [ ] Database list loads correctly
- [ ] Property mappings work accurately
- [ ] Imports create correct Cloutmate models
- [ ] Relationships are properly established
- [ ] Periodic sync runs on schedule
- [ ] Manual sync works
- [ ] Settings UI displays correctly
- [ ] Connect/disconnect works
- [ ] Error handling works gracefully

## Dependencies

- Notion OAuth API
- Notion REST API v1
- SwiftData for persistence
- URLSession for networking
- Keychain for secure token storage

