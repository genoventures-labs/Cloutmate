//
//  ArcDetectionService.swift
//  FocusOS
//
//  Auto-detects story arcs from activity patterns
//

import Foundation
import SwiftData
import os.log

@MainActor
final class ArcDetectionService {
    static let shared = ArcDetectionService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "ArcDetection")
    
    private init() {}
    
    /// Detect arcs from workspace activity
    func detectArcs(
        in dateRange: DateInterval,
        modelContext: ModelContext
    ) async -> [StoryArc] {
        var arcs: [StoryArc] = []
        
        // Analyze StoryTokens for arc patterns
        let tokens = getStoryTokens(in: dateRange, modelContext: modelContext)
        
        // Group tokens by themes
        let themeGroups = groupByThemes(tokens: tokens)
        
        // Detect momentum shifts
        let momentumShifts = detectMomentumShifts(tokens: tokens)
        
        // Generate arcs from patterns
        for (theme, tokenGroup) in themeGroups {
            if tokenGroup.count >= 2 {
                let arc = createArc(
                    theme: theme,
                    tokens: tokenGroup,
                    momentumShifts: momentumShifts,
                    modelContext: modelContext
                )
                arcs.append(arc)
            }
        }
        
        return arcs
    }
    
    private func getStoryTokens(
        in range: DateInterval,
        modelContext: ModelContext
    ) -> [StoryToken] {
        let descriptor = FetchDescriptor<StoryToken>(
            predicate: #Predicate { token in
                token.startDate >= range.start && token.endDate <= range.end
            },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func groupByThemes(tokens: [StoryToken]) -> [String: [StoryToken]] {
        var groups: [String: [StoryToken]] = [:]
        
        for token in tokens {
            for theme in token.themes {
                groups[theme, default: []].append(token)
            }
        }
        
        return groups
    }
    
    private func detectMomentumShifts(tokens: [StoryToken]) -> [Date] {
        // Detect significant changes in emotional tone or metrics
        var shifts: [Date] = []
        
        for i in 1..<tokens.count {
            let prev = tokens[i - 1]
            let curr = tokens[i]
            
            // Check for tone shift
            if prev.emotionalTone != curr.emotionalTone {
                shifts.append(curr.startDate)
            }
            
            // Check for metric shift
            if let prevFocus = prev.metrics["focusHours"],
               let currFocus = curr.metrics["focusHours"],
               abs(currFocus - prevFocus) > 5.0 {
                shifts.append(curr.startDate)
            }
        }
        
        return shifts
    }
    
    private func createArc(
        theme: String,
        tokens: [StoryToken],
        momentumShifts: [Date],
        modelContext: ModelContext
    ) -> StoryArc {
        let startDate = tokens.first?.startDate ?? Date()
        let endDate = tokens.last?.endDate ?? Date()
        
        // Calculate momentum
        let momentum = calculateMomentum(tokens: tokens)
        
        // Generate arc label
        let label = generateArcLabel(theme: theme, tokens: tokens, momentum: momentum)
        
        let arc = StoryArc(
            label: label,
            startDate: startDate,
            endDate: endDate,
            themes: [theme],
            momentum: momentum
        )
        
        modelContext.insert(arc)
        return arc
    }
    
    private func calculateMomentum(tokens: [StoryToken]) -> Double {
        guard !tokens.isEmpty else { return 0.0 }
        
        // Average emotional intensity weighted by recency
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        for (index, token) in tokens.enumerated() {
            let weight = Double(index + 1) / Double(tokens.count)
            let intensity = token.emotionalIntensity
            weightedSum += intensity * weight
            totalWeight += weight
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : 0.0
    }
    
    private func generateArcLabel(
        theme: String,
        tokens: [StoryToken],
        momentum: Double
    ) -> String {
        // Simple label generation - in production would use AI
        if momentum > 0.6 {
            return "\(theme.capitalized) Sprint"
        } else if momentum < -0.3 {
            return "\(theme.capitalized) Recovery"
        } else {
            return "\(theme.capitalized) Focus"
        }
    }
}

