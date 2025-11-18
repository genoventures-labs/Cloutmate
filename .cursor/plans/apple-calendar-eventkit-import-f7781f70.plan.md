<!-- f7781f70-e773-4757-afe7-b851ce894261 93b08e4c-77d7-4cb4-9a08-116533ee062b -->
# Monday.com Integration Implementation

## Overview

Implement Monday.com OAuth 2.0 integration following the same pattern as Todoist and Notion integrations. Import Monday.com boards as FocusOS Projects and items as Tasks, with user-selectable board filtering.

## 1. Add OAuth Credentials to Config.plist

**File:** `FocusOS/Config.plist` (modify)

Add Monday.com OAuth credentials:

- `MondayOAuthClientId` - OAuth client ID from Monday.com Developer Center
- `MondayOAuthClientSecret` - OAuth client secret from Monday.com Developer Center

**Note:** These should be obtained from https://developer.monday.com/apps/docs/the-developer-center after creating a Monday.com app.

## 2. Create MondayModels.swift

**File:** `FocusOS/Services/MondayModels.swift` (new)

Define Codable structs for Monday.com GraphQL API responses:

**Key Models:**

- `MondayBoard` - Board structure (id, name, description, items_count, etc.)
- `MondayItem` - Item structure (id, name, board, column_values, etc.)
- `MondayColumnValue` - Column value structure (id, text, value, type, etc.)
- `MondayUser` - User structure (id, name, email, etc.)
- `MondayGraphQLResponse<T>` - Generic GraphQL response wrapper
- `MondayGraphQLError` - GraphQL error structure
- `MondayTokenResponse` - OAuth token response (access_token, token_type, scope)

**GraphQL Response Format:**

Monday.com uses GraphQL, so responses follow GraphQL structure with `data` and `errors` fields.

## 3. Create MondayService.swift

**File:** `FocusOS/Services/MondayService.swift` (new)

OAuth 2.0 authentication and GraphQL API client:

**Key Properties:**

- `oauthClientId: String` - Load from Config.plist or environment variable
- `oauthClientSecret: String` - Load from Config.plist or environment variable
- `redirectURI: String` - Returns `https://oauth.kosmicapps.com/auth/callback` (server redirects to `focusos://oauth/monday`)
- `baseURL: String` - Monday.com GraphQL API endpoint: `https://api.monday.com/v2`

**Key Methods:**

- `getOAuthURL() -> URL?` - Generate OAuth authorization URL
  - Base URL: `https://auth.monday.com/oauth2/authorize`
  - Required scopes: `boards:read boards:write` (for reading boards and items)
- `exchangeCodeForToken(_ code: String) async throws -> MondayTokenResponse` - Exchange authorization code for access token
  - Token endpoint: `https://auth.monday.com/oauth2/token`
  - Method: POST
  - Tokens do not expire (no refresh token needed)
- `executeGraphQL<T>(_ query: String, variables: [String: Any]?, accessToken: String) async throws -> T` - Execute GraphQL query/mutation
- `getBoards(accessToken: String) async throws -> [MondayBoard]` - Fetch all boards user has access to
- `getBoardItems(boardId: String, accessToken: String) async throws -> [MondayItem]` - Fetch items from a specific board
- `getUser(accessToken: String) async throws -> MondayUser` - Fetch current user info

**GraphQL Queries:**

- Boards query: Fetch id, name, description, items_count, board_kind
- Items query: Fetch id, name, column_values (status, date, text fields), board, creator

**OAuth Flow:**

1. User clicks "Connect Monday.com"
2. Open OAuth URL in browser (ASWebAuthenticationSession)
3. User authorizes in Monday.com
4. Callback returns with authorization code
5. Exchange code for access token
6. Store token securely in Keychain

## 4. Create MondayConverter.swift

**File:** `FocusOS/Services/MondayConverter.swift` (new)

Convert Monday.com models to FocusOS models:

**Key Methods:**

- `convertToProject(_ mondayBoard: MondayBoard) -> Project` - Convert Monday.com board to FocusOS Project
  - Map: board.name → project.title
  - Map: board.description → project.goal (if available)
  - Set: externalProjectId = board.id
  - Set: externalSource = "monday"
