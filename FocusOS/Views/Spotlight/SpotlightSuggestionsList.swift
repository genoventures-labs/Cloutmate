//
//  SpotlightSuggestionsList.swift
//  FocusOS
//
//  Real-time adaptive suggestions for Aurora Spotlight
//

import SwiftUI
import SwiftData
import FocusOSShared

struct SpotlightSuggestion: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let category: SuggestionCategory
    let icon: String
    let confidence: Double
    let tabIdentifier: TabIdentifier? // For navigation suggestions
    let taskId: UUID? // For task suggestions
    
    enum SuggestionCategory {
        case command
        case navigation
        case task
        case query
    }
}

struct SpotlightSuggestionsList: View {
    let suggestions: [SpotlightSuggestion]
    let onSelect: (SpotlightSuggestion) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(suggestions.prefix(8)) { suggestion in
                    SuggestionRow(suggestion: suggestion) {
                        onSelect(suggestion)
                    }
                    .environmentObject(glassColorSystem)
                }
            }
            .padding(.vertical, 8)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

struct SuggestionRow: View {
    let suggestion: SpotlightSuggestion
    let onTap: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: suggestion.icon)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                
                Text(suggestion.text)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(glassColorSystem.cardColor().opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(glassColorSystem.borderColor().opacity(0.15), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var iconColor: Color {
        switch suggestion.category {
        case .command:
            return glassColorSystem.emotionalAccent()
        case .navigation:
            return glassColorSystem.emotionalAccent()
        case .task:
            return .kosmicGreen
        case .query:
            return glassColorSystem.emotionalAccent()
        }
    }
}

@MainActor
class SpotlightSuggestionsEngine {
    static let shared = SpotlightSuggestionsEngine()
    
    private init() {}
    
    /// Generate suggestions based on query and context
    func generateSuggestions(
        query: String,
        modelContext: ModelContext
    ) -> [SpotlightSuggestion] {
        var suggestions: [SpotlightSuggestion] = []
        
        // Common Aurora commands
        let commonCommands: [(text: String, icon: String)] = [
            ("Start morning ritual", "sunrise.fill"),
            ("Start evening ritual", "moon.stars.fill"),
            ("Start focus session", "timer"),
            ("Reflect today", "brain.head.profile"),
            ("How's my focus?", "gauge.with.dots.needle.67percent"),
            ("Summarize my week", "chart.line.uptrend.xyaxis"),
            ("What's my current focus energy?", "sparkles"),
            ("Create a task", "checkmark.circle.fill"),
            ("Create a note", "note.text"),
            ("Create a project", "folder.fill")
        ]
        
        for command in commonCommands {
            if query.isEmpty || command.text.lowercased().contains(query.lowercased()) {
                suggestions.append(SpotlightSuggestion(
                    text: command.text,
                    category: .command,
                    icon: command.icon,
                    confidence: query.isEmpty ? 0.5 : 0.8,
                    tabIdentifier: nil,
                    taskId: nil
                ))
            }
        }
        
        // Navigation routes
        let navRoutes: [(text: String, tab: TabIdentifier, icon: String)] = [
            ("Go to Projects", .projects, "folder.fill"),
            ("Go to Tasks", .tasks, "checkmark.circle.fill"),
            ("Go to Notes", .notes, "note.text"),
            ("Go to Calendar", .calendar, "calendar"),
            ("Go to Insights", .insights, "chart.line.uptrend.xyaxis"),
            ("Go to AI Assistant", .aiAssistant, "sparkles"),
            ("Go to Focus Mode", .focusMode, "timer"),
            ("Go to Rituals", .rituals, "moon.stars.fill")
        ]
        
        for route in navRoutes {
            if query.isEmpty || route.text.lowercased().contains(query.lowercased()) {
                suggestions.append(SpotlightSuggestion(
                    text: route.text,
                    category: .navigation,
                    icon: route.icon,
                    confidence: query.isEmpty ? 0.4 : 0.7,
                    tabIdentifier: route.tab,
                    taskId: nil
                ))
            }
        }
        
        // Recent tasks (if query matches)
        if !query.isEmpty {
            var taskDescriptor = FetchDescriptor<FocusOSShared.Task>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            taskDescriptor.fetchLimit = 5
            
            if let tasks = try? modelContext.fetch(taskDescriptor) {
                for task in tasks {
                    if task.title.lowercased().contains(query.lowercased()) {
                        suggestions.append(SpotlightSuggestion(
                            text: "Open task: \(task.title)",
                            category: .task,
                            icon: "checkmark.circle.fill",
                            confidence: 0.6,
                            tabIdentifier: .tasks,
                            taskId: task.id
                        ))
                    }
                }
            }
        }
        
        // AI query templates
        let queryTemplates: [(text: String, icon: String)] = [
            ("What's my current focus energy?", "sparkles"),
            ("How was this week?", "chart.line.uptrend.xyaxis"),
            ("What are my top priorities?", "star.fill"),
            ("Show me my productivity patterns", "brain.head.profile"),
            ("When did I last mention...", "clock.fill")
        ]
        
        for template in queryTemplates {
            if query.isEmpty || template.text.lowercased().contains(query.lowercased()) {
                suggestions.append(SpotlightSuggestion(
                    text: template.text,
                    category: .query,
                    icon: template.icon,
                    confidence: query.isEmpty ? 0.3 : 0.6,
                    tabIdentifier: nil,
                    taskId: nil
                ))
            }
        }
        
        // Sort by confidence and remove duplicates
        return Array(Set(suggestions))
            .sorted { $0.confidence > $1.confidence }
            .prefix(8)
            .map { $0 }
    }
}

#Preview {
    SpotlightSuggestionsList(
        suggestions: [
            SpotlightSuggestion(text: "Start morning ritual", category: .command, icon: "sunrise.fill", confidence: 0.8, tabIdentifier: nil, taskId: nil),
            SpotlightSuggestion(text: "Go to Projects", category: .navigation, icon: "folder.fill", confidence: 0.7, tabIdentifier: .projects, taskId: nil),
            SpotlightSuggestion(text: "How's my focus?", category: .query, icon: "gauge.with.dots.needle.67percent", confidence: 0.6, tabIdentifier: nil, taskId: nil)
        ],
        onSelect: { _ in }
    )
    .padding()
    .background(Color.black.opacity(0.3))
    .environmentObject(GlassColorSystem())
}

