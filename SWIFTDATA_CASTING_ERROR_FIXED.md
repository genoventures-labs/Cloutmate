# SwiftData Casting Error - FIXED

## Problem
```
SwiftData/ModelContext.swift:712: Fatal error: Failed to cast model FocusOS.Draft for PersistentIdentifier(...) to Draft.
```

## Root Causes Identified

### 1. **Incorrect Module Reference for Draft Model**
- **Issue**: `FocusOSApp.swift` referenced `FocusOSShared.Draft.self` in the schema
- **Reality**: `Draft` model is defined in `FocusOS/Models/Draft.swift` (main app module, not FocusOSShared)
- **Fix**: Changed to `Draft.self` without the `FocusOSShared.` prefix

### 2. **Multiple Models Missing from Schema**
The following SwiftData models were being used with `@Query` or `FetchDescriptor` but were NOT included in the model container schema:
- `Area` - Used in AreasView, ProjectsView, TasksView, etc.
- `InsightSnapshot` - Used in ProjectInsightsView, AppContextService
- `Journal` - Used in JournalView
- `Campaign` - Used in CampaignView
- `NotionSyncConfig` - Used in NotionIntegrationSection
- `PARATemplate` - Used in AppContextService, QuickCaptureView, TemplateLibraryView

**Impact**: When SwiftData tried to fetch these models, it couldn't find them in the schema, causing casting failures.

### 3. **Duplicate Model Files**
Many models existed in both `FocusOS/Models/` and `FocusOSShared/Models/`, causing type identity conflicts:

**Removed Duplicates (Shared models - kept in FocusOSShared):**
- ✅ `Note.swift` - Deleted from main app, using `FocusOSShared.Note`
- ✅ `Task.swift` - Deleted from main app, using `FocusOSShared.Task`
- ✅ `Project.swift` - Deleted from main app, using `FocusOSShared.Project`
- ✅ `InboxItem.swift` - Deleted from main app, using `FocusOSShared.InboxItem`

**Removed Duplicates (App-local models - kept in main app):**
- ✅ `Area.swift` - Deleted from FocusOSShared (not used by Widget/MenuBar)
- ✅ `AIMessage.swift` - Deleted from FocusOSShared (main app has emotion tracking)
- ✅ `AISettings.swift` - Deleted from FocusOSShared (not a SwiftData model, app-local singleton)
- ✅ `InsightSnapshot.swift` - Deleted from FocusOSShared (app-local only)
- ✅ `PlatformAIConfiguration.swift` - Deleted from FocusOSShared (app-local, has AITool support)
- ✅ `Platform+UI.swift` - Deleted from FocusOSShared (app-local extension)

## Complete Schema Fix

### Updated `FocusOSApp.swift` Schema:
```swift
let schema = Schema([
    // Shared models used in the app (publicly accessible)
    FocusOSShared.Post.self,
    Draft.self,  // ✅ FIXED: Was incorrectly FocusOSShared.Draft.self
    FocusOSShared.Template.self,
    FocusOSShared.PlatformAccount.self,
    FocusOSShared.PerformancePrediction.self,
    FocusOSShared.RecyclablePost.self,
    FocusOSShared.ContentTopic.self,
    FocusOSShared.ContentBalance.self,
    FocusOSShared.PostingTimeTest.self,
    FocusOSShared.OptimalPostingTime.self,
    FocusOSShared.CustomPostProperty.self,
    FocusOSShared.PostView.self,
    FocusOSShared.HashtagPerformance.self,
    FocusOSShared.HashtagSet.self,
    // Shared PARA models (used by dashboard cards and other features)
    FocusOSShared.Note.self,  // ✅ FIXED: Now properly namespaced
    FocusOSShared.Task.self,  // ✅ FIXED: Now properly namespaced
    FocusOSShared.Project.self,  // ✅ FIXED: Now properly namespaced
    FocusOSShared.InboxItem.self,  // ✅ FIXED: Now properly namespaced
    // App-local PARA models
    Area.self,  // ✅ ADDED: Was missing from schema
    // App-specific models
    DashboardCard.self,
    AIMessage.self,
    AIConversation.self,
    UserPreferences.self,
    InsightSnapshot.self,  // ✅ ADDED: Was missing from schema
    Journal.self,  // ✅ ADDED: Was missing from schema
    Campaign.self,  // ✅ ADDED: Was missing from schema
    NotionSyncConfig.self,  // ✅ ADDED: Was missing from schema
    PARATemplate.self  // ✅ ADDED: Was missing from schema
])
```

## Impact of Fixes

### Before:
- ❌ SwiftData couldn't cast models due to incorrect module references
- ❌ Multiple models missing from schema causing query failures
- ❌ Duplicate model definitions causing type identity conflicts
- ❌ Views using `@Query` would fail to fetch data
- ❌ Migration service couldn't create Area records

### After:
- ✅ All models correctly namespaced with proper module references
- ✅ All active SwiftData models included in schema
- ✅ No duplicate model definitions
- ✅ Type identity properly resolved across the app
- ✅ `FocusOS_v3.sqlite` will be recreated with correct schema

## Files Modified
1. `/FocusOS/FocusOSApp.swift` - Fixed schema with proper model references

## Files Deleted (Duplicates)
1. `/FocusOSShared/Models/Area.swift`
2. `/FocusOSShared/Models/AIMessage.swift`
3. `/FocusOSShared/Models/AISettings.swift`
4. `/FocusOSShared/Models/InsightSnapshot.swift`
5. `/FocusOSShared/Models/PlatformAIConfiguration.swift`
6. `/FocusOSShared/Models/Platform+UI.swift`
7. `/FocusOS/Models/Note.swift`
8. `/FocusOS/Models/Task.swift`
9. `/FocusOS/Models/Project.swift`
10. `/FocusOS/Models/InboxItem.swift`

## Testing Recommendations
1. **Clean build** the project to ensure all references resolve correctly
2. **Delete the app** from simulator/device to force fresh database creation
3. **Test key views** that use SwiftData queries:
   - DraftsView (Draft queries)
   - AreasView (Area queries)
   - ProjectInsightsView (InsightSnapshot queries)
   - JournalView (Journal queries)
   - CampaignView (Campaign queries)
4. **Verify migration** runs successfully on app launch
5. **Check Widget/MenuBar** still work with shared models

## Database Schema Version
- **Current**: `FocusOS_v3.sqlite`
- **SharedDataManager**: `FocusOS_v2.sqlite` (Widget/MenuBar)
- **Note**: Different versions intentional - main app has additional app-local models

## Conclusion
The casting error was caused by a combination of incorrect module references, missing schema entries, and duplicate model definitions. All issues have been systematically resolved by:
1. Correcting all model references to use proper namespaces
2. Adding all missing models to the schema
3. Removing duplicate model files and establishing single source of truth
4. Properly separating shared models (in FocusOSShared) from app-local models (in main app)

