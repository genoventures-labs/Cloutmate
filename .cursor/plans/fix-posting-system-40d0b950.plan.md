<!-- 40d0b950-63b6-4926-a5d4-f1a4568a2fef 08d745cc-2a81-4446-abad-c9bee11a1bd7 -->
# Advanced Content Intelligence Features

## Overview

Implement 6 advanced features that leverage AI and historical data to provide intelligent content recommendations, predictions, and optimization.

## Architecture Overview

### New Services

- `ContentIntelligenceService` - AI-powered content analysis and predictions
- `PerformancePredictionService` - ML-based engagement prediction
- `ContentRecyclingService` - Identifies and suggests evergreen content
- `ContentGapAnalyzerService` - Topic cluster analysis and trend detection
- `BestTimeOptimizerService` - A/B testing and optimal time learning
- `HashtagPerformanceService` - Hashtag tracking and recommendation

### New Models

- `PerformancePrediction` - Stores prediction scores and factors
- `RecyclablePost` - Tracks evergreen content suggestions
- `ContentTopic` - Topic clusters and coverage metrics
- `PostingTimeTest` - A/B test results for posting times
- `HashtagPerformance` - Hashtag usage and engagement metrics
- `CustomPostProperty` - User-defined post metadata
- `PostView` - Saved view configurations (Kanban, Gallery, etc.)

### UI Components

- Performance prediction indicator in composer
- Recycling suggestions panel in dashboard
- Content gap analyzer view in insights
- Best time optimizer with heatmap visualization
- Custom database views (Kanban, Table, Gallery, Timeline)
- Hashtag performance dashboard

## Feature 1: Content Performance Predictor

### Data Model

**File**: `FocusOS/Models/PerformancePrediction.swift`

```swift
@Model
final class PerformancePrediction {
    var id: UUID = UUID()
    var postId: UUID
    var predictedEngagementRate: Double
    var confidence: Double // 0-1
    var factors: [String: Double] = [:]
    var optimalPostingTime: Date?
    var createdAt: Date = Date()
    
    // Factor weights
    var captionLengthScore: Double = 0
    var toneScore: Double = 0
    var hashtagScore: Double = 0
    var platformScore: Double = 0
    var timeScore: Double = 0
    var similarityScore: Double = 0
}
```

### Service Layer

**File**: `FocusOS/Services/PerformancePredictionService.swift`

```swift
actor PerformancePredictionService {
    static let shared = PerformancePredictionService()
    
    func predictEngagement(for post: Post, historicalPosts: [Post]) async -> PerformancePrediction
    func analyzeCaption(_ caption: String) async -> (length: Int, sentiment: String, complexity: Double)
    func findSimilarPosts(_ post: Post, in historicalPosts: [Post]) async -> [Post]
    func calculateOptimalTime(platform: Platform, historicalPosts: [Post]) -> Date?
    func getPerformanceScore() -> Double // 0-100
}
```

### Composer Integration

**File**: `FocusOS/Views/Composer/PerformancePredictorPanel.swift`

Add panel to ComposerWindow showing:

- Real-time score (0-100) with color coding
- Factor breakdown with icons
- Optimal posting time suggestion
- Historical comparison

## Feature 2: Content Recycling Engine

### Data Model

**File**: `FocusOS/Models/RecyclablePost.swift`

```swift
@Model
final class RecyclablePost {
    var id: UUID = UUID()
    var originalPostId: UUID
    var isEvergreen: Bool = false
    var lastRecycledAt: Date?
    var recycleCount: Int = 0
    var nextSuggestedDate: Date?
    var topicTags: [String] = []
    var engagementScore: Double = 0
    var variations: [String] = [] // AI-generated variations
}
```

### Service Layer

**File**: `FocusOS/Services/ContentRecyclingService.swift`

```swift
actor ContentRecyclingService {
    static let shared = ContentRecyclingService()
    
    func identifyEvergreenContent(posts: [Post]) async -> [RecyclablePost]
    func generateVariations(for post: Post) async -> [String]
    func getSuggestionsForToday() async -> [RecyclablePost]
    func scheduleRecycledPost(_ recyclable: RecyclablePost, variation: String) async
}
```

### Dashboard Integration

**File**: `FocusOS/Views/Dashboard/ContentRecyclingSuggestions.swift`

Card showing:

- "3 posts ready to recycle"
- Top performing evergreen posts
- One-click to create variation
- Calendar showing recycling schedule

## Feature 3: Content Gap Analyzer

### Data Model

**File**: `FocusOS/Models/ContentTopic.swift`

