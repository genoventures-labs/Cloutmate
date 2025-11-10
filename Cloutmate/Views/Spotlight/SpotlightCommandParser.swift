//
//  SpotlightCommandParser.swift
//  Cloutmate
//
//  Intent detection and routing for Aurora Spotlight commands
//

import Foundation
import SwiftData
import CloutmateShared

enum SpotlightIntent {
    case execution(ExecutionIntent)
    case reflection(ReflectionIntent)
    case navigation(TabIdentifier)
    case dataSearch(String)
    case memoryQuery(String)
    case ritual(RitualCommand)
    case unknown(String)
}

enum RitualCommand {
    case startMorning
    case startEvening
    case startFocusSession
}

@MainActor
final class SpotlightCommandParser {
    static let shared = SpotlightCommandParser()
    
    private let coreResponseService = CoreResponseService.shared
    
    private init() {}
    
    /// Parse user input and determine intent type
    func parse(_ input: String, modelContext: ModelContext) async -> SpotlightIntent {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Check for "Open task:" pattern FIRST to prevent creating tasks with that name
        if trimmed.hasPrefix("open task:") {
            // Extract task name and search for it
            let taskName = String(trimmed.dropFirst("open task:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !taskName.isEmpty {
                return .dataSearch("task: \(taskName)")
            }
        }
        
        // Check for navigation commands first (fast, no AI needed)
        if let tab = detectNavigationIntent(trimmed) {
            return .navigation(tab)
        }
        
        // Check for ritual commands (fast, pattern-based)
        if let ritual = detectRitualCommand(trimmed) {
            return .ritual(ritual)
        }
        
        // Check for reflection intent (AI-powered)
        if let reflectionIntent = try? await coreResponseService.detectReflectionIntent(input: input) {
            return .reflection(reflectionIntent)
        }
        
        // Check for execution intent (AI-powered) - but only if it's not a navigation/opening command
        // Skip execution detection for patterns that look like navigation
        let isNavigationPattern = trimmed.hasPrefix("go to ") || 
                                  trimmed.hasPrefix("open ") || 
                                  trimmed.hasPrefix("show ") ||
                                  trimmed.hasPrefix("navigate to ")
        
        if !isNavigationPattern {
            if let executionIntent = try? await coreResponseService.detectExecutionIntent(input: input) {
                return .execution(executionIntent)
            }
        }
        
        // Check for memory query patterns
        if detectMemoryQuery(trimmed) {
            return .memoryQuery(input)
        }
        
        // Check for data search patterns
        if detectDataSearch(trimmed) {
            return .dataSearch(input)
        }
        
        // Default: unknown (will route to AI Assistant)
        return .unknown(input)
    }
    
    // MARK: - Navigation Detection
    
    private func detectNavigationIntent(_ input: String) -> TabIdentifier? {
        let navPatterns: [(pattern: String, tab: TabIdentifier)] = [
            ("go to home", .home),
            ("open home", .home),
            ("show home", .home),
            ("go to inbox", .inbox),
            ("open inbox", .inbox),
            ("show inbox", .inbox),
            ("go to notes", .notes),
            ("open notes", .notes),
            ("show notes", .notes),
            ("go to journal", .journal),
            ("open journal", .journal),
            ("show journal", .journal),
            ("go to projects", .projects),
            ("open projects", .projects),
            ("show projects", .projects),
            ("go to tasks", .tasks),
            ("open tasks", .tasks),
            ("show tasks", .tasks),
            ("go to areas", .areas),
            ("open areas", .areas),
            ("show areas", .areas),
            ("go to resources", .resources),
            ("open resources", .resources),
            ("show resources", .resources),
            ("go to archives", .archives),
            ("open archives", .archives),
            ("show archives", .archives),
            ("go to drafts", .drafts),
            ("open drafts", .drafts),
            ("show drafts", .drafts),
            ("go to calendar", .calendar),
            ("open calendar", .calendar),
            ("show calendar", .calendar),
            ("go to artifacts", .posts),
            ("open artifacts", .posts),
            ("show artifacts", .posts),
            ("go to ai assistant", .aiAssistant),
            ("open ai assistant", .aiAssistant),
            ("show ai assistant", .aiAssistant),
            ("go to focus mode", .focusMode),
            ("open focus mode", .focusMode),
            ("show focus mode", .focusMode),
            ("go to focus gravity", .focusGravity),
            ("open focus gravity", .focusGravity),
            ("show focus gravity", .focusGravity),
            ("go to rituals", .rituals),
            ("open rituals", .rituals),
            ("show rituals", .rituals),
            ("go to insights", .insights),
            ("open insights", .insights),
            ("show insights", .insights),
            ("go to settings", .settings),
            ("open settings", .settings),
            ("show settings", .settings)
        ]
        
        for (pattern, tab) in navPatterns {
            if input.contains(pattern) {
                return tab
            }
        }
        
        return nil
    }
    
    // MARK: - Ritual Detection
    
    private func detectRitualCommand(_ input: String) -> RitualCommand? {
        let morningPatterns = ["start morning ritual", "begin morning ritual", "morning ritual", "start morning"]
        let eveningPatterns = ["start evening ritual", "begin evening ritual", "evening ritual", "start evening"]
        let focusPatterns = ["start focus", "begin focus", "focus session", "start focus session", "focus mode"]
        
        for pattern in morningPatterns {
            if input.contains(pattern) {
                return .startMorning
            }
        }
        
        for pattern in eveningPatterns {
            if input.contains(pattern) {
                return .startEvening
            }
        }
        
        for pattern in focusPatterns {
            if input.contains(pattern) {
                return .startFocusSession
            }
        }
        
        return nil
    }
    
    // MARK: - Memory Query Detection
    
    private func detectMemoryQuery(_ input: String) -> Bool {
        let patterns = [
            "when did i last",
            "when did i mention",
            "when did i talk about",
            "what did i say about",
            "remember when",
            "recall when"
        ]
        
        return patterns.contains { input.contains($0) }
    }
    
    // MARK: - Data Search Detection
    
    private func detectDataSearch(_ input: String) -> Bool {
        let patterns = [
            "find all",
            "search for",
            "show me all",
            "list all",
            "find",
            "search"
        ]
        
        return patterns.contains { input.hasPrefix($0) }
    }
}

