//
//  AuroraMetaSymphony.swift
//  FocusOS
//
//  Global meta-conductor interpreting ERI, AECI, and ARTE as musical movements
//

import Foundation
import SwiftData
import SwiftUI
import os.log
import Combine

@MainActor
final class AuroraMetaSymphony: ObservableObject {
    static let shared = AuroraMetaSymphony()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "AuroraMetaSymphony")
    
    // Current ERS cache
    @Published private(set) var currentERS: Double = 0.0
    @Published private(set) var currentCategory: ERSCategory = .neutral
    @Published private(set) var currentMusicalKey: String = "C"
    @Published private(set) var currentTempoBPM: Double = 60.0
    @Published private(set) var isMajorKey: Bool = true
    @Published private(set) var lastCalculated: Date?
    
    // Real-time synchronization
    @Published var ambientAudioEnabled: Bool = false
    @Published var colorGradientSync: Bool = true
    @Published var animationPacingSync: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Subscribe to subsystem changes for real-time updates
        setupSubsystemObservers()
    }
    
    // MARK: - ERS Calculation
    
    /// Calculate Emotional Resonance Score from ERI, AECI, and ARTE
    func calculateERS(
        modelContext: ModelContext
    ) async -> ERSHistory? {
        logger.info("Calculating ERS from ERI, AECI, and ARTE")
        
        // Get source indices
        let eriIndex = await AuroraEcosphericLayer.shared.getCurrentERI(modelContext: modelContext)
        let aecIndex = await EmotionalContinuityEngine.shared.getCurrentAECI(modelContext: modelContext)
        
        // Get ARTE intensity
        let arteIntensity: Double = {
            guard let glassSystem = GlassColorSystem.active else { return 0.7 }
            return glassSystem.emotionalIntensity
        }()
        
        // Calculate component scores
        
        // 1. Cognitive Intent Alignment (from ERI)
        // ERI represents how well subsystems align cognitively
        let cognitiveIntentAlignment = (eriIndex + 1.0) / 2.0 // Normalize -1..1 to 0..1
        
        // 2. Emotional Tone Harmony (from AECI)
        // AECI represents emotional climate and tone consistency
        let emotionalToneHarmony = (aecIndex + 1.0) / 2.0 // Normalize -1..1 to 0..1
        
        // 3. Environmental Rhythm (from ARTE intensity and stability)
        // ARTE intensity represents environmental emotional rhythm
        let environmentalRhythm = arteIntensity // Already 0.0 to 1.0
        
        // Calculate ERS: weighted harmonic alignment
        // Formula: (cognitive * 0.4) + (emotional * 0.35) + (environmental * 0.25)
        let ersIndex = (cognitiveIntentAlignment * 0.4) + (emotionalToneHarmony * 0.35) + (environmentalRhythm * 0.25)
        
        // Transform to -1.0 to +1.0 scale
        let normalizedERS = (ersIndex * 2.0) - 1.0
        
        // Clamp to -1.0 to +1.0
        let clampedERS = min(1.0, max(-1.0, normalizedERS))
        
        // Create ERS history entry
        let history = ERSHistory(
            ersIndex: clampedERS,
            cognitiveIntentAlignment: cognitiveIntentAlignment,
            emotionalToneHarmony: emotionalToneHarmony,
            environmentalRhythm: environmentalRhythm,
            eriIndex: eriIndex,
            aecIndex: aecIndex,
            arteIntensity: arteIntensity
        )
        
        modelContext.insert(history)
        
        // Update cache
        currentERS = clampedERS
        currentCategory = history.category
        currentMusicalKey = history.musicalKey
        currentTempoBPM = history.tempoBPM
        isMajorKey = history.isMajorKey
        lastCalculated = Date()
        
        // Apply real-time synchronization
        await synchronizeAmbientAudio(history: history)
        synchronizeColorGradients(history: history)
        synchronizeAnimationPacing(history: history)
        
        do {
            try modelContext.save()
            logger.info("Calculated ERS: \(String(format: "%.2f", clampedERS)) (key: \(history.musicalKey), tempo: \(String(format: "%.0f", history.tempoBPM)) BPM)")
        } catch {
            logger.error("Failed to save ERS history: \(error.localizedDescription)")
        }
        
        return history
    }
    
    // MARK: - Real-Time Synchronization
    
    /// Synchronize ambient audio with ERS
    private func synchronizeAmbientAudio(history: ERSHistory) async {
        guard ambientAudioEnabled else { return }
        
        // Update audio parameters based on ERS
        // Positive ERS → major key, higher BPM
        // Negative ERS → minor key, lower BPM
        
        logger.info("Synchronizing ambient audio: Key=\(history.musicalKey), Tempo=\(String(format: "%.0f", history.tempoBPM)) BPM, Major=\(history.isMajorKey)")
        
        // TODO: Integrate with actual audio system
        // This would update:
        // - Musical key (major/minor)
        // - Tempo (BPM)
        // - Tonal center (pitch)
        // - Harmonic progression
    }
    
    /// Synchronize color gradients with ERS
    private func synchronizeColorGradients(history: ERSHistory) {
        guard colorGradientSync, let glassSystem = GlassColorSystem.active else { return }
        
        // Update color gradients based on ERS
        // Positive ERS → brighter, warmer gradients
        // Negative ERS → darker, cooler gradients
        
        // ERS influences are already applied through ERI and AECI
        // This is a meta-layer that can add additional gradient modulation
        
        logger.info("Synchronizing color gradients: ERS=\(String(format: "%.2f", history.ersIndex))")
    }
    
    /// Synchronize animation pacing with ERS
    private func synchronizeAnimationPacing(history: ERSHistory) {
        guard animationPacingSync, let glassSystem = GlassColorSystem.active else { return }
        
        // Update animation pacing based on ERS
        // Positive ERS → faster animations
        // Negative ERS → slower animations
        
        // ERS influences are already applied through ERI
        // This is a meta-layer that can add additional pacing modulation
        
        logger.info("Synchronizing animation pacing: Tempo multiplier=\(String(format: "%.2f", history.tempoMultiplier))")
    }
    
    // MARK: - Subsystem Observers
    
    private func setupSubsystemObservers() {
        // Real-time ERS updates are triggered by subsystem changes
        // The ERS is recalculated after each AI response in AIAssistantViewModel
        // This observer setup can be extended for more granular real-time updates if needed
    }
    
    // MARK: - ERS History & Symphonic Timeline
    
    /// Get ERS history for Symphonic Timeline
    func getSymphonicTimeline(
        hours: Int = 24,
        modelContext: ModelContext
    ) async -> [ERSHistory] {
        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<ERSHistory>(
            predicate: #Predicate<ERSHistory> { history in
                history.timestamp >= cutoffDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Get current ERS (from cache or calculate)
    func getCurrentERS(modelContext: ModelContext) async -> Double {
        // Check if cache is fresh (within last 1 minute)
        if let lastCalc = lastCalculated,
           Date().timeIntervalSince(lastCalc) < 60 {
            return currentERS
        }
        
        // Recalculate
        if let history = await calculateERS(modelContext: modelContext) {
            return history.ersIndex
        }
        
        return 0.0
    }
    
    /// Get musical movement type for current ERS
    func getCurrentMovementType() -> String {
        // Classify current ERS as a musical movement
        if currentERS > 0.5 {
            return "overture" // Bright, energetic opening
        } else if currentERS > 0.2 {
            return "development" // Building, evolving
        } else if currentERS > -0.2 {
            return "recapitulation" // Returning, reflective
        } else {
            return "coda" // Closing, resolving
        }
    }
    
    // MARK: - Musical Parameter Getters
    
    /// Get current musical key
    func getCurrentMusicalKey() -> String {
        return currentMusicalKey
    }
    
    /// Get current tempo (BPM)
    func getCurrentTempoBPM() -> Double {
        return currentTempoBPM
    }
    
    /// Get tempo multiplier for animations
    func getTempoMultiplier() -> Double {
        return 1.0 + (currentERS * 0.3) // Maps -1.0→0.7x, +1.0→1.3x
    }
    
    /// Get tonal center (-1.0 to +1.0)
    func getTonalCenter() -> Double {
        // Blend ERS with AECI for tonal center
        // This would be calculated from current AECI if available
        return currentERS * 0.6 // Simplified
    }
}

