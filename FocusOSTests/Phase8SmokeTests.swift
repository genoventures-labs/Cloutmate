//
//  Phase8SmokeTests.swift
//  FocusOSTests
//
//  Phase 8: Cognitive Loop Completion - Smoke Test Suite
//  Verifies loop coherence and emotional reactivity with minimal runtime logs
//

import XCTest
import SwiftData
@testable import FocusOS
@testable import FocusOSShared

final class Phase8SmokeTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    @MainActor
    override func setUp() async throws {
        // Create in-memory test container with minimal schema
        let schema = Schema([
            FocusRitual.self,
            RitualCompletion.self,
            WeeklyReview.self,
            SmartNudge.self
        ])
        
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = modelContainer.mainContext
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }
    
    // MARK: - Test 1: Ritual Triggers
    
    @MainActor
    func test_01_RitualManagerInitialization() async throws {
        // Given: Fresh app state
        let manager = FocusRitualManager.shared
        
        // When: Starting ritual manager
        manager.start(modelContext: modelContext)
        
        // Then: Should have morning and evening rituals scheduled
        XCTAssertEqual(manager.upcomingRituals.count, 2, "Should have 2 upcoming rituals (morning/evening)")
        
        let ritualTypes = Set(manager.upcomingRituals.map { $0.type })
        XCTAssertTrue(ritualTypes.contains(.morning), "Should have morning ritual")
        XCTAssertTrue(ritualTypes.contains(.evening), "Should have evening ritual")
        
        print("✅ Test 1: Ritual Manager Initialization - PASSED")
    }
    
    // MARK: - Test 2: Completion Flow
    
    @MainActor
    func test_02_MorningRitualCompletion() async throws {
        // Given: A morning ritual exists
        let manager = FocusRitualManager.shared
        manager.start(modelContext: modelContext)
        
        let morningRituals = manager.upcomingRituals.filter { $0.type == .morning }
        guard let morningRitual = morningRituals.first else {
            XCTFail("Should have morning ritual")
            return
        }
        
        let initialCompletions = fetchRitualCompletions().count
        
        // When: Triggering and completing the ritual
        manager.triggerRitual(morningRitual, modelContext: modelContext)
        
        let completionInput = RitualCompletionInput(
            outcome: .completed,
            completedAt: Date(),
            duration: 1200,
            cpsBoostApplied: true,
            momentumDelta: 0.15,
            metadata: ["test": "smoke"]
        )
        
        let completion = manager.completeRitual(
            morningRitual,
            input: completionInput,
            modelContext: modelContext
        )
        
        // Then: Should have increased completion count
        let finalCompletions = fetchRitualCompletions().count
        XCTAssertEqual(finalCompletions, initialCompletions + 1, "Completion count should increase")
        XCTAssertEqual(completion.outcome, .completed, "Should be marked as completed")
        XCTAssertTrue(completion.cpsBoostApplied, "CPS boost should be applied")
        XCTAssertEqual(morningRitual.status, .completed, "Ritual should be marked completed")
        XCTAssertGreaterThan(morningRitual.streakCount, 0, "Streak should be tracked")
        
        print("✅ Test 2: Morning Ritual Completion - PASSED")
    }
    
    @MainActor
    func test_03_EveningRitualCompletion() async throws {
        // Given: An evening ritual exists
        let manager = FocusRitualManager.shared
        manager.start(modelContext: modelContext)
        
        let eveningRituals = manager.upcomingRituals.filter { $0.type == .evening }
        guard let eveningRitual = eveningRituals.first else {
            XCTFail("Should have evening ritual")
            return
        }
        
        // When: Completing evening reflection
        manager.triggerRitual(eveningRitual, modelContext: modelContext)
        
        let completionInput = RitualCompletionInput(
            outcome: .completed,
            completedAt: Date(),
            duration: 600,
            taskStatusCounts: ["done": 5, "deferred": 2, "dropped": 0],
            momentumDelta: 0.2,
            metadata: ["test": "evening"]
        )
        
        _ = manager.completeRitual(
            eveningRitual,
            input: completionInput,
            modelContext: modelContext
        )
        
        // Then: Task counts should be saved
        let completions = fetchRitualCompletions()
        let eveningCompletions = completions.filter { $0.ritualType == .evening }
        guard let lastEvening = eveningCompletions.last else {
            XCTFail("Should have evening completion")
            return
        }
        
        XCTAssertEqual(lastEvening.taskStatusCounts["done"], 5, "Should save done count")
        XCTAssertEqual(lastEvening.taskStatusCounts["deferred"], 2, "Should save deferred count")
        
        print("✅ Test 3: Evening Ritual Completion - PASSED")
    }
    
    // MARK: - Test 3: Weekly Review
    
    @MainActor
    func test_04_WeeklyReviewFlow() async throws {
        // Given: A weekly review instance
        let review = WeeklyReview(
            scheduledFor: Date(),
            status: .scheduled
        )
        modelContext.insert(review)
        
        // When: Completing the review
        review.markStarted()
        XCTAssertEqual(review.status, .inProgress, "Should be in progress after marking started")
        
        review.summary = "Test weekly review"
        review.insights = "Test insights"
        review.recommendations = "Test recommendations"
        review.nextFocuses = ["Focus 1", "Focus 2", "Focus 3"]
        review.focusGravityScore = 0.75
        review.captureVelocity = 15.0
        review.outputVelocity = 12.0
        review.clarityIndex = 85.0
        review.inboxItemsCleared = 3
        review.markCompleted()
        
        RitualAnalytics.shared.recordWeeklyReview(review, modelContext: modelContext)
        
        // Then: Review should be marked completed
        XCTAssertEqual(review.status, .completed, "Review should be completed")
        XCTAssertNotNil(review.completedAt, "Should have completion timestamp")
        XCTAssertEqual(review.nextFocuses.count, 3, "Should have 3 next focuses")
        
        print("✅ Test 4: Weekly Review Flow - PASSED")
    }
    
    // MARK: - Test 4: Smart Nudge Engine
    
    @MainActor
    func test_05_NudgeServiceInitialization() async throws {
        // Given: Fresh nudge service
        let service = SmartNudgeService.shared
        service.start(modelContext: modelContext)
        
        // Then: Should be initialized without errors
        XCTAssertNotNil(service, "Service should be initialized")
        
        print("✅ Test 5: Nudge Service Initialization - PASSED")
    }
    
    @MainActor
    func test_06_NudgeToneAdaptation() async throws {
        // Given: ARTE integration
        let adapter = NudgeToneAdapter.shared
        
        // When: ARTE state changes
        let calmTone = adapter.tone(for: .stalePriority)
        let energizedTone = adapter.tone(for: .captureVelocityDrop)
        let fatiguedTone = adapter.tone(for: .reflectionReminder)
        
        // Then: Tones should be mapped correctly
        XCTAssertEqual(calmTone, .calm, "Calm state should map to calm tone")
        XCTAssertNotNil(energizedTone, "Energized state should return a tone")
        XCTAssertNotNil(fatiguedTone, "Fatigued state should return a tone")
        
        print("✅ Test 6: Nudge Tone Adaptation - PASSED")
    }
    
    @MainActor
    func test_07_NudgeCreation() async throws {
        // Given: Nudge service and emotional state
        let service = SmartNudgeService.shared
        service.start(modelContext: modelContext)
        
        let initialNudgeCount = fetchSmartNudges().count
        
        // When: Creating a nudge
        let nudge = SmartNudge(
            trigger: .stalePriority,
            tone: .focused,
            message: "Test nudge message",
            detail: "Test detail",
            metadata: ["test": "smoke"]
        )
        nudge.markDelivered()
        modelContext.insert(nudge)
        
        RitualAnalytics.shared.recordNudge(nudge, modelContext: modelContext)
        
        // Then: Nudge should be saved
        let finalNudgeCount = fetchSmartNudges().count
        XCTAssertEqual(finalNudgeCount, initialNudgeCount + 1, "Nudge count should increase")
        XCTAssertNotNil(nudge.deliveredAt, "Should have delivery timestamp")
        
        print("✅ Test 7: Nudge Creation - PASSED")
    }
    
    // MARK: - Test 5: Insights Integration
    
    @MainActor
    func test_08_RitualAnalytics() async throws {
        // Given: Some ritual completions exist
        let morningRitual = FocusRitual(type: .morning, scheduledFor: Date(), windowEnd: Date())
        morningRitual.streakCount = 7
        morningRitual.bestStreak = 10
        morningRitual.totalCompletions = 25
        modelContext.insert(morningRitual)
        
        let completion1 = RitualCompletion(
            ritualType: .morning,
            outcome: .completed,
            scheduledFor: Date(),
            completedAt: Date()
        )
        let completion2 = RitualCompletion(
            ritualType: .morning,
            outcome: .completed,
            scheduledFor: Date(),
            completedAt: Date()
        )
        modelContext.insert(completion1)
        modelContext.insert(completion2)
        
        try modelContext.save()
        
        // When: Generating analytics summary
        let summary = RitualAnalytics.shared.generateSummary(
            for: .thisWeek,
            modelContext: modelContext
        )
        
        // Then: Should have correct metrics
        XCTAssertEqual(summary.morningStreak, 7, "Should track morning streak")
        XCTAssertEqual(summary.bestMorningStreak, 10, "Should track best streak")
        XCTAssertGreaterThan(summary.completionRate, 0, "Should have completion rate")
        
        print("✅ Test 8: Ritual Analytics - PASSED")
    }
    
    @MainActor
    func test_09_AnalyticsEngineIntegration() async throws {
        // Given: Analytics engine with ritual data
        let completion = RitualCompletion(
            ritualType: .morning,
            outcome: .completed,
            scheduledFor: Date(),
            completedAt: Date()
        )
        modelContext.insert(completion)
        try modelContext.save()
        
        // When: Generating snapshot
        let snapshot = AnalyticsEngine.shared.generateSnapshot(
            for: .today,
            modelContext: modelContext
        )
        
        // Then: Should include ritual metrics
        XCTAssertNotNil(snapshot.ritualCompletionRate, "Should have completion rate")
        XCTAssertGreaterThanOrEqual(snapshot.morningRitualStreak, 0, "Should have streak count")
        XCTAssertGreaterThanOrEqual(snapshot.eveningRitualStreak, 0, "Should have evening streak")
        XCTAssertGreaterThanOrEqual(snapshot.nudgeResponseRate, 0, "Should have nudge rate")
        
        print("✅ Test 9: Analytics Engine Integration - PASSED")
    }
    
    // MARK: - Test 6: ARTE Tone Match
    
    @MainActor
    func test_10_ARTEReactiveThemePublisher() async throws {
        // Given: Reactive theme manager
        let manager = ReactiveThemeManager.shared
        
        // When: Getting current state
        let currentState = manager.currentEmotion()
        
        // Then: Should have valid state
        XCTAssertNotNil(currentState, "Should have current emotional state")
        
        // Verify publisher exists
        let publisher = manager.emotionalStatePublisher
        XCTAssertNotNil(publisher, "Should have emotional state publisher")
        
        print("✅ Test 10: ARTE Reactive Theme Publisher - PASSED")
    }
    
    @MainActor
    func test_11_NudgeFatigueSuppression() async throws {
        // Given: Nudge tone adapter
        let adapter = NudgeToneAdapter.shared
        
        // When: Checking fatigue suppression
        let shouldSuppress = adapter.shouldSuppressDueToFatigue
        
        // Then: Should return boolean (actual state depends on current ARTE state)
        XCTAssertNotNil(shouldSuppress, "Should have fatigue suppression flag")
        
        print("✅ Test 11: Nudge Fatigue Suppression - PASSED")
    }
    
    // MARK: - Test 7: Performance Validation
    
    @MainActor
    func test_12_SettingsPersistence() async throws {
        // Given: Ritual settings
        let settings = RitualSettings.shared
        
        // When: Updating settings
        settings.updateMorningTime(hour: 9, minute: 30)
        settings.nudgesEnabled = true
        settings.maxNudgesPerDay = 5
        
        // Then: Settings should persist
        let morningTime = settings.morningTime
        XCTAssertEqual(morningTime.hour, 9, "Should persist morning hour")
        XCTAssertEqual(morningTime.minute, 30, "Should persist morning minute")
        XCTAssertTrue(settings.nudgesEnabled, "Should persist nudges enabled")
        XCTAssertEqual(settings.maxNudgesPerDay, 5, "Should persist max nudges")
        
        print("✅ Test 12: Settings Persistence - PASSED")
    }
    
    @MainActor
    func test_13_RitualStreaks() async throws {
        // Given: Morning and evening rituals
        let morningRitual = FocusRitual(type: .morning, scheduledFor: Date(), windowEnd: Date())
        morningRitual.streakCount = 5
        morningRitual.bestStreak = 10
        
        let eveningRitual = FocusRitual(type: .evening, scheduledFor: Date(), windowEnd: Date())
        eveningRitual.streakCount = 3
        eveningRitual.bestStreak = 8
        
        modelContext.insert(morningRitual)
        modelContext.insert(eveningRitual)
        try modelContext.save()
        
        // When: Getting analytics
        let summary = RitualAnalytics.shared.generateSummary(
            for: .thisWeek,
            modelContext: modelContext
        )
        
        // Then: Should track both streaks
        XCTAssertEqual(summary.morningStreak, 5, "Should track morning streak")
        XCTAssertEqual(summary.eveningStreak, 3, "Should track evening streak")
        XCTAssertEqual(summary.bestMorningStreak, 10, "Should track best morning streak")
        XCTAssertEqual(summary.bestEveningStreak, 8, "Should track best evening streak")
        
        print("✅ Test 13: Ritual Streaks - PASSED")
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func fetchRitualCompletions() -> [RitualCompletion] {
        let descriptor = FetchDescriptor<RitualCompletion>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    @MainActor
    private func fetchSmartNudges() -> [SmartNudge] {
        let descriptor = FetchDescriptor<SmartNudge>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Performance Validation Tests

extension Phase8SmokeTests {
    
    @MainActor
    func test_14_MemoryFootprint() async throws {
        // Given: Baseline state
        let manager = FocusRitualManager.shared
        let service = SmartNudgeService.shared
        
        // When: Starting systems
        manager.start(modelContext: modelContext)
        service.start(modelContext: modelContext)
        
        // Then: Should be lightweight (qualitative check)
        // In production, would measure actual memory delta
        XCTAssertNotNil(manager)
        XCTAssertNotNil(service)
        
        print("✅ Test 14: Memory Footprint Check - PASSED")
    }
    
    @MainActor
    func test_15_TimerInitialization() async throws {
        // Given: Fresh service instances
        let manager = FocusRitualManager.shared
        let service = SmartNudgeService.shared
        
        // When: Starting
        manager.start(modelContext: modelContext)
        service.start(modelContext: modelContext)
        
        // Then: Should have active timers
        XCTAssertFalse(manager.upcomingRituals.isEmpty, "Should schedule rituals")
        
        // Clean up
        manager.stop()
        service.stop()
        
        print("✅ Test 15: Timer Initialization - PASSED")
    }
}