```swift
@Model
final class ContentTopic {
    var id: UUID = UUID()
    var name: String
    var postCount: Int = 0
    var lastPostedAt: Date?
    var averageEngagement: Double = 0
    var relatedKeywords: [String] = []
    var isUnderrepresented: Bool = false
    var suggestedFrequency: Int = 0 // posts per month
}

@Model
final class ContentBalance {
    var id: UUID = UUID()
    var analyzedAt: Date = Date()
    var contentTypes: [String: Double] = [:] // e.g., "tips": 0.6, "stories": 0.3
    var topicClusters: [String: Int] = [:]
    var gaps: [String] = []
    var recommendations: [String] = []
}
```

### Service Layer

**File**: `FocusOS/Services/ContentGapAnalyzerService.swift`

```swift
actor ContentGapAnalyzerService {
    static let shared = ContentGapAnalyzerService()
    
    func analyzeTopicClusters(posts: [Post]) async -> [ContentTopic]
    func detectContentGaps(topics: [ContentTopic]) async -> [String]
    func analyzeContentBalance(posts: [Post]) async -> ContentBalance
    func suggestTopics(based on: [ContentTopic]) async -> [String]
}
```

### Insights Integration

**File**: `FocusOS/Views/Insights/ContentGapAnalyzerView.swift`

Full-screen view showing:

- Topic distribution pie chart
- Content type balance bar chart
- Gap suggestions with AI explanations
- Trending topics comparison
- Action buttons to create posts for gaps

## Feature 4: Best Time Optimizer with A/B Testing

### Data Model

**File**: `FocusOS/Models/PostingTimeTest.swift`

```swift
@Model
final class PostingTimeTest {
    var id: UUID = UUID()
    var basePostId: UUID
    var testVariants: [UUID] = [] // Post IDs for A/B/C variants
    var testStartDate: Date = Date()
    var testEndDate: Date?
    var results: [UUID: Double] = [:] // postId: engagementRate
    var winningTime: Date?
    var status: String = "active" // active, completed, cancelled
}

@Model
final class OptimalPostingTime {
    var id: UUID = UUID()
    var platform: String
    var dayOfWeek: Int // 1-7
    var hourOfDay: Int // 0-23
    var engagementMultiplier: Double = 1.0
    var sampleSize: Int = 0
    var confidence: Double = 0
}
```

### Service Layer

**File**: `FocusOS/Services/BestTimeOptimizerService.swift`

```swift
actor BestTimeOptimizerService {
    static let shared = BestTimeOptimizerService()
    
    func createTimeTest(for post: Post, times: [Date]) async -> PostingTimeTest
    func analyzeTestResults(_ test: PostingTimeTest) async
    func buildPostingHeatmap(platform: Platform, posts: [Post]) async -> [[Double]]
    func suggestOptimalTimes(platform: Platform) async -> [Date]
    func learnFromHistory(posts: [Post]) async
}
```

### UI Components

**File**: `FocusOS/Views/Insights/BestTimeOptimizerView.swift`

Features:

- Weekly heatmap (day × hour grid)
- A/B test creator in composer
- Active tests dashboard
- Historical test results
- Confidence indicators

## Feature 5: Notion-Style Database Views

### Data Model

**File**: `FocusOS/Models/CustomPostProperty.swift`

```swift
@Model
final class CustomPostProperty {
    var id: UUID = UUID()
    var name: String
    var type: String // text, number, select, multiselect, date, checkbox
    var options: [String] = [] // for select/multiselect
    var icon: String?
    var color: String?
}

@Model
final class PostView {
    var id: UUID = UUID()
    var name: String
    var viewType: String // table, kanban, gallery, timeline
    var filters: [String: Any] = [:]
    var sortBy: String?
    var groupBy: String?
    var visibleProperties: [String] = []
    var isDefault: Bool = false
}
```

### Extend Post Model

**File**: `FocusOSShared/FocusOSShared/FocusOSShared/Models/Post.swift`

Add:

```swift
public var customProperties: [String: String] = [:]
public var contentPillar: String?
public var funnelStage: String?
public var campaignId: UUID?
```

### UI Components

**File**: `FocusOS/Views/List/DatabaseViews/`

Create:

- `KanbanBoardView.swift` - Drag-and-drop cards grouped by property
- `GalleryView.swift` - Grid of post thumbnails
- `TimelineView.swift` - Gantt-style timeline view
- `DatabaseViewPicker.swift` - View switcher
- `CustomPropertyEditor.swift` - Manage custom fields

## Feature 6: Smart Hashtag Performance Tracker

### Data Model

**File**: `FocusOS/Models/HashtagPerformance.swift`