- `convertToTask(_ mondayItem: MondayBoard, boardId: String) -> Task` - Convert Monday.com item to FocusOS Task
  - Map: item.name → task.title
  - Extract status from column_values (look for status column)
  - Extract due date from column_values (look for date column)
  - Extract priority from column_values (look for priority/urgency column)
  - Extract notes from column_values (look for text/note columns)
  - Set: externalReminderId = item.id
  - Set: externalReminderListId = boardId (to track which board the item belongs to)
  - Set: externalSource = "monday"
- `extractStatus(_ columnValues: [MondayColumnValue]) -> TaskStatus?` - Extract task status from column values
- `extractDueDate(_ columnValues: [MondayColumnValue]) -> Date?` - Extract due date from column values
- `extractPriority(_ columnValues: [MondayColumnValue]) -> TaskPriority?` - Extract priority from column values
- `extractNotes(_ columnValues: [MondayColumnValue]) -> String?` - Extract notes/description from column values
- `updateProject(_ project: Project, from mondayBoard: MondayBoard)` - Update existing Project
- `updateTask(_ task: Task, from mondayItem: MondayItem, boardId: String)` - Update existing Task

**Column Value Mapping:**

Monday.com uses dynamic column values. Need to detect column types:

- Status columns → TaskStatus
- Date columns → Due date
- Text columns → Notes/description
- Priority columns → TaskPriority

## 5. Create MondayImportSettings.swift

**File:** `FocusOS/Services/MondayImportSettings.swift` (new)

User preferences for Monday.com import behavior:

```swift
@MainActor
final class MondayImportSettings: ObservableObject {
    static let shared = MondayImportSettings()
    
    var importEnabled: Bool
    var selectedBoardIds: [String] // Empty = all boards
    var syncInterval: TimeInterval // Default: 15 minutes
    var importCompletedItems: Bool // Default: false
    var lastSyncDate: Date?
    var accessToken: String? // Stored in Keychain
}
```

**Token Storage:** Use KeychainService for secure storage (like Todoist/Notion).

## 6. Create MondayImportService.swift

**File:** `FocusOS/Services/MondayImportService.swift` (new)

Main service for importing and syncing Monday.com data:

**Key Methods:**

- `start(modelContext: ModelContext) async` - Initialize service and start sync
- `stop()` - Stop background sync
- `syncAllBoards(modelContext: ModelContext) async throws` - Sync all selected boards
- `importBoard(_ boardId: String, modelContext: ModelContext) async throws -> NotionImportResult` - Import single board (as Project) and its items (as Tasks)
- `importBoardAsProject(_ board: MondayBoard, modelContext: ModelContext) async throws -> (imported: Bool, project: Project)` - Import board as Project
- `importBoardItems(_ boardId: String, modelContext: ModelContext) async throws -> NotionImportResult` - Import items from board as Tasks
- `observeChanges(modelContext: ModelContext)` - Watch for Monday.com changes (polling)
- `updateItem(_:from:modelContext:)` - Update existing FocusOS item from Monday.com data
- `deleteItem(_:modelContext:)` - Delete FocusOS item if removed from Monday.com

**Import Logic:**

- Fetch all selected boards (or all if none selected)
- For each board:
  - Import board as Project (check for existing by externalProjectId)
  - Fetch all items from board
  - Import items as Tasks (check for existing by externalReminderId)
  - Link tasks to project via externalReminderListId = board.id
- Handle completed items: set status appropriately
- Track external IDs: `externalProjectId` for boards, `externalReminderId` for items, `externalSource = "monday"`

**Duplicate Prevention:**

- Check for existing Projects by `externalProjectId == board.id && externalSource == "monday"`
- Check for existing Tasks by `externalReminderId == item.id && externalSource == "monday"`

## 7. Create MondayImportSettingsView.swift

**File:** `FocusOS/Views/Settings/MondayImportSettingsView.swift` (new)

Settings drawer for Monday.com import configuration:

- Connection status (OAuth token status)
- Board picker: Multi-select from available Monday.com boards
- Sync interval: 15min / 30min / 1hr / manual
- Toggle: Import completed items
- Last sync: Display timestamp
- "Sync Now" button
- "Disconnect" button (revokes token, clears Keychain)

**UI Pattern:** Follow `NotionImportSettingsView.swift` structure.

## 8. Update IntegrationsDrawer.swift

**File:** `FocusOS/Views/Settings/IntegrationsDrawer.swift` (modify)

