<!-- 40e61813-94da-4d51-b94d-f7ba9b53aa28 85488883-7809-413f-9b54-c53bb8a62a14 -->
# Social Media Removal & Artifact Migration Plan

## Overview

Transform Cloutmate from a social media scheduling tool into a cognitive workspace orchestration system. Replace all social publishing functionality with artifact-based narrative output that runs locally via Ollama.

## Phase 1: Model Transformation

### 1.1 Create Artifact Model

**File:** `CloutmateShared/CloutmateShared/CloutmateShared/Models/Artifact.swift`

- Replace `Post` model with `Artifact`
- Fields: `id`, `title`, `content`, `outputFormat` (replaces platforms), `state` (idea/draft/final/published/archived), `publishedAt`, `createdAt`, `updatedAt`, `tags`, `mediaURLs`, `projectId`, `areaId`
- Remove all social media fields: `engagementRate`, `impressions`, `likes`, `comments`, `saves`, `reach`, `threadsPostID`, `facebookPostID`, `pageIDs`, `retryCount`, `lastError`

### 1.2 Create OutputFormat Enum

**File:** `CloutmateShared/CloutmateShared/CloutmateShared/Models/OutputFormat.swift`

- Replace `Platform` enum with `OutputFormat`: `brief`, `summary`, `reflection`, `report`, `releaseNote`, `lessonLearned`
- Add `displayName` and `colorName` properties

### 1.3 Create ArtifactState Enum

**File:** `CloutmateShared/CloutmateShared/CloutmateShared/Models/ArtifactState.swift`

- Replace `PostStatus` with `ArtifactState`: `idea`, `draft`, `final`, `published`, `archived`
- Merge Draft states into this enum

### 1.4 Remove Social Media Models

- Delete `PlatformAccount.swift` (no longer needed)
- Delete `InsightSnapshot.swift` (or repurpose for cognitive insights)
- Delete `Platform.swift` (replaced by OutputFormat)
- Delete `Post.swift` (replaced by Artifact)

### 1.5 Migrate Draft Model

- Merge `Draft` functionality into `Artifact` model
- Update all Draft references to use Artifact with state="draft"

## Phase 2: Data Migration

### 2.1 Create Migration Service

**File:** `Cloutmate/Services/ArtifactMigrationService.swift`

- Migrate existing Posts → Artifacts:
- `caption` → `title` (first line) + `content` (rest)
- `platforms` → `outputFormat` (map to nearest format)
- `scheduledDate` → `publishedAt` (if published)
- `status` → `state` (map statuses)
- Migrate Drafts → Artifacts with state="draft"
- Preserve relationships (projectId, areaId, tags)

### 2.2 Update Schema Migration

- Update `MigrationService.swift` to handle Post→Artifact migration
- Ensure backward compatibility during transition period

## Phase 3: Service Removal

### 3.1 Delete Social Media Services

- **Delete:** `Cloutmate/Services/MetaAPIService.swift`
- **Delete:** `Cloutmate/Services/ThreadsService.swift`
- **Delete:** `Cloutmate/Services/FacebookService.swift`
- **Delete:** `Cloutmate/Services/PublishingService.swift` (or repurpose for local artifact generation)
- **Delete:** `CloutmateHelper/Services/MetaAPIService.swift`
- **Delete:** `CloutmateHelper/Services/ThreadsService.swift`
- **Delete:** `CloutmateHelper/Services/FacebookService.swift`
- **Delete:** `CloutmateHelper/PostPublisher.swift`
- **Delete:** `CloutmateHelper/InsightsPoller.swift`

### 3.2 Delete Social Media Analytics Services

- **Delete:** `Cloutmate/Services/BestTimeOptimizerService.swift`
- **Delete:** `Cloutmate/Services/HashtagPerformanceService.swift`
- **Delete:** `Cloutmate/Services/ContentGapAnalyzerService.swift`
- **Delete:** `Cloutmate/Services/ContentRecyclingService.swift`
- **Delete:** `Cloutmate/Services/PerformancePredictionService.swift`

### 3.3 Update Remaining Services

- **Update:** `AppContextService.swift` - Remove Post references, add Artifact references
- **Update:** `AIRecallService.swift` - Replace Post with Artifact
- **Update:** `NarrativeEngine.swift` - Enhance for artifact generation (already exists)
- **Update:** `AICreativeService.swift` - Remove platform-specific logic, add output format guidance

## Phase 4: View Transformation

### 4.1 Transform Composer

**File:** `Cloutmate/Views/Composer/ComposerWindow.swift` → `ArtifactComposerView.swift`

- Replace platform selector with format selector (Brief, Summary, Reflection, Report, Release Note, Lesson Learned)
- Add Capture/Craft mode toggle
- Remove scheduling UI (replace with "Publish" button that creates artifact)
- Remove social media publishing logic
- Add export-to-clipboard functionality

### 4.2 Update Menu Bar Composer

**File:** `CloutmateMenuBar/QuickComposerView.swift`

- Remove platform selection
- Remove scheduling
- Simplify to quick artifact capture

### 4.3 Remove Social Settings

- **Delete:** `Cloutmate/Views/Settings/AccountsSection.swift`
- **Delete:** `Cloutmate/Views/Settings/BackgroundPostingSection.swift`
- **Delete:** `Cloutmate/Views/Settings/PlatformConnectButton.swift`
- Update `SettingsView.swift` to remove social sections

### 4.4 Update Dashboard

**File:** `Cloutmate/Views/Dashboard/DashboardView.swift`

