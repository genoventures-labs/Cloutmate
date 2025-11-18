//
//  ColorOverrideManager.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - User color overrides with adaptive learning
//

import Foundation
import SwiftData
import os.log
import FocusOSShared

@MainActor
final class ColorOverrideManager {
    static let shared = ColorOverrideManager()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "ColorOverrideManager")
    private let cognitionService = AuroraCalendarCognitionService.shared
    
    private struct OverridePattern {
        var fromColor: EventColor
        var toColor: EventColor
        var count: Int
        var lastOverride: Date
    }
    
    private var overridePatterns: [String: OverridePattern] = [:]
    
    private init() {}
    
    // MARK: - Override Management
    
    func setOverride(
        for event: CalendarEvent,
        color: EventColor,
        modelContext: ModelContext
    ) {
        // Store override in event
        event.colorHex = color.hex
        
        // Update or create reason with override flag
        let eventId = event.id
        let descriptor = FetchDescriptor<EventColorReason>(
            predicate: #Predicate<EventColorReason> { reason in
                reason.eventId == eventId
            }
        )
        
        let reason: EventColorReason
        if let existing = try? modelContext.fetch(descriptor).first {
            reason = existing
        } else {
            reason = EventColorReason(
                eventId: event.id,
                colorHex: color.hex,
                urgencyScore: 0.0,
                primaryFactor: "user_override",
                explanation: "User override",
                isUserOverride: true
            )
            modelContext.insert(reason)
        }
        
        reason.colorHex = color.hex
        reason.isUserOverride = true
        reason.computedAt = Date()
        reason.primaryFactor = "user_override"
        reason.explanation = "You chose \(color.description)"
        
        // Track pattern - check original color before override
        let originalDescriptor = FetchDescriptor<EventColorReason>(
            predicate: #Predicate<EventColorReason> { r in
                r.eventId == eventId
            }
        )
        if let existing = try? modelContext.fetch(originalDescriptor).first,
           !existing.colorHex.isEmpty,
           let originalColor = EventColor.from(hex: existing.colorHex),
           originalColor != color {
            trackOverridePattern(from: originalColor, to: color)
        }
        
        do {
            try modelContext.save()
            logger.info("Set color override for event \(event.id.uuidString)")
        } catch {
            logger.error("Failed to save color override: \(error.localizedDescription)")
        }
    }
    
    func clearOverride(for event: CalendarEvent, modelContext: ModelContext) {
        // Remove override flag
        let eventId = event.id
        let descriptor = FetchDescriptor<EventColorReason>(
            predicate: #Predicate<EventColorReason> { reason in
                reason.eventId == eventId
            }
        )
        
        if let reason = try? modelContext.fetch(descriptor).first {
            reason.isUserOverride = false
        }
        
        // Re-analyze event
        _Concurrency.Task { @MainActor in
            await cognitionService.analyzeAndColorizeEvents(modelContext: modelContext)
        }
    }
    
    // MARK: - Pattern Tracking
    
    private func trackOverridePattern(from: EventColor, to: EventColor) {
        let key = "\(from.rawValue)->\(to.rawValue)"
        
        if var pattern = overridePatterns[key] {
            pattern.count += 1
            pattern.lastOverride = Date()
            overridePatterns[key] = pattern
        } else {
            overridePatterns[key] = OverridePattern(
                fromColor: from,
                toColor: to,
                count: 1,
                lastOverride: Date()
            )
        }
        
        // Check if pattern is significant (3+ overrides in last 30 days)
        if let pattern = overridePatterns[key],
           pattern.count >= 3 {
            logger.info("Detected override pattern: \(from.rawValue) -> \(to.rawValue) (\(pattern.count) times)")
            // Could trigger adaptive weight adjustment here
        }
    }
    
    // MARK: - Learning
    
    func getSuggestedWeightAdjustments() -> [String: Double] {
        var adjustments: [String: Double] = [:]
        
        // Analyze patterns and suggest weight adjustments
        // For now, return empty (would be enhanced with actual learning logic)
        
        return adjustments
    }
}

