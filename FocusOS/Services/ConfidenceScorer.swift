//
//  ConfidenceScorer.swift
//  FocusOS
//
//  Computes Aurora's response confidence from recall, context freshness, and intent signals.
//

import Foundation

struct ConfidenceSnapshot: Sendable {
    enum Level: String, Sendable {
        case low
        case medium
        case high
    }

    let score: Double
    let level: Level
    let factors: [String]
    let toneGuidance: String
    let recallScore: Double?
    let contextAge: TimeInterval?
    let intentConfidence: Double?

    var formattedScore: String {
        String(format: "%.2f", score)
    }

    var promptDirective: String {
        switch level {
        case .high:
            return "Confidence is high. You can answer with warm assurance while staying humble and open."
        case .medium:
            return "Confidence is moderate. Use softer language like 'I think' or 'It looks like', and invite the user to confirm if they'd like."
        case .low:
            return "Confidence is low. Be transparent about uncertainty, share what you do know, and suggest next steps or clarifying questions."
        }
    }
}

enum ConfidenceScorer {
    private struct Weights {
        static let recall: Double = 0.45
        static let context: Double = 0.25
        static let intent: Double = 0.30
    }

    static func evaluate(
        recallSnippets: [RecallSnippet],
        intentSummary: IntentClusterSummary?,
        contextAge: TimeInterval?
    ) -> ConfidenceSnapshot {
        let topRecallScore = recallSnippets.first?.score
        let recallComponent = clamp(topRecallScore ?? 0.55)

        let contextComponent = contextConfidence(from: contextAge)
        let intentComponent = clamp(intentSummary?.confidence ?? 0.6)

        let weightedScore = clamp(
            (recallComponent * Weights.recall) +
            (contextComponent * Weights.context) +
            (intentComponent * Weights.intent)
        )

        let level: ConfidenceSnapshot.Level
        switch weightedScore {
        case 0.75...:
            level = .high
        case 0.5..<0.75:
            level = .medium
        default:
            level = .low
        }

        var factors: [String] = []
        if let recall = topRecallScore {
            if recall >= 0.75 {
                factors.append("Strong recall match (score \(String(format: "%.2f", recall))).")
            } else if recall >= 0.5 {
                factors.append("Partial recall alignment (score \(String(format: "%.2f", recall))).")
            } else {
                factors.append("Limited recall overlap (score \(String(format: "%.2f", recall))).")
            }
        } else {
            factors.append("No prior recall match available; relying on general knowledge.")
        }

        if let age = contextAge {
            let minutes = age / 60
            if minutes < 5 {
                factors.append("App context is fresh (updated ~\(Int(round(minutes)))m ago).")
            } else if minutes < 30 {
                factors.append("App context is moderately fresh (~\(Int(round(minutes)))m old).");
            } else {
                let hours = Int(round(minutes / 60))
                factors.append("App context may be stale (~\(hours)h old); consider refreshing soon.")
            }
        } else {
            factors.append("Context freshness unknown; using cached signals.")
        }

        if let intent = intentSummary?.confidence {
            if intent >= 0.75 {
                factors.append("Intent prediction is confident (\(String(format: "%.2f", intent))).")
            } else if intent >= 0.5 {
                factors.append("Intent prediction is plausible (\(String(format: "%.2f", intent))).")
            } else {
                factors.append("Intent prediction is tentative (\(String(format: "%.2f", intent))).")
            }
        } else {
            factors.append("No recent intent clusters available; improvising from conversation flow.")
        }

        let toneGuidance: String
        switch level {
        case .high:
            toneGuidance = "You sound sure-footed. Answer with grounded clarity, but stay open to follow-ups."
        case .medium:
            toneGuidance = "You're moderately sure. Soften assertions and leave space for collaboration."
        case .low:
            toneGuidance = "Signal the uncertainty kindly, offer what you can, and suggest next steps or clarifiers."
        }

        return ConfidenceSnapshot(
            score: weightedScore,
            level: level,
            factors: factors,
            toneGuidance: toneGuidance,
            recallScore: topRecallScore,
            contextAge: contextAge,
            intentConfidence: intentSummary?.confidence
        )
    }

    private static func contextConfidence(from age: TimeInterval?) -> Double {
        guard let age = age else { return 0.6 }
        switch age {
        case ..<300: // under 5 minutes
            return 1.0
        case ..<1800: // under 30 minutes
            return 0.7
        case ..<7200: // under 2 hours
            return 0.45
        case ..<21600: // under 6 hours
            return 0.3
        default:
            return 0.2
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
}

