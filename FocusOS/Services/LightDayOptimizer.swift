//
//  LightDayOptimizer.swift
//  FocusOS
//
//  Aurora Calendar Cognition Layer - Light day optimization suggestions
//

import Foundation
import SwiftData
import os.log
import FocusOSShared

@MainActor
final class LightDayOptimizer {
    static let shared = LightDayOptimizer()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "LightDayOptimizer")
    private let cognitionService = AuroraCalendarCognitionService.shared
    
    private init() {}
    
    func analyzeDay(_ date: Date, modelContext: ModelContext) -> [DayOptimization] {
        return cognitionService.suggestLightDayOptimizations(for: date, modelContext: modelContext)
    }
}

