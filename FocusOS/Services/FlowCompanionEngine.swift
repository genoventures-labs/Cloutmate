//
//  FlowCompanionEngine.swift
//  FocusOS
//
//  Phase 10: Central controller for the floating reflection bubble
//

import Foundation
import SwiftData
import Combine
import os.log

@MainActor
final class FlowCompanionEngine: ObservableObject {
    static let shared = FlowCompanionEngine()
    
    @Published var currentPrompt: String?
    @Published var isBubbleVisible: Bool = false
    @Published var shouldShowPanel: Bool = false
    @Published var currentReflectionNote: ReflectionNote?
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "FlowCompanion")
    private var cancellables = Set<AnyCancellable>()
    private var prompts: [String: [String]] = [:]
    private var currentTriggerType: ReflectionTriggerType?
    private var bubbleDismissTimer: Timer?
    private var isRunning = false
    
    private init() {
        loadPrompts()
    }
    
    func start(modelContext: ModelContext) {
        guard !isRunning else { return }
        guard FlowCompanionSettings.shared.isEnabled else { return }
        
        isRunning = true
        logger.info("Starting FlowCompanionEngine")
        
        FlowTriggersService.shared.start(modelContext: modelContext)
        
        // Observe trigger events
        FlowTriggersService.shared.$shouldTriggerReflection
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldTrigger in
                if shouldTrigger {
                    self?.handleTrigger()
                }
            }
            .store(in: &cancellables)
        
        FlowTriggersService.shared.$currentTriggerType
            .receive(on: RunLoop.main)
            .sink { [weak self] triggerType in
                self?.currentTriggerType = triggerType
            }
            .store(in: &cancellables)
    }
    
    func stop() {
        cancellables.removeAll()
        bubbleDismissTimer?.invalidate()
        isRunning = false
        logger.info("Stopped FlowCompanionEngine")
    }
    
    /// Present a reflection prompt
    func presentPrompt(_ type: ReflectionTriggerType) {
        guard FlowCompanionSettings.shared.isEnabled else { return }
        
        let emotion = ReactiveThemeManager.shared.currentEmotion()
        let prompt = selectPrompt(for: emotion, triggerType: type)
        
        currentPrompt = prompt
        currentTriggerType = type
        isBubbleVisible = true
        
        // Auto-dismiss after 45 seconds
        scheduleAutoDismiss()
        
        logger.info("Presenting reflection prompt: \(type.rawValue)")
    }
    
    /// Handle user response
    func handleResponse(_ text: String, modelContext: ModelContext) {
        guard let prompt = currentPrompt, let triggerType = currentTriggerType else { return }
        
        let emotion = ReactiveThemeManager.shared.currentEmotion()
        let note = ReflectionNote(
            prompt: prompt,
            response: text,
            emotionTone: emotion.rawValue,
            contextTag: triggerType.rawValue
        )
        
        // Process reflection
        let metrics = MetaReflectionProcessor.shared.analyze(note, modelContext: modelContext)
        
        // Update CPS weights
        MetaReflectionProcessor.shared.updateCPSWeights(from: note, modelContext: modelContext)
        
        // Feed into momentum tracker
        MetaReflectionProcessor.shared.feedIntoMomentumTracker(note, modelContext: modelContext)
        
        // Sync ARTE if needed
        MetaReflectionProcessor.shared.syncARTEStateIfNeeded(note)
        
        // Save note
        modelContext.insert(note)
        do {
            try modelContext.save()
            logger.info("Saved reflection note")
        } catch {
            logger.error("Failed to save reflection note: \(error.localizedDescription)")
        }
        
        // Record in analytics
        RitualAnalytics.shared.recordReflection(note, modelContext: modelContext)
        
        currentReflectionNote = note
        collapseBubble()
        
        // Show panel for longer responses
        if text.count > 100 {
            shouldShowPanel = true
        }
    }
    
    /// Collapse bubble
    func collapseBubble() {
        isBubbleVisible = false
        currentPrompt = nil
        bubbleDismissTimer?.invalidate()
        FlowTriggersService.shared.acknowledgeTrigger()
    }
    
    /// Expand to full panel
    func expandToPanel() {
        shouldShowPanel = true
        collapseBubble()
    }
    
    // MARK: - Private Methods
    
    private func handleTrigger() {
        guard let triggerType = FlowTriggersService.shared.currentTriggerType else { return }
        presentPrompt(triggerType)
    }
    
    private func selectPrompt(for emotion: EmotionalState, triggerType: ReflectionTriggerType) -> String {
        let emotionKey = emotion.rawValue.lowercased()
        
        // Get prompts for this emotion
        if let emotionPrompts = prompts[emotionKey], !emotionPrompts.isEmpty {
            return emotionPrompts.randomElement() ?? getDefaultPrompt(for: triggerType)
        }
        
        return getDefaultPrompt(for: triggerType)
    }
    
    private func getDefaultPrompt(for triggerType: ReflectionTriggerType) -> String {
        switch triggerType {
        case .drift:
            return "Where did your attention drift just now?"
        case .evening:
            return "What felt most meaningful today?"
        case .idle:
            return "What's on your mind right now?"
        case .manual:
            return "What would you like to reflect on?"
        }
    }
    
    func loadPrompts() {
        guard let url = Bundle.main.url(forResource: "ReflectionPrompts", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String]] else {
            logger.warning("Could not load ReflectionPrompts.plist - using defaults")
            prompts = getDefaultPrompts()
            return
        }
        
        prompts = plist
    }
    
    private func getDefaultPrompts() -> [String: [String]] {
        return [
            "calm": ["What felt most meaningful today?", "What are you noticing about your work?"],
            "fatigued": ["Where did your attention leak?", "What's draining your energy?"],
            "energized": ["What momentum are you riding right now?", "What's working well?"],
            "reflective": ["What surprised you about today?", "What patterns are you seeing?"],
            "focused": ["What's holding your focus?", "What needs your attention?"]
        ]
    }
    
    private func scheduleAutoDismiss() {
        bubbleDismissTimer?.invalidate()
        // Auto-dismiss after at least 1 minute (60 seconds)
        bubbleDismissTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            self?.collapseBubble()
        }
    }
    
    /// Reset the auto-dismiss timer (called when user interacts)
    func resetDismissTimer() {
        scheduleAutoDismiss()
    }
}