- Remove "Social" section entirely
- Remove social insights cards
- Update `DashboardCard.swift` - Remove social card types: `scheduledPosts`, `draftCount`, `recentInsights`, `postingStreak`, `topPerformingPost`, `socialOverview`, `contentPerformance`, `platformComparison`, all Facebook insight cards
- **Delete:** `Cloutmate/Views/Dashboard/SocialInsightsCards.swift`
- **Delete:** `Cloutmate/Views/Dashboard/FacebookInsightsCards.swift`
- **Delete:** `Cloutmate/Views/Dashboard/PostSummaryCard.swift`
- **Delete:** `Cloutmate/Views/Dashboard/ContentRecyclingCard.swift`

### 4.5 Update Insights Views

- **Delete:** `Cloutmate/Views/Insights/PlatformComparisonView.swift`
- **Delete:** `Cloutmate/Views/Insights/PlatformComparisonChart.swift`
- **Delete:** `Cloutmate/Views/Insights/HashtagPerformanceView.swift`
- **Delete:** `Cloutmate/Views/Insights/ContentGapAnalyzerView.swift`
- **Delete:** `Cloutmate/Views/Insights/BestTimeOptimizerView.swift`
- **Delete:** `Cloutmate/Views/Insights/ContentAnalyticsView.swift`
- **Update:** `Cloutmate/Views/Insights/ReflectionSummary.swift` - Remove Post/platform references
- **Update:** `Cloutmate/Views/Insights/InsightsView.swift` - Remove social insights tabs

### 4.6 Update Calendar Views

- **Update:** `Cloutmate/Views/Calendar/UnifiedCalendarView.swift` - Replace Post with Artifact
- **Update:** `Cloutmate/Views/Calendar/MonthlyCalendarView.swift` - Replace Post with Artifact
- **Update:** `Cloutmate/Views/Calendar/PostPreviewSheet.swift` → `ArtifactPreviewSheet.swift`
- **Update:** `Cloutmate/Views/Calendar/PostDropDelegate.swift` → `ArtifactDropDelegate.swift`
- **Update:** `Cloutmate/Views/Calendar/CalendarPostListSheet.swift` → `CalendarArtifactListSheet.swift`

### 4.7 Update List Views

- **Update:** `Cloutmate/Views/List/ListTableView.swift` - Replace Post with Artifact
- **Update:** `Cloutmate/Views/List/DatabaseViews.swift` - Replace Post with Artifact

### 4.8 Update Drafts View

- **Update:** `Cloutmate/Views/Drafts/DraftsView.swift` - Show Artifacts with state="draft"
- **Update:** `Cloutmate/Views/Drafts/DraftEditor.swift` - Update to use Artifact model

## Phase 5: Update References

### 5.1 Update All Post References

- Search and replace throughout codebase:
- `Post` → `Artifact`
- `PostStatus` → `ArtifactState`
- `Platform` → `OutputFormat`
- `.threads` / `.facebook` → output format equivalents
- `postPlatforms` → `outputFormat`
- `publishPost` → `createArtifact` or `publishArtifact`

### 5.2 Update Helper App

- **Delete:** `CloutmateHelper/PostPublisher.swift`
- **Delete:** `CloutmateHelper/InsightsPoller.swift`
- **Update:** `CloutmateHelper/BackgroundScheduler.swift` - Remove scheduled posting logic
- **Update:** `CloutmateHelper/HelperXPCService.swift` - Remove publishing-related methods

### 5.3 Update Widget

- **Update:** `CloutmateWidget/WidgetTimelineProvider.swift` - Replace Post with Artifact
- **Update:** `CloutmateWidget/CloutmateWidgetView.swift` - Show artifacts instead of posts

### 5.4 Update XPC Protocol

- **Update:** `CloutmateShared/CloutmateShared/CloutmateShared/Services/XPCProtocol.swift`
- Remove publishing-related methods
- Keep only data sync methods

## Phase 6: Clean Up

### 6.1 Remove OAuth Infrastructure

- Remove Meta OAuth callback handling
- Remove AuthenticationServices integration for social platforms
- Clean up Info.plist entries for Meta OAuth

### 6.2 Remove API Models

- **Delete:** `Cloutmate/Models/APIModels.swift`
- **Delete:** `CloutmateHelper/Services/APIModels.swift`
- Keep only local models

### 6.3 Update README

- **Update:** `README.md` - Remove social media features, update to cognitive workspace description

## Phase 7: Testing & Validation

### 7.1 Migration Testing

- Test Post → Artifact migration preserves data
- Test Draft → Artifact migration
- Verify relationships maintained (projects, areas, tags)

### 7.2 Feature Testing

- Verify Artifact Composer works in Capture/Craft modes
- Verify format selector works
- Verify export-to-clipboard functionality
- Verify NarrativeEngine generates artifacts correctly

### 7.3 Remove Dead Code

- Remove unused imports
- Remove unused UI components
- Clean up references to deleted services

## Key Files to Modify

**Models:**

- Create: `Artifact.swift`, `OutputFormat.swift`, `ArtifactState.swift`
- Delete: `Post.swift`, `Platform.swift`, `PlatformAccount.swift`, `InsightSnapshot.swift`
- Update: `Draft.swift` (merge into Artifact)

**Services:**

- Create: `ArtifactMigrationService.swift`
- Delete: All Meta/social services listed above
- Update: `NarrativeEngine.swift`, `AppContextService.swift`, `AIRecallService.swift`

**Views:**

- Transform: `ComposerWindow.swift` → `ArtifactComposerView.swift`
- Delete: All social insights views listed above
- Update: All views that reference Post/Platform

**Helper:**

- Remove: Publishing and insights polling functionality
- Keep: Only data sync capabilities