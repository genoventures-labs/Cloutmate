//
//  DashboardFooterView.swift
//  Cloutmate
//
//  Dashboard V2 - Footer Zone with Micro Reflection Memory Bubble
//

import SwiftUI
import SwiftData

struct DashboardFooterView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @Query(sort: \FocusSession.startTime, order: .reverse)
    private var allSessions: [FocusSession]
    
    @State private var sessionsToday: Int = 0
    @State private var totalFocusTime: TimeInterval = 0
    @State private var currentStreak: Int = 0
    @State private var memoryBubble: String = ""
    
    let onEndOfDaySummary: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quick Stats
            HStack(spacing: 16) {
                StatCard(
                    title: "Sessions Today",
                    value: "\(sessionsToday)",
                    icon: "timer",
                    color: .kosmicBlue
                )
                
                StatCard(
                    title: "Focus Time",
                    value: formatFocusTime(totalFocusTime),
                    icon: "clock.fill",
                    color: .kosmicPurple
                )
                
                StatCard(
                    title: "Current Streak",
                    value: "\(currentStreak)",
                    icon: "flame.fill",
                    color: .kosmicGreen
                )
            }
            
            // Micro Reflection Memory Bubble
            if !memoryBubble.isEmpty {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundColor(.kosmicPurple.opacity(0.7))
                    Text(memoryBubble)
                        .font(.caption)
                        .foregroundColor(glassColorSystem.textSecondary())
                        .italic()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.kosmicPurple.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.kosmicPurple.opacity(0.2), lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Aurora Quote
            HStack {
                Spacer()
                Text("Momentum begins with awareness.")
                    .font(.subheadline)
                    .foregroundColor(glassColorSystem.textSecondary())
                    .italic()
                Spacer()
            }
            .padding(.top, 8)
            
            // End of Day Summary button
            Button {
                onEndOfDaySummary?()
            } label: {
                HStack {
                    Image(systemName: "moon.stars.fill")
                    Text("End of Day Summary")
                }
                .font(.subheadline)
                .foregroundColor(.kosmicPurple)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.kosmicPurple.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                EmptyView()
            }
        )
        .task {
            await loadData()
        }
    }
    
    @MainActor
    private func loadData() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Calculate sessions today
        sessionsToday = allSessions.filter { calendar.isDate($0.startTime, inSameDayAs: Date()) }.count
        
        // Calculate total focus time today
        totalFocusTime = allSessions
            .filter { calendar.isDate($0.startTime, inSameDayAs: Date()) }
            .reduce(0) { $0 + $1.actualDuration }
        
        // Get current streak from RitualAnalytics
        let summary = RitualAnalytics.shared.generateSummary(for: .thisWeek, modelContext: modelContext)
        currentStreak = max(summary.morningStreak, summary.eveningStreak)
        
        // Generate memory bubble
        await generateMemoryBubble()
    }
    
    @MainActor
    private func generateMemoryBubble() async {
        let currentState = ReactiveThemeManager.shared.currentState
        
        // Find similar past sessions
        let similarSessions = allSessions.filter { session in
            // Match by similar duration (±10 minutes) and time of day (±2 hours)
            let sessionDuration = session.actualDuration
            let sessionHour = Calendar.current.component(.hour, from: session.startTime)
            let currentHour = Calendar.current.component(.hour, from: Date())
            
            return abs(sessionDuration - 1800) < 600 && // Within 10 min of 30 min
                   abs(sessionHour - currentHour) < 2 &&
                   session.startTime < Date().addingTimeInterval(-86400) && // At least 1 day ago
                   session.startTime > Date().addingTimeInterval(-2592000) // Within last 30 days
        }
        
        if let similarSession = similarSessions.first {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            let dayName = dayFormatter.string(from: similarSession.startTime)
            let minutes = Int(similarSession.actualDuration / 60)
            memoryBubble = "You last felt this flow on \(dayName), after \(minutes) minutes"
        } else {
            // Fallback: use ritual completion
            let summary = RitualAnalytics.shared.generateSummary(for: .thisWeek, modelContext: modelContext)
            if let lastReview = summary.lastWeeklyReview {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "EEEE"
                let dayName = dayFormatter.string(from: lastReview)
                memoryBubble = "You last felt this rhythm on \(dayName)"
            }
        }
    }
    
    private func formatFocusTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    DashboardFooterView(onEndOfDaySummary: nil)
        .padding()
        .environmentObject(GlassColorSystem())
}

