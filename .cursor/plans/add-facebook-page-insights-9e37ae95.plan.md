<!-- 9e37ae95-23cd-47f0-a37f-9c95fe71a475 19bebc18-8b4d-48f4-87ea-c86cc5561e43 -->
# Fix Swift 6 Compilation Errors

## Overview

Systematically fix compilation errors across multiple service files to ensure Swift 6 compatibility. Errors fall into categories: Logger actor isolation, GeminiService API mismatches, Post model property visibility, CharacterSet references, and SwiftData predicate issues.

## Error Categories & Fixes

### 1. Logger Actor Isolation Issues

**Files affected:** BestTimeOptimizerService, ContentGapAnalyzerService, ContentRecyclingService, AIExecutionService, ContentIntelligenceService

**Fix:** Replace `Logger.publishing.error()` and `Logger.metaAPI.error()` with direct `os_log()` calls which are thread-safe and don't require MainActor isolation.

### 2. GeminiService API Mismatches  

**Files affected:** ContentGapAnalyzerService, ContentRecyclingService, HashtagPerformanceService

**Fix:** Replace all `GeminiService.shared.generateText(prompt:)` calls with `GeminiService.shared.generateResponse(for:)` which is the correct method signature.

### 3. CharacterSet Reference Issues

**Files affected:** ContentGapAnalyzerService, ContentRecyclingService

**Fix:** Add `CharacterSet.` prefix to all `.whitespacesAndNewlines` and `.whitespaces` references.

### 4. Post Model Property Access

**Files affected:** BestTimeOptimizerService, ContentRecyclingService

**Properties:** `customProperties`, `contentPillar`, `campaignId`

**Fix:** Use reflection-based helper extension (similar to pageIDs fix) or access via helper methods. These properties exist in the model but have SwiftData visibility issues.

### 5. SwiftData Predicate Issues

**Files affected:** BestTimeOptimizerService, ContentRecyclingService

**Fix:** Rewrite predicates that compare UUIDs across different model types. SwiftData predicates have limitations with cross-model comparisons.

### 6. Type Conversion Issues

**Files affected:** BestTimeOptimizerService (line 94)

**Fix:** Fix dictionary type mismatches and conversion errors.

### 7. Platform.displayName Actor Isolation

**Files affected:** HashtagPerformanceService, AppContextService

**Fix:** Capture displayName value synchronously or use nonisolated access pattern.

## Implementation Order

1. Fix Logger calls (replace with os_log)
2. Fix GeminiService.generateText calls
3. Fix CharacterSet references  
4. Add Post property helper extensions
5. Fix SwiftData predicates
6. Fix type conversion issues
7. Fix Platform.displayName access

### To-dos

- [ ] Replace Logger static property access with os_log calls in all affected service files
- [ ] Replace generateText(prompt:) with generateResponse(for:) in ContentGapAnalyzerService, ContentRecyclingService, HashtagPerformanceService
- [ ] Add CharacterSet. prefix to whitespacesAndNewlines and whitespaces references
- [ ] Add helper extension for Post customProperties, contentPillar, campaignId using reflection
- [ ] Fix SwiftData predicate expressions that compare UUIDs across different model types
- [ ] Fix dictionary type mismatches in BestTimeOptimizerService
- [ ] Fix Platform.displayName actor isolation issues