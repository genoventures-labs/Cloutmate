//
//  AuroraLuminara.swift
//  FocusOS
//
//  Real-time embodied resonance layer aggregating ERI, AECI, and ERS into Luminance Field
//

import Foundation
import SwiftData
import SwiftUI
import os.log
import Combine

@MainActor
final class AuroraLuminara: ObservableObject {
    static let shared = AuroraLuminara()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "AuroraLuminara")
    
    // Current LF cache
    @Published private(set) var currentLF: Double = 0.0
    @Published private(set) var currentCategory: LFCategory = .neutral
    @Published private(set) var particleMotionSpeed: Double = 1.0
    @Published private(set) var particleDensity: Double = 0.5
    @Published private(set) var pulseFrequency: Double = 1.0
    @Published private(set) var lightingIntensity: Double = 0.5
    @Published private(set) var shimmerIntensity: Double = 0.0
    @Published private(set) var lastCalculated: Date?
    
    // Visual feedback enabled
    @Published var isLuminanceFieldEnabled: Bool = true
    @Published var showParticles: Bool = true
    @Published var showPulse: Bool = true
    @Published var showReactiveLighting: Bool = true
    
    var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Luminance Field Calculation
    
    /// Calculate Luminance Field from ERI, AECI, and ERS
    func calculateLuminanceField(
        modelContext: ModelContext
    ) async -> LFHistory? {
        logger.info("Calculating Luminance Field from ERI, AECI, and ERS")
        
        // Get source indices
        let eriIndex = await AuroraEcosphericLayer.shared.getCurrentERI(modelContext: modelContext)
        let aecIndex = await EmotionalContinuityEngine.shared.getCurrentAECI(modelContext: modelContext)
        let ersIndex = await AuroraMetaSymphony.shared.getCurrentERS(modelContext: modelContext)
        
        // Calculate weighted contributions
        // ERI: 35% (ecospheric resonance - system harmony)
        // AECI: 35% (emotional climate - tone consistency)
        // ERS: 30% (emotional resonance - musical alignment)
        let eriContribution = eriIndex * 0.35
        let aecContribution = aecIndex * 0.35
        let ersContribution = ersIndex * 0.30
        
        // Calculate Luminance Field: weighted sum
        let luminanceField = eriContribution + aecContribution + ersContribution
        
        // Clamp to -1.0 to +1.0
        let clampedLF = min(1.0, max(-1.0, luminanceField))
        
        // Create LF history entry
        let history = LFHistory(
            luminanceField: clampedLF,
            eriContribution: eriContribution,
            aecContribution: aecContribution,
            ersContribution: ersContribution,
            eriIndex: eriIndex,
            aecIndex: aecIndex,
            ersIndex: ersIndex
        )
        
        modelContext.insert(history)
        
        // Update cache
        currentLF = clampedLF
        currentCategory = history.category
        particleMotionSpeed = history.particleMotionSpeed
        particleDensity = history.particleDensity
        pulseFrequency = history.pulseFrequency
        lightingIntensity = history.lightingIntensity
        shimmerIntensity = history.shimmerIntensity
        lastCalculated = Date()
        
        do {
            try modelContext.save()
            logger.info("Calculated LF: \(String(format: "%.2f", clampedLF)) (category: \(history.category.rawValue), aurora: \(history.auroraType ?? "unknown"))")
        } catch {
            logger.error("Failed to save LF history: \(error.localizedDescription)")
        }
        
        return history
    }
    
    // MARK: - Visual Parameter Getters
    
    /// Get particle motion speed multiplier
    func getParticleMotionSpeed() -> Double {
        return particleMotionSpeed
    }
    
    /// Get particle density (0.0 to 1.0)
    func getParticleDensity() -> Double {
        return particleDensity
    }
    
    /// Get pulse frequency (Hz)
    func getPulseFrequency() -> Double {
        return pulseFrequency
    }
    
    /// Get lighting intensity (0.0 to 1.0)
    func getLightingIntensity() -> Double {
        return lightingIntensity
    }
    
    /// Get shimmer intensity (0.0 to 1.0)
    func getShimmerIntensity() -> Double {
        return shimmerIntensity
    }
    
    /// Get color temperature (-1.0 to +1.0)
    func getColorTemperature() -> Double {
        // Blend LF with AECI for color temperature
        let aecIndex = EmotionalContinuityEngine.shared.currentAECI
        return (currentLF * 0.6) + (aecIndex * 0.4)
    }
    
    // MARK: - LF History & Emotional Auroras
    
    /// Get LF history for emotional auroras visualization
    func getEmotionalAuroras(
        hours: Int = 24,
        modelContext: ModelContext
    ) async -> [LFHistory] {
        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<LFHistory>(
            predicate: #Predicate<LFHistory> { history in
                history.timestamp >= cutoffDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Get current LF (from cache or calculate)
    func getCurrentLF(modelContext: ModelContext) async -> Double {
        // Check if cache is fresh (within last 30 seconds)
        if let lastCalc = lastCalculated,
           Date().timeIntervalSince(lastCalc) < 30 {
            return currentLF
        }
        
        // Recalculate
        if let history = await calculateLuminanceField(modelContext: modelContext) {
            return history.luminanceField
        }
        
        return 0.0
    }
}

