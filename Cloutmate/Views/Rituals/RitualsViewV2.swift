//
//  RitualsViewV2.swift
//  Cloutmate
//
//  Rituals V2: Unified ritual experience with guided steps, ARTE-adaptive visuals, and reflection
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct RitualsViewV2: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @StateObject private var ritualManager = FocusRitualManager.shared
    @StateObject private var smartNudgeService = SmartNudgeService.shared
    
    @State private var ritualType: FocusRitualType = .morning
    @State private var steps: [RitualStep] = []
    @State private var currentRitual: FocusRitual?
    @State private var isRitualActive = false
    @State private var completedSteps: Set<UUID> = []
    @State private var reflectionText: String?
    @State private var showJournalView = false
    @State private var showFocusGravityView = false
    @State private var showInsightsView = false
    @State private var ritualStartTime: Date?
    @State private var ritualDuration: TimeInterval = 0
    @State private var ritualTimer: Timer?
    
    var body: some View {
        ZStack {
        ScrollView {
            VStack(spacing: 24) {
                RitualHeaderView(ritualType: ritualType)
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                
                if let nudge = smartNudgeService.latestNudge,
                   nudge.trigger == .reflectionReminder {
                    nudgeCard(nudge)
                        .padding(.horizontal, 28)
                }
                
                CurrentRitualCard(
                    ritualType: ritualType,
                    ritualDuration: ritualDuration,
                    progress: steps.isEmpty ? 0 : Double(completedSteps.count) / Double(steps.count),
                    isRitualActive: isRitualActive && ritualStartTime != nil,
                        onStartRitual: startRitual,
                        onEndEarly: endRitualEarly
                )
                .padding(.horizontal, 28)
                
                if isRitualActive {
                    RitualStepsList(
                        ritualType: ritualType,
                        steps: $steps,
                            onStepComplete: { step in handleStepComplete(step) },
                            onStepSkip: { step in handleStepSkip(step) },
                        onTaskPreviewTap: {
                                withAnimation(GlassMotion.Easing.modalOpen) {
                            showFocusGravityView = true
                                }
                        }
                    )
                    .padding(.horizontal, 28)
                }
                
                if !isRitualActive && !completedSteps.isEmpty && steps.allSatisfy({ completedSteps.contains($0.id) }) {
                    ReflectionSummaryView(
                        ritualType: ritualType,
                        reflectionText: reflectionText,
                        onJournalTap: {
                                withAnimation(GlassMotion.Easing.modalOpen) {
                            showJournalView = true
                                }
                        }
                    )
                    .padding(.horizontal, 28)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                RitualHistoryView(ritualType: ritualType)
                    .padding(.horizontal, 28)
                
                Spacer(minLength: 40)
            }
        }
        .background(Color(.windowBackgroundColor))
            .opacity(drawerVisible ? 0 : 1)
            
            overlayDrawers
        }
        .navigationTitle("Rituals")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Ritual Type", selection: $ritualType) {
                    Text("Morning").tag(FocusRitualType.morning)
                    Text("Evening").tag(FocusRitualType.evening)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .onChange(of: ritualType) { _, newType in
            loadSteps(for: newType)
            Task {
                await loadCurrentRitual(for: newType)
            }
        }
        .task {
            loadSteps(for: ritualType)
            await loadCurrentRitual(for: ritualType)
        }
        .sheet(isPresented: $showFocusGravityView) {
            FocusGravityView()
        }
        .sheet(isPresented: $showInsightsView) {
            InsightsView()
        }
    }
    
    private var drawerVisible: Bool {
        showJournalView
    }
    
    @ViewBuilder
    private var overlayDrawers: some View {
        if showJournalView {
            AuroraDrawer(isPresented: $showJournalView, title: "Reflect & Journal", icon: "book.closed") {
                UnifiedJournalView()
                    .padding(.horizontal, -24)
            }
            .transition(.move(edge: .trailing))
        }
    }
    
    @ViewBuilder
    private func nudgeCard(_ nudge: SmartNudge) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.kosmicPurple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(nudge.message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    if let detail = nudge.detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundColor(glassColorSystem.textSecondary())
                    }
                }
                
                Spacer()
            }
            .padding(16)
        }
    }
    
    private func loadSteps(for type: FocusRitualType) {
        steps = RitualStepConfiguration.steps(for: type)
        completedSteps.removeAll()
    }
    
    @MainActor
    private func loadCurrentRitual(for type: FocusRitualType) async {
        ritualManager.refreshRitualSchedule(modelContext: modelContext)
        
        // Find ritual for this type
        let descriptor = FetchDescriptor<FocusRitual>()
        let allRituals = (try? modelContext.fetch(descriptor)) ?? []
        currentRitual = allRituals.first { $0.type == type }
        
        if let ritual = currentRitual {
            isRitualActive = ritual.status == .inProgress
            
            if ritual.status == .completed {
                // Load reflection if available
                var completionDescriptor = FetchDescriptor<RitualCompletion>(
                    sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
                )
                completionDescriptor.fetchLimit = 1
                if let latestCompletion = try? modelContext.fetch(completionDescriptor).first,
                   latestCompletion.ritualType == type {
                    reflectionText = latestCompletion.aiRecap ?? latestCompletion.userNotes
                }
            }
        }
    }
    
    private func startRitual() {
        guard let ritual = currentRitual else {
            // Create new ritual if none exists
            let schedule = RitualSettings.shared.nextWindow(for: ritualType)
            let newRitual = FocusRitual(
                type: ritualType,
                scheduledFor: Date(),
                windowEnd: schedule.end
            )
            modelContext.insert(newRitual)
            currentRitual = newRitual
            ritualManager.triggerRitual(newRitual, modelContext: modelContext)
            isRitualActive = true
            ritualStartTime = nil // Timer starts when first step is completed
            return
        }
        
        ritualManager.triggerRitual(ritual, modelContext: modelContext)
        isRitualActive = true
        ritualStartTime = nil // Timer starts when first step is completed
        
        // Haptic feedback
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
    
    private func endRitualEarly() {
        guard let ritual = currentRitual else { return }
        
        stopRitualTimer()
        
        // Mark as completed with current progress
        let completedCount = completedSteps.count
        let totalSteps = steps.count
        let outcome: RitualCompletionOutcome = completedCount >= totalSteps / 2 ? .completed : .deferred
        let finalDuration = ritualStartTime != nil ? Date().timeIntervalSince(ritualStartTime!) : 0
        
        let input = RitualCompletionInput(
            outcome: outcome,
            completedAt: Date(),
            duration: finalDuration,
            userNotes: nil,
            aiRecap: nil,
            highlights: ["Completed \(completedCount) of \(totalSteps) steps"],
            focusItemIds: [],
            taskStatusCounts: [:],
            cpsBoostApplied: false,
            momentumDelta: Double(completedCount) / Double(totalSteps) * 0.1,
            metadata: ["source": "rituals-v2", "completed_steps": "\(completedCount)"]
        )
        
        _ = ritualManager.completeRitual(ritual, input: input, modelContext: modelContext)
        isRitualActive = false
        ritualStartTime = nil
        
        // Generate reflection
        generateReflection()
    }
    
    private func handleStepComplete(_ step: RitualStep) {
        // Start timer when first step is completed
        if ritualStartTime == nil && completedSteps.isEmpty {
            ritualStartTime = Date()
            startRitualTimer()
        }
        
        completedSteps.insert(step.id)
        
        // Check if all steps are complete
        if steps.allSatisfy({ completedSteps.contains($0.id) }) {
            stopRitualTimer()
            completeRitual()
        }
    }
    
    private func handleStepSkip(_ step: RitualStep) {
        // Start timer when first step is skipped (same as completing)
        if ritualStartTime == nil && completedSteps.isEmpty {
            ritualStartTime = Date()
            startRitualTimer()
        }
        
        // Mark as completed but with skip flag
        completedSteps.insert(step.id)
        
        // Check if all steps are complete
        if steps.allSatisfy({ completedSteps.contains($0.id) }) {
            stopRitualTimer()
            completeRitual()
        }
    }
    
    private func completeRitual() {
        guard let ritual = currentRitual else { return }
        
        // Calculate final duration
        let finalDuration = ritualStartTime != nil ? Date().timeIntervalSince(ritualStartTime!) : 0
        
        let input = RitualCompletionInput(
            outcome: .completed,
            completedAt: Date(),
            duration: finalDuration,
            userNotes: nil,
            aiRecap: nil,
            highlights: ["Completed all ritual steps"],
            focusItemIds: [],
            taskStatusCounts: [:],
            cpsBoostApplied: ritualType == .morning,
            momentumDelta: 0.15,
            metadata: ["source": "rituals-v2"]
        )
        
        _ = ritualManager.completeRitual(ritual, input: input, modelContext: modelContext)
        isRitualActive = false
        ritualStartTime = nil
        
        // Generate reflection
        generateReflection()
        
        // Haptic feedback
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    private func startRitualTimer() {
        stopRitualTimer()
        ritualTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard let startTime = ritualStartTime else { return }
            DispatchQueue.main.async {
                ritualDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopRitualTimer() {
        ritualTimer?.invalidate()
        ritualTimer = nil
    }
    
    private func generateReflection() {
        let prompt = ritualType == .morning
            ? "Generate a brief, encouraging morning reflection (1-2 sentences) for someone who completed their morning ritual. Focus on clarity and intention. Be warm and supportive."
            : "Generate a brief, reflective evening summary (1-2 sentences) for someone who completed their evening ritual. Acknowledge what moved and what resisted. Be gentle and insightful."
        
        _Concurrency.Task {
            do {
                let response = try await CoreResponseService.shared.generateResponse(
                    for: prompt,
                    modelContext: modelContext
                )
                await MainActor.run {
                    reflectionText = response
                }
            } catch {
                await MainActor.run {
                    reflectionText = ritualType == .morning
                        ? "You seem calmer than usual this morning — focus flow is building."
                        : "Today had its moments. Tomorrow is a fresh start."
                }
            }
        }
    }
}

#Preview {
    do {
        let container = try ModelContainer(
            for: FocusRitual.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return RitualsViewV2()
            .environmentObject(GlassColorSystem())
            .modelContainer(container)
    } catch {
        return Text("Preview unavailable")
    }
}

