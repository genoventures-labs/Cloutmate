//
//  CognitiveHealthService.swift
//  FocusOS
//
//  Provides self-introspection metrics so Aurora can reason about her own cognitive load.
//

import Foundation
import SwiftData

struct CognitiveHealthSnapshot: Sendable {
    let totalMemories: Int
    let memoryDensityPerDay: Double
    let stalePercentage: Double
    let staleCount: Int
    let forgottenCount: Int
    let contextPressure: Double
    let messageCount: Int
    let daysObserved: Double
    let themeCoherence: Double?

    private static let percentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    var memoryLoadDescriptor: String {
        switch memoryDensityPerDay {
        case ..<5:
            return "light"
        case ..<12:
            return "steady"
        default:
            return "heavy"
        }
    }

    var staleDescriptor: String {
        switch stalePercentage {
        case ..<0.1:
            return "minimal"
        case ..<0.25:
            return "notable"
        default:
            return "high"
        }
    }

    var contextDescriptor: String {
        switch contextPressure {
        case ..<0.4:
            return "roomy"
        case ..<0.7:
            return "balanced"
        default:
            return "tight"
        }
    }

    var formattedStalePercentage: String {
        Self.percentageFormatter.string(from: NSNumber(value: stalePercentage)) ?? "0%"
    }

    var formattedDensity: String {
        Self.decimalFormatter.string(from: NSNumber(value: memoryDensityPerDay)) ?? "0"
    }

    var summaryLines: [String] {
        var lines: [String] = []
        lines.append("- Memory load: \(memoryLoadDescriptor) — \(totalMemories) memories (~\(formattedDensity)/day across \(Int(daysObserved.rounded())) days).")
        let stalePercentString = formattedStalePercentage
        lines.append("- Stale memories: \(staleDescriptor) — \(stalePercentString) (\(staleCount) entries untouched 60+ days, \(forgottenCount) nearing archival).")
        let pressurePercent = Self.percentageFormatter.string(from: NSNumber(value: min(contextPressure, 1.0))) ?? "0%"
        lines.append("- Context window: \(contextDescriptor) — \(messageCount) recent messages (~\(pressurePercent) of comfort range).")
        if let coherence = themeCoherence {
            let coherenceValue = Self.decimalFormatter.string(from: NSNumber(value: coherence)) ?? "0"
            lines.append("- Concept coherence: average relevance \(coherenceValue) (higher = stronger thematic focus).")
        }
        return lines
    }

    var summaryText: String {
        summaryLines.joined(separator: "\n")
    }
}

@MainActor
final class CognitiveHealthService {
    static let shared = CognitiveHealthService()

    private let staleInterval: TimeInterval = 60 * 24 * 60 * 60  // 60 days
    private let contextComfortWindow: Double = 40

    private init() {}

    func snapshot(messages: [AIMessage], modelContext: ModelContext) -> CognitiveHealthSnapshot? {
        let entries = AIRecallService.shared.allEntries(modelContext: modelContext)
        let total = entries.count
        let now = Date()

        let earliestUpdate = entries.map { $0.lastUpdatedAt }.min() ?? now
        let daysObserved = max(1.0, now.timeIntervalSince(earliestUpdate) / (60 * 60 * 24))

        let staleEntries = entries.filter { now.timeIntervalSince($0.lastViewedAt) > staleInterval }
        let staleCount = staleEntries.count
        let stalePercentage = total > 0 ? Double(staleCount) / Double(total) : 0
        let forgottenCount = entries.filter { $0.importance < 0.1 }.count

        let messageCount = messages.count
        let contextPressure = min(1.0, Double(messageCount) / max(contextComfortWindow, 1))

        var themeCoherence: Double? = nil
        if AIConfigService.shared.config.featureFlags.narrativeEnabled {
            let summaries = ConceptTracker.shared.getConceptSummaries(limit: 8, modelContext: modelContext)
            if !summaries.isEmpty {
                let totalWeight = summaries.reduce(0.0) { $0 + $1.relevanceWeight }
                themeCoherence = totalWeight / Double(summaries.count)
            }
        }

        guard total > 0 || messageCount > 0 || themeCoherence != nil else {
            return nil
        }

        let density = total > 0 ? Double(total) / daysObserved : 0

        return CognitiveHealthSnapshot(
            totalMemories: total,
            memoryDensityPerDay: density,
            stalePercentage: stalePercentage,
            staleCount: staleCount,
            forgottenCount: forgottenCount,
            contextPressure: contextPressure,
            messageCount: messageCount,
            daysObserved: daysObserved,
            themeCoherence: themeCoherence
        )
    }
}

