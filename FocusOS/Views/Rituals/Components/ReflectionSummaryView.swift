//
//  ReflectionSummaryView.swift
//  FocusOS
//
//  Rituals V2: Aurora-generated reflection summary with journal integration
//

import SwiftUI
import SwiftData

struct ReflectionSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @StateObject private var reactiveThemeManager = ReactiveThemeManager.shared
    
    let ritualType: FocusRitualType
    let reflectionText: String?
    let onJournalTap: () -> Void
    
    @State private var aiReflection: String?
    @State private var isGenerating = false
    @State private var showJournalSheet = false
    
    var body: some View {
        if let reflection = aiReflection ?? reflectionText {
            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                            .foregroundColor(emotionalAccentColor)
                        
                        Text("Aurora's Reflection")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(glassColorSystem.textPrimary())
                        
                        Spacer()
                        
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    
                    Text(reflection)
                        .font(.system(size: 14))
                        .foregroundColor(glassColorSystem.textSecondary())
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Emotional state indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(emotionalAccentColor)
                            .frame(width: 8, height: 8)
                        
                        Text("Emotional state: \(reactiveThemeManager.currentState.rawValue.capitalized)")
                            .font(.system(size: 12))
                            .foregroundColor(glassColorSystem.textSecondary())
                    }
                    
                    Divider()
                    
                    Button {
                        createJournalEntry(reflection: reflection)
                        onJournalTap()
                    } label: {
                        HStack {
                            Image(systemName: "book.fill")
                            Text("Journal this reflection")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [emotionalAccentColor, emotionalAccentColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else if !isGenerating {
            // Generate reflection button
            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(emotionalAccentColor.opacity(0.6))
                    
                    Text("Generate reflection")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    Text("Aurora will create a personalized reflection based on your ritual")
                        .font(.system(size: 13))
                        .foregroundColor(glassColorSystem.textSecondary())
                        .multilineTextAlignment(.center)
                    
                    Button {
                        generateReflection()
                    } label: {
                        Text("Generate")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(emotionalAccentColor)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
        }
    }
    
    private var emotionalAccentColor: Color {
        switch reactiveThemeManager.currentState {
        case .calm:
            return .kosmicBlue
        case .energized:
            return .kosmicGreen
        case .focused:
            return .kosmicBlue
        case .reflective:
            return .kosmicPurple
        case .fatigued:
            return .kosmicPurple.opacity(0.7)
        }
    }
    
    private func generateReflection() {
        isGenerating = true
        
        let prompt = ritualType == .morning
            ? "Generate a brief, encouraging morning reflection (1-2 sentences) for someone starting their day. Focus on clarity and intention. Be warm and supportive."
            : "Generate a brief, reflective evening summary (1-2 sentences) for someone ending their day. Acknowledge what moved and what resisted. Be gentle and insightful."
        
        _Concurrency.Task {
            do {
                let response = try await CoreResponseService.shared.generateResponse(
                    for: prompt,
                    modelContext: modelContext
                )
                await MainActor.run {
                    aiReflection = response
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    aiReflection = ritualType == .morning
                        ? "You seem calmer than usual this morning — focus flow is building."
                        : "Today had its moments. Tomorrow is a fresh start."
                    isGenerating = false
                }
            }
        }
    }
    
    private func createJournalEntry(reflection: String) {
        let journal = Journal(
            title: "Ritual Reflection - \(Date().formatted(date: .abbreviated, time: .omitted))",
            content: reflection,
            entryDate: Date(),
            entryType: .reflection,
            mood: moodFromEmotionalState(reactiveThemeManager.currentState),
            tags: ["ritual", ritualType.rawValue]
        )
        journal.author = .aurora
        
        modelContext.insert(journal)
        try? modelContext.save()
    }
    
    private func moodFromEmotionalState(_ state: EmotionalState) -> JournalMood {
        switch state {
        case .energized:
            return .motivated
        case .calm:
            return .calm
        case .reflective:
            return .reflective
        case .focused:
            return .motivated
        case .fatigued:
            return .contemplative
        }
    }
}

#Preview {
    ReflectionSummaryView(
        ritualType: .morning,
        reflectionText: nil,
        onJournalTap: {}
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