```swift
@Model
final class HashtagPerformance {
    var id: UUID = UUID()
    var hashtag: String
    var useCount: Int = 0
    var totalEngagement: Int = 0
    var averageEngagement: Double = 0
    var bestPerformingPostId: UUID?
    var lastUsedAt: Date?
    var platform: String
    var isTrending: Bool = false
    var trendScore: Double = 0
}

@Model
final class HashtagSet {
    var id: UUID = UUID()
    var name: String
    var hashtags: [String] = []
    var description: String?
    var useCount: Int = 0
    var averagePerformance: Double = 0
}
```

### Service Layer

**File**: `FocusOS/Services/HashtagPerformanceService.swift`

```swift
actor HashtagPerformanceService {
    static let shared = HashtagPerformanceService()
    
    func trackHashtagPerformance(post: Post) async
    func getTopPerformingHashtags(platform: Platform, limit: Int) async -> [HashtagPerformance]
    func suggestHashtags(for caption: String, platform: Platform) async -> [String]
    func detectTrendingHashtags(platform: Platform) async -> [String]
    func compareHashtagSets() async -> [(HashtagSet, Double)]
}
```

### UI Components

**File**: `FocusOS/Views/Insights/HashtagPerformanceView.swift`

Features:

- Performance leaderboard table
- Engagement comparison chart
- Hashtag set manager
- Trending indicators
- Suggestions based on content

**File**: `FocusOS/Views/Composer/HashtagSuggestionPanel.swift`

In composer:

- Smart hashtag suggestions
- Performance indicators next to suggestions
- Quick-insert hashtag sets
- Real-time performance preview

## Implementation Order

### Phase 1: Foundation (Week 1)

1. Create all data models
2. Add custom properties to Post model
3. Build service layer skeletons
4. Set up AI integration points

### Phase 2: Performance Predictor (Week 2)

1. Implement PerformancePredictionService
2. Build ML scoring algorithm
3. Create composer panel UI
4. Add real-time prediction updates

### Phase 3: Hashtag Tracker (Week 2-3)

1. Implement HashtagPerformanceService
2. Build tracking system
3. Create insights dashboard
4. Add composer suggestions

### Phase 4: Time Optimizer (Week 3)

1. Implement BestTimeOptimizerService
2. Build heatmap visualization
3. Create A/B test creator
4. Add learning algorithm

### Phase 5: Content Recycling (Week 4)

1. Implement ContentRecyclingService
2. Build AI variation generator
3. Create dashboard suggestions
4. Add scheduling workflow

### Phase 6: Gap Analyzer (Week 4-5)

1. Implement ContentGapAnalyzerService
2. Build topic clustering
3. Create insights view
4. Add trend comparison

### Phase 7: Database Views (Week 5-6)

1. Create custom property system
2. Build Kanban view
3. Build Gallery view
4. Build Timeline view
5. Add view switcher

### Phase 8: Polish & Integration (Week 6)

1. Connect all features
2. Add onboarding flows
3. Performance optimization
4. Testing and bug fixes

## Technical Requirements

### Dependencies

- Gemini AI (already integrated) for predictions and content analysis
- Core ML or Create ML for local ML models
- Charts framework for visualizations

### Data Requirements

- Minimum 20 published posts for reliable predictions
- Minimum 10 posts per platform for time optimization
- Continuous learning from new data

### Performance Considerations

- Cache predictions for 1 hour
- Background processing for analysis
- Lazy loading for database views
- Incremental learning updates

## Testing Strategy

1. **Unit Tests**: Each service with mock data
2. **Integration Tests**: Service interactions
3. **UI Tests**: Critical user flows
4. **Performance Tests**: ML prediction speed
5. **Data Quality Tests**: Ensure predictions improve over time

### To-dos

- [ ] Create all new data models: PerformancePrediction, RecyclablePost, ContentTopic, PostingTimeTest, HashtagPerformance, CustomPostProperty, PostView
- [ ] Add custom properties, contentPillar, funnelStage, campaignId to Post model
- [ ] Implement PerformancePredictionService with ML scoring algorithm
- [ ] Create PerformancePredictorPanel in composer with real-time scoring
- [ ] Implement HashtagPerformanceService with tracking and suggestions
- [ ] Create HashtagPerformanceView and composer suggestion panel
- [ ] Implement BestTimeOptimizerService with heatmap and A/B testing
- [ ] Create BestTimeOptimizerView with heatmap visualization and test creator
- [ ] Implement ContentRecyclingService with evergreen detection and AI variations
- [ ] Create ContentRecyclingSuggestions dashboard card
- [ ] Implement ContentGapAnalyzerService with topic clustering
- [ ] Create ContentGapAnalyzerView with charts and recommendations
- [ ] Implement custom property management and storage
- [ ] Create KanbanBoardView with drag-and-drop
- [ ] Create GalleryView and TimelineView
- [ ] Create DatabaseViewPicker and integrate with List tab
- [ ] Connect all features, add onboarding, optimize performance, test thoroughly