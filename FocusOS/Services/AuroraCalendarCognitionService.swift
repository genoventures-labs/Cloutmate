//
//  AuroraCalendarCognitionService.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Main orchestrator service
//

import Foundation
import SwiftData
import Combine
import os.log
import FocusOSShared

@MainActor
final class AuroraCalendarCognitionService: ObservableObject {
    static let shared = AuroraCalendarCognitionService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "AuroraCalendarCognition")
    private var cancellables = Set<AnyCancellable>()
    private var isRunning = false
    
    @Published private(set) var lastAnalysisDate: Date?
    @Published private(set) var isAnalyzing = false
    
    private let colorEngine = CalendarColorEngine.shared
    
    private init() {}
    
    // MARK: - Lifecycle
    
    func start(modelContext: ModelContext) {
        guard !isRunning else {
            logger.debug("AuroraCalendarCognitionService already running")
            return
        }
        
        guard UserDefaults.standard.bool(forKey: "calendarCognitionEnabled") != false else {
            logger.info("Calendar cognition disabled")
            return
        }
        
        isRunning = true
        logger.info("Starting AuroraCalendarCognitionService")
        
        // Initial analysis
        _Concurrency.Task { @MainActor in
            await analyzeAndColorizeEvents(modelContext: modelContext)
        }
        
        // Subscribe to relevant notifications
        observeTaskCompletions(modelContext: modelContext)
        observeFocusSessions(modelContext: modelContext)
        observeProjectChanges(modelContext: modelContext)
    }
    
    func stop() {
        cancellables.removeAll()
        isRunning = false
        logger.info("Stopped AuroraCalendarCognitionService")
    }
    
    // MARK: - Core Analysis
    
    func analyzeAndColorizeEvents(modelContext: ModelContext) async {
        guard !isAnalyzing else {
            logger.debug("Analysis already in progress")
            return
        }
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        logger.info("Starting calendar event colorization analysis")
        
        do {
            // Fetch all calendar events
            let descriptor = FetchDescriptor<CalendarEvent>(
                sortBy: [SortDescriptor(\.startDate, order: .forward)]
            )
            let events = try modelContext.fetch(descriptor)
            
            logger.debug("Found \(events.count) events to analyze")
            
            // Build context
            let context = buildAnalysisContext(events: events, modelContext: modelContext)
            
            // Analyze each event
            var updatedCount = 0
            for event in events {
                if await updateEventColor(event, context: context, modelContext: modelContext) {
                    updatedCount += 1
                }
            }
            
            try modelContext.save()
            lastAnalysisDate = Date()
            
            logger.info("Completed analysis: updated \(updatedCount) of \(events.count) events")
            
            // Check for triage needs
            checkTriageNeeded(modelContext: modelContext)
            
        } catch {
            logger.error("Failed to analyze events: \(error.localizedDescription)")
        }
    }
    
    func getColorForEvent(_ event: CalendarEvent, modelContext: ModelContext) async -> EventColor {
        let eventId = event.id
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate<CalendarEvent> { e in
                e.id == eventId
            }
        )
        let events = (try? modelContext.fetch(descriptor)) ?? []
        let context = buildAnalysisContext(events: events, modelContext: modelContext)
        
        let result = colorEngine.computeColor(for: event, context: context, modelContext: modelContext)
        return result.color
    }
    
    // MARK: - Event Color Updates
    
    private func updateEventColor(
        _ event: CalendarEvent,
        context: ColorAnalysisContext,
        modelContext: ModelContext
    ) async -> Bool {
        // Skip if user has manually overridden
        if let existingReason = getExistingReason(for: event.id, modelContext: modelContext),
           existingReason.isUserOverride {
            return false
        }
        
        // Compute new color
        let result = colorEngine.computeColor(for: event, context: context, modelContext: modelContext)
        
        // Check if color changed
        let currentColorHex = event.colorHex
        if currentColorHex == result.color.hex {
            // Update reason timestamp even if color unchanged
            if let existingReason = getExistingReason(for: event.id, modelContext: modelContext) {
                existingReason.computedAt = Date()
                existingReason.urgencyScore = result.urgencyScore
                existingReason.primaryFactor = result.primaryFactor
                existingReason.secondaryFactors = result.secondaryFactors
                existingReason.explanation = result.explanation
                existingReason.factors = result.factors
            }
            return false
        }
        
        // Update event color
        event.colorHex = result.color.hex
        
        // Update or create reason
        let reason = getOrCreateReason(for: event.id, modelContext: modelContext)
        reason.colorHex = result.color.hex
        reason.urgencyScore = result.urgencyScore
        reason.primaryFactor = result.primaryFactor
        reason.secondaryFactors = result.secondaryFactors
        reason.explanation = result.explanation
        reason.factors = result.factors
        reason.computedAt = Date()
        reason.isUserOverride = false
        
        logger.debug("Updated event \(event.id.uuidString) color to \(result.color.rawValue)")
        
        return true
    }
    
    // MARK: - Triage & Recommendations
    
    func checkTriageNeeded(for date: Date? = nil, modelContext: ModelContext) -> TriageRecommendation? {
        let targetDate = date ?? Date()
        let dayStart = Calendar.current.startOfDay(for: targetDate)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? targetDate
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.startDate >= dayStart && event.startDate < dayEnd
            }
        )
        
        guard let events = try? modelContext.fetch(descriptor) else { return nil }
        
        // Count high-urgency events (red/orange)
        let highUrgencyEvents = events.filter { event in
            guard let colorHex = event.colorHex,
                  let color = EventColor.from(hex: colorHex) else { return false }
            return color == .red || color == .orange
        }
        
        let threshold = UserDefaults.standard.integer(forKey: "triageThreshold")
        let actualThreshold = threshold > 0 ? threshold : 3
        
        guard highUrgencyEvents.count >= actualThreshold else { return nil }
        
        // Build recommendation
        var suggestedActions: [TriageAction] = []
        var highROITasks: [UUID] = []
        var rescheduleCandidates: [UUID] = []
        
        // Find high ROI tasks (high CPS + high urgency)
        for event in highUrgencyEvents {
            for (index, entityId) in event.linkedEntityIds.enumerated() {
                guard index < event.linkedEntityTypes.count,
                      event.linkedEntityTypes[index] == "task" else { continue }
                
                if let cpsScoreValue = PriorityEngine.shared.getScoreValue(for: entityId, modelContext: modelContext),
                   cpsScoreValue > 0.7 {
                    highROITasks.append(entityId)
                }
            }
        }
        
        // Find negotiable events (green/yellow, no deadline)
        for event in events {
            guard let colorHex = event.colorHex,
                  let color = EventColor.from(hex: colorHex) else { continue }
            
            if (color == .green || color == .yellow) && event.linkedEntityIds.isEmpty {
                // Could be rescheduled
                suggestedActions.append(.reschedule(event.id))
                rescheduleCandidates.append(event.id)
            }
        }
        
        if highUrgencyEvents.count > 5 {
            suggestedActions.append(.createTriageWindow)
        }
        
        if !highROITasks.isEmpty {
            suggestedActions.append(.focusOnHighROI)
        }
        
        return TriageRecommendation(
            date: targetDate,
            urgencyCount: highUrgencyEvents.count,
            suggestedActions: suggestedActions,
            highROITasks: highROITasks,
            rescheduleCandidates: rescheduleCandidates
        )
    }
    
    func suggestLightDayOptimizations(for date: Date, modelContext: ModelContext) -> [DayOptimization] {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? date
        
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.startDate >= dayStart && event.startDate < dayEnd
            }
        )
        
        guard let events = try? modelContext.fetch(descriptor) else { return [] }
        
        // Calculate workload density
        let totalDuration = events.reduce(0.0) { sum, event in
            sum + event.endDate.timeIntervalSince(event.startDate)
        }
        let hoursScheduled = totalDuration / 3600
        
        guard events.count < 3 || hoursScheduled < 2 else { return [] }
        
        var optimizations: [DayOptimization] = []
        
        // Suggest pulling tasks forward
        let tomorrowStart = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let tomorrowEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayEnd) ?? dayEnd
        
        let tomorrowStartValue = tomorrowStart
        let tomorrowEndValue = tomorrowEnd
        
        // Fetch tasks with due dates and filter by date range in Swift
        let doneStatusRaw = FocusOSShared.TaskStatus.done.rawValue
        let taskDescriptor = FetchDescriptor<FocusOSShared.Task>(
            predicate: #Predicate<FocusOSShared.Task> { task in
                task.dueDate != nil && task.statusRaw != doneStatusRaw
            }
        )
        
        if let allTasks = try? modelContext.fetch(taskDescriptor) {
            let tomorrowTasks = allTasks.filter { (task: FocusOSShared.Task) -> Bool in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= tomorrowStartValue && dueDate < tomorrowEndValue
            }
            
            if !tomorrowTasks.isEmpty {
                optimizations.append(.pullTasksForward(tomorrowTasks.prefix(3).map { $0.id }))
            }
        }
        
        // Suggest rest opportunities
        if hoursScheduled < 1 {
            optimizations.append(.restOpportunity)
        }
        
        // Suggest pre-prep
        optimizations.append(.prepForTomorrow)
        
        return optimizations
    }
    
    // MARK: - Helpers
    
    private func buildAnalysisContext(events: [CalendarEvent], modelContext: ModelContext) -> ColorAnalysisContext {
        // Get energy forecast from CognitionPredictor if available
        // For now, use nil (will be enhanced later)
        let energyForecast: ColorAnalysisContext.EnergyForecast? = nil
        
        return ColorAnalysisContext(
            eventsOnDay: events,
            currentDate: Date(),
            energyForecast: energyForecast
        )
    }
    
    private func getExistingReason(for eventId: UUID, modelContext: ModelContext) -> EventColorReason? {
        let eventIdValue = eventId
        let descriptor = FetchDescriptor<EventColorReason>(
            predicate: #Predicate<EventColorReason> { reason in
                reason.eventId == eventIdValue
            }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func getOrCreateReason(for eventId: UUID, modelContext: ModelContext) -> EventColorReason {
        if let existing = getExistingReason(for: eventId, modelContext: modelContext) {
            return existing
        }
        
        let reason = EventColorReason(
            eventId: eventId,
            colorHex: "",
            urgencyScore: 0.0,
            primaryFactor: "",
            explanation: ""
        )
        modelContext.insert(reason)
        return reason
    }
    
    // MARK: - Observers
    
    private func observeTaskCompletions(modelContext: ModelContext) {
        NotificationCenter.default
            .publisher(for: .taskStatusChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                _Concurrency.Task { @MainActor in
                    await self?.analyzeAndColorizeEvents(modelContext: modelContext)
                }
            }
            .store(in: &cancellables)
    }
    
    private func observeFocusSessions(modelContext: ModelContext) {
        NotificationCenter.default
            .publisher(for: .focusSessionStatusChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                _Concurrency.Task { @MainActor in
                    await self?.analyzeAndColorizeEvents(modelContext: modelContext)
                }
            }
            .store(in: &cancellables)
    }
    
    private func observeProjectChanges(modelContext: ModelContext) {
        NotificationCenter.default
            .publisher(for: .projectStatusChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                _Concurrency.Task { @MainActor in
                    await self?.analyzeAndColorizeEvents(modelContext: modelContext)
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Types

struct TriageRecommendation {
    let date: Date
    let urgencyCount: Int
    let suggestedActions: [TriageAction]
    let highROITasks: [UUID]
    let rescheduleCandidates: [UUID]
}

enum TriageAction {
    case createTriageWindow
    case focusOnHighROI
    case reschedule(UUID)
    case split(UUID)
    case drop(UUID)
}

enum DayOptimization {
    case pullTasksForward([UUID])
    case accelerateProject(UUID)
    case restOpportunity
    case prepForTomorrow
}

// MARK: - Notification Names

extension Notification.Name {
    static let taskStatusChanged = Notification.Name("taskStatusChanged")
    static let projectStatusChanged = Notification.Name("projectStatusChanged")
}