Add Monday.com section following the same pattern as Notion/Todoist:

**Monday.com Section:**

- Connection status (connected/disconnected based on OAuth token)
- Board selection (multi-select from available boards)
- Sync status indicator (last sync time, sync in progress)
- "Sync Now" button
- Settings button (opens MondayImportSettingsView)

**Connection Flow:**

1. User taps "Connect"
2. Start OAuth flow (ASWebAuthenticationSession)
3. User authorizes in Monday.com
4. Exchange code for tokens
5. Store tokens in Keychain
6. Trigger initial import
7. Start background sync scheduler

**Methods to add:**

- `connectToMonday()` - Start OAuth flow
- `disconnectFromMonday()` - Revoke token, clear Keychain, stop service
- `syncMondayNow()` - Trigger manual sync
- `checkMondayConnectionStatus()` - Check OAuth token status
- `presentMondayIntegrationManager()` - Open settings drawer

**State variables to add:**

- `@ObservedObject private var mondayService = MondayImportService.shared`
- `@ObservedObject private var mondaySettings = MondayImportSettings.shared`
- `@State private var showMondaySettings = false`
- `@State private var mondayIsConnecting = false`
- `@State private var mondayError: String?`
- `@State private var mondaySuccessMessage: String?`

## 9. Background Sync Scheduler

**File:** `FocusOS/Services/MondayImportService.swift` (extend)

Add timer-based sync:

