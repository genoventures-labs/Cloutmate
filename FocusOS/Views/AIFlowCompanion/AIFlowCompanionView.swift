//
//  AIFlowCompanionView.swift
//  FocusOS
//
//  AI Flow Companion - "Clarity Coach" interface
//

import SwiftUI
import SwiftData
import Combine

struct AIFlowCompanionView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var companion = AIFlowCompanion.shared
    
    @State private var companionState: FlowCompanionState?
    @State private var latestInsight: String?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var selectedPersonality: FlowCompanionPersonality = .clarityCoach
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                personalitySection
                latestInsightSection
                interactionHistorySection
            }
            .padding(28)
        }
        .background(Color(.windowBackgroundColor))
        .task {
            loadCompanionState()
            companion.start(modelContext: modelContext)
            
            // Observe latest insight
            companion.$latestInsight
                .receive(on: RunLoop.main)
                .sink { insight in
                    latestInsight = insight
                }
                .store(in: &cancellables)
        }
        .onDisappear {
            cancellables.removeAll()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Flow Companion")
                .font(.system(size: 28, weight: .bold))
            
            Text("Your clarity coach for maintaining focus and momentum")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
    
    private var personalitySection: some View {
        GlassCard(showHeader: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Personality Mode")
                    .font(.system(size: 18, weight: .semibold))
                
                Picker("Personality", selection: $selectedPersonality) {
                    ForEach(FlowCompanionPersonality.allCases, id: \.self) { personality in
                        Text(personality.displayName).tag(personality)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedPersonality) { _, newValue in
                    updatePersonality(newValue)
                }
                
                Text(personalityDescription(for: selectedPersonality))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding(20)
        }
    }
    
    private var latestInsightSection: some View {
        Group {
            if let insight = latestInsight ?? companionState?.interactionHistory.last {
                GlassCard(showHeader: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Latest Insight")
                                .font(.system(size: 18, weight: .semibold))
                            Spacer()
                            Button(action: {
                                generateNewInsight()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Text(insight)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                    }
                    .padding(20)
                }
            }
        }
    }
    
    private var interactionHistorySection: some View {
        Group {
            if let state = companionState, !state.interactionHistory.isEmpty {
                GlassCard(showHeader: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Interactions")
                            .font(.system(size: 18, weight: .semibold))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(state.interactionHistory.suffix(5).reversed()), id: \.self) { interaction in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 6)
                                    
                                    Text(interaction)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .lineSpacing(2)
                                }
                            }
                        }
                        
                        if state.totalInteractions > 5 {
                            Text("\(state.totalInteractions - 5) more interactions")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    
    private func personalityDescription(for personality: FlowCompanionPersonality) -> String {
        switch personality {
        case .clarityCoach:
            return "Structured, thoughtful guidance. Provides actionable insights and clarifying questions."
        case .momentumGuide:
            return "Focused on maintaining and building productive momentum through pattern recognition."
        case .reflectionPartner:
            return "Helps you understand patterns and make meaning from your work through thoughtful questions."
        }
    }
    
    private func loadCompanionState() {
        let descriptor = FetchDescriptor<FlowCompanionState>()
        if let state = try? modelContext.fetch(descriptor).first {
            companionState = state
            selectedPersonality = state.personality
        }
    }
    
    private func updatePersonality(_ personality: FlowCompanionPersonality) {
        guard var state = companionState else { return }
        state.personality = personality
        do {
            try modelContext.save()
        } catch {
            print("Failed to update personality: \(error)")
        }
    }
    
    private func generateNewInsight() {
        Task {
            let context = FlowCompanionContext(
                momentum: DriftMonitor.shared.latestMomentum,
                emotionalState: ReactiveThemeManager.shared.currentEmotion(),
                activeFocusSession: nil,
                recentRitualCompletion: nil
            )
            
            if let insight = await companion.generateInsight(context: context, modelContext: modelContext) {
                latestInsight = insight
            }
        }
    }
}

