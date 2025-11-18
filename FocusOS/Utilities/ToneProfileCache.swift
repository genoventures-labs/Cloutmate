//
//  ToneProfileCache.swift
//  FocusOS
//
//  Phase 9: Predictive Reflection Engine
//  Persists ARTE tone coefficients and predictive cognition settings
//

import Foundation
import os.log

/// Snapshot of tone profile configuration returned to callers.
struct ToneProfile {
    var toneWeights: [EmotionalState: Double]
    var lastUpdated: Date
    var confidenceThreshold: Double
    var suppressionFlags: [String: Bool]
    var lastPredictionTimestamp: Date?
}

@MainActor
final class ToneProfileCache {
    static let shared = ToneProfileCache()

    private struct StoredProfile: Codable {
        var toneWeights: [String: Double]
        var lastUpdated: Date
        var confidenceThreshold: Double
        var suppressionFlags: [String: Bool]
        var lastPredictionTimestamp: Date?
        var adaptationTimestamps: [Date]

        static func makeDefault() -> StoredProfile {
            let baselineWeights = Dictionary(uniqueKeysWithValues: EmotionalState.allCases.map { ($0.rawValue, 1.0) })
            return StoredProfile(
                toneWeights: baselineWeights,
                lastUpdated: Date(),
                confidenceThreshold: 0.75,
                suppressionFlags: [:],
                lastPredictionTimestamp: nil,
                adaptationTimestamps: []
            )
        }
    }

    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "ToneProfileCache")
    private let storageKey = "ToneProfileCache"
    private let defaults: UserDefaults
    private var storedProfile: StoredProfile
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? decoder.decode(StoredProfile.self, from: data) {
            self.storedProfile = decoded
        } else {
            self.storedProfile = StoredProfile.makeDefault()
            persist()
        }
    }

    // MARK: - Public API

    func load() -> ToneProfile {
        ToneProfile(
            toneWeights: storedProfile.toneWeights.reduce(into: [:]) { result, entry in
                if let state = EmotionalState(rawValue: entry.key) {
                    result[state] = entry.value
                }
            },
            lastUpdated: storedProfile.lastUpdated,
            confidenceThreshold: storedProfile.confidenceThreshold,
            suppressionFlags: storedProfile.suppressionFlags,
            lastPredictionTimestamp: storedProfile.lastPredictionTimestamp
        )
    }

    func toneWeight(for state: EmotionalState) -> Double {
        storedProfile.toneWeights[state.rawValue] ?? 1.0
    }

    func updateWeight(for state: EmotionalState, to value: Double) {
        storedProfile.toneWeights[state.rawValue] = max(0.0, value)
        storedProfile.lastUpdated = Date()
        recordAdaptation()
        persist()
    }

    func setToneWeights(_ weights: [EmotionalState: Double]) {
        storedProfile.toneWeights = Dictionary(uniqueKeysWithValues: weights.map { ($0.key.rawValue, max(0.0, $0.value)) })
        storedProfile.lastUpdated = Date()
        recordAdaptation()
        persist()
    }

    var confidenceThreshold: Double {
        get { storedProfile.confidenceThreshold }
        set {
            storedProfile.confidenceThreshold = min(max(newValue, 0.0), 1.0)
            storedProfile.lastUpdated = Date()
            persist()
        }
    }

    var suppressionFlags: [String: Bool] {
        storedProfile.suppressionFlags
    }

    func setSuppressionFlag(_ value: Bool, for key: String) {
        storedProfile.suppressionFlags[key] = value
        storedProfile.lastUpdated = Date()
        persist()
    }

    func suppressionFlag(for key: String) -> Bool {
        storedProfile.suppressionFlags[key] ?? false
    }

    var lastPredictionTimestamp: Date? {
        get { storedProfile.lastPredictionTimestamp }
        set {
            storedProfile.lastPredictionTimestamp = newValue
            storedProfile.lastUpdated = Date()
            persist()
        }
    }

    func markPredictionRun(at date: Date = Date()) {
        storedProfile.lastPredictionTimestamp = date
        storedProfile.lastUpdated = date
        persist()
    }

    /// Number of tone adaptations applied within the provided window (default 24h).
    func recentAdaptationCount(within interval: TimeInterval = 86_400) -> Int {
        let threshold = Date().addingTimeInterval(-interval)
        return storedProfile.adaptationTimestamps.filter { $0 >= threshold }.count
    }

    func reset() {
        storedProfile = StoredProfile.makeDefault()
        persist()
    }

    // MARK: - Internal Helpers

    private func recordAdaptation(maxHistory: Int = 50) {
        storedProfile.adaptationTimestamps.append(Date())
        if storedProfile.adaptationTimestamps.count > maxHistory {
            storedProfile.adaptationTimestamps.removeFirst(storedProfile.adaptationTimestamps.count - maxHistory)
        }
    }

    private func persist() {
        do {
            let data = try encoder.encode(storedProfile)
            defaults.set(data, forKey: storageKey)
        } catch {
            logger.error("Failed to persist tone profile: \(error.localizedDescription)")
        }
    }
}