- Use `_Concurrency.Task` for periodic sync
- Respect `syncInterval` setting
- Run sync on background queue
- Update `lastSyncedAt` after successful sync
- Handle errors gracefully (log, don't crash)

## 10. UnifiedCalendarView Integration

**File:** `FocusOS/Views/Calendar/UnifiedCalendarView.swift` (modify)

Initialize import service on appear:

```swift
.task {
    await AppleCalendarImportService.shared.start(modelContext: modelContext)
    await AppleRemindersImportService.shared.start(modelContext: modelContext)
    await TodoistImportService.shared.start(modelContext: modelContext)
    await NotionImportService.shared.start(modelContext: modelContext)
    await MondayImportService.shared.start(modelContext: modelContext)
}
```

## 11. OAuth Configuration

**File:** `FocusOS/Info.plist` (verify)

Ensure OAuth redirect URI is configured:

- OAuth redirect URI: `https://oauth.kosmicapps.com/auth/callback` (must match Monday.com app settings)

**Monday.com Developer Center Setup:**

- Create app in Monday.com Developer Center
- Add redirect URL: `https://oauth.kosmicapps.com/auth/callback`
- Configure OAuth scopes: `boards:read boards:write`
- Get client ID and client secret

## 12. Keychain Integration

**File:** `FocusOS/Services/KeychainService.swift` (verify)

Ensure KeychainService supports Monday.com tokens:

- `storeToken(_:forAccount:)` - Store access token
- `getToken(forAccount:)` - Retrieve access token
- `deleteToken(forAccount:)` - Remove token on disconnect

**Account Keys:**

- `"monday_access_token"`

## Implementation Order

1. Add Monday.com OAuth credentials to Config.plist
2. Create MondayModels.swift with GraphQL response structures
3. Create MondayService.swift with OAuth flow and GraphQL client
4. Create MondayConverter.swift for data transformation
5. Create MondayImportSettings.swift for user preferences
6. Create MondayImportService.swift with import, sync, and change detection
7. Create MondayImportSettingsView.swift for configuration
8. Update IntegrationsDrawer.swift with new Monday.com section
9. Add background sync scheduler
10. Integrate into UnifiedCalendarView
11. Test OAuth flow, import, sync, and error handling

## Testing Considerations

- Test OAuth flow (authorization, token exchange)
- Test with multiple boards
- Test board selection (all vs selected)
- Test items with and without due dates
- Test completed vs incomplete items
- Test priority/status mapping
- Test change detection (edit in Monday.com, verify update in FocusOS)
- Test disconnect flow (revoke token, clear data)
- Verify items appear in appropriate views (tasks in Tasks view, projects in Projects view)
- Verify Aurora prioritization works on imported items
- Test duplicate prevention
- Test relationship linking (tasks to projects via board)

## Key Differences from Other Integrations

- Uses GraphQL API (not REST)
- Boards → Projects, Items → Tasks mapping
- Dynamic column values (need to detect column types)
- OAuth tokens do not expire (no refresh token needed)
- User-selectable boards (like Notion databases)

## GraphQL Query Examples

**Fetch Boards:**

```graphql
query {
  boards {
    id
    name
    description
    items_count
    board_kind
  }
}
```

**Fetch Board Items:**

```graphql
query($boardId: [ID!]) {
  boards(ids: $boardId) {
    items {
      id
      name
      column_values {
        id
        text
        value
        type
      }
    }
  }
}
```

### To-dos

- [x] Add externalEventId, externalCalendarId, externalSource, and lastSyncedAt fields to CalendarEvent model
- [x] Create AppleCalendarEventConverter to convert EKEvent properties (title, dates, recurrence, alarms) to CalendarEvent
- [x] Build AppleCalendarImportService with importEvents, syncAllCalendars, observeCalendarChanges, and update/delete methods
- [x] Create AppleCalendarImportSettings for user preferences (enabled, selected calendars, sync interval, import range)
- [x] Trigger AuroraCalendarCognitionService.analyzeAndColorizeEvents after batch imports and getColorForEvent after single updates
- [x] Replace placeholder Apple Calendar section in IntegrationsDrawer with real connection UI, calendar picker, sync status, and settings button
- [x] Build AppleCalendarImportSettingsView drawer for configuring import settings (calendars, sync interval, import range)
- [x] Implement timer-based background sync scheduler in AppleCalendarImportService respecting syncInterval setting
- [x] Initialize AppleCalendarImportService.start in UnifiedCalendarView.onAppear or .task modifier
- [x] Add NSCalendarsUsageDescription to Info.plist with user-friendly explanation
- [x] 
- [x] Add externalReminderId, externalReminderListId, externalSource, and lastSyncedAt fields to Task model
- [x] Create AppleRemindersEventConverter to convert EKReminder properties (title, notes, dueDate, priority, isCompleted) to Task
- [x] Build AppleRemindersImportService with importReminders, syncAllReminderLists, observeReminderChanges, and update/delete methods
- [x] Create AppleRemindersImportSettings for user preferences (enabled, selected lists, sync interval, import range, import completed)
- [x] Replace placeholder Apple Reminders section in IntegrationsDrawer with real connection UI, reminder list picker, sync status, and settings button
- [x] Build AppleRemindersImportSettingsView drawer for configuring import settings (lists, sync interval, import range, completed toggle)
- [x] Create AppleRemindersPermissionDeniedDrawer with deep-link to System Settings and auto-retry functionality
- [x] Implement timer-based background sync scheduler in AppleRemindersImportService respecting syncInterval setting
- [x] Initialize AppleRemindersImportService.start in UnifiedCalendarView.task modifier
- [x] Add NSRemindersUsageDescription to Info.plist with user-friendly explanation
- [x] Add com.apple.security.personal-information.reminders entitlement to FocusOS.entitlements
- [x] 
- [x] 
- [ ] Add externalEventId, externalCalendarId, externalSource, and lastSyncedAt fields to CalendarEvent model
- [ ] Create AppleCalendarEventConverter to convert EKEvent properties (title, dates, recurrence, alarms) to CalendarEvent
- [ ] Build AppleCalendarImportService with importEvents, syncAllCalendars, observeCalendarChanges, and update/delete methods
- [ ] Create AppleCalendarImportSettings for user preferences (enabled, selected calendars, sync interval, import range)
- [ ] Trigger AuroraCalendarCognitionService.analyzeAndColorizeEvents after batch imports and getColorForEvent after single updates
- [ ] Replace placeholder Apple Calendar section in IntegrationsDrawer with real connection UI, calendar picker, sync status, and settings button
- [ ] Build AppleCalendarImportSettingsView drawer for configuring import settings (calendars, sync interval, import range)
- [ ] Implement timer-based background sync scheduler in AppleCalendarImportService respecting syncInterval setting
- [ ] Initialize AppleCalendarImportService.start in UnifiedCalendarView.onAppear or .task modifier
- [ ] Add NSCalendarsUsageDescription to Info.plist with user-friendly explanation
- [ ] Add externalReminderId, externalReminderListId, externalSource, and lastSyncedAt fields to Task model
- [ ] Create AppleRemindersEventConverter to convert EKReminder properties (title, notes, dueDate, priority, isCompleted) to Task
- [ ] Build AppleRemindersImportService with importReminders, syncAllReminderLists, observeReminderChanges, and update/delete methods
- [ ] Create AppleRemindersImportSettings for user preferences (enabled, selected lists, sync interval, import range, import completed)
- [ ] Replace placeholder Apple Reminders section in IntegrationsDrawer with real connection UI, reminder list picker, sync status, and settings button
- [ ] Build AppleRemindersImportSettingsView drawer for configuring import settings (lists, sync interval, import range, completed toggle)
- [ ] Create AppleRemindersPermissionDeniedDrawer with deep-link to System Settings and auto-retry functionality
- [ ] Implement timer-based background sync scheduler in AppleRemindersImportService respecting syncInterval setting
- [ ] Initialize AppleRemindersImportService.start in UnifiedCalendarView.task modifier
- [ ] Add NSRemindersUsageDescription to Info.plist with user-friendly explanation
- [ ] Add com.apple.security.personal-information.reminders entitlement to FocusOS.entitlements
- [x] Add externalProjectId, externalSource, and lastSyncedAt fields to Project model
- [x] Create TodoistModels.swift with TodoistProject, TodoistTask, TodoistDueDate, TodoistSection, TodoistLabel API response models
- [x] Build TodoistService with OAuth 2.0 flow (getOAuthURL, exchangeCodeForToken, refreshToken) and API client methods (getProjects, getTasks, getSections, getLabels)
- [x] Create TodoistConverter to convert TodoistProject → Project and TodoistTask → Task with priority/status/dueDate mapping
- [x] Build TodoistImportService with importProjects, importTasks, syncAllProjects, observeChanges, and update/delete methods
- [x] Create TodoistImportSettings for user preferences (enabled, selected projects, sync interval, import completed)
- [x] Replace placeholder Todoist section in IntegrationsDrawer with real OAuth connection UI, project picker, sync status, and settings button
- [x] Build TodoistImportSettingsView drawer for configuring import settings (projects, sync interval, completed toggle)
- [x] Implement timer-based background sync scheduler in TodoistImportService respecting syncInterval setting and handling token refresh
- [x] Initialize TodoistImportService.start in UnifiedCalendarView.task modifier
- [x] Ensure focusos:// URL scheme is configured in Info.plist for OAuth callback
- [x] 
- [x] 
- [ ] Delete all old Notion integration files (NotionService, NotionSyncService, NotionModels, NotionSyncConfig, all Notion views/components)
- [ ] Add NotionSwift package dependency to the project (https://swiftpackageindex.com/chojnac/NotionSwift)
- [ ] Create NotionService.swift with OAuth 2.0 flow and NotionSwift API client wrapper (getOAuthURL, exchangeCodeForToken, refreshToken, getDatabases, getPages, getBlocks)
- [ ] Create NotionConverter.swift to convert NotionSwift models to FocusOS models (convertToTask, convertToProject, convertToNote, convertToArea, with type detection and property mapping)
- [ ] Create NotionImportSettings.swift for user preferences (importEnabled, selectedDatabaseIds, syncInterval, importCompletedItems, autoDetectTypes, token management via Keychain)
- [ ] Create NotionImportService.swift with import, sync, and change detection (start, stop, syncAllDatabases, importDatabase, importPages, determinePageType, background sync scheduler)
- [ ] Create NotionImportSettingsView.swift drawer for configuration (database picker, sync interval, import options, sync now button)
- [ ] Update IntegrationsDrawer.swift with new Notion section (connectToNotion, disconnectFromNotion, syncNotionNow, checkNotionConnectionStatus, presentNotionIntegrationManager)
- [ ] Add NotionImportService.start to UnifiedCalendarView.task modifier
- [ ] Remove NotionSyncConfig from SwiftData schema and clean up any old Notion references in AppContextService and other files
- [x] 
- [x] Add NotionSwift package dependency to the project. This requires manual action in Xcode: File > Add Packages > https://github.com/chojnac/NotionSwift (or correct URL from Swift Package Index). Once added, update NotionService.swift and NotionConverter.swift to use actual NotionSwift types instead of placeholders.
- [x] 
- [x] 
- [x] 
- [x] 
- [x] 
- [x] 
- [x] 
- [x] 