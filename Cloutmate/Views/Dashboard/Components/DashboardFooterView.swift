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
        DashboardTile(accent: .kosmicBlue.opacity(0.7), padding: 24) {
            VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                    DashboardStatTile(
                    title: "Sessions Today",
                    value: "\(sessionsToday)",
                    icon: "timer",
                        accent: .kosmicBlue
                )
                
                    DashboardStatTile(
                    title: "Focus Time",
                    value: formatFocusTime(totalFocusTime),
                    icon: "clock.fill",
                        accent: .kosmicPurple
                )
                
                    DashboardStatTile(
                    title: "Current Streak",
                    value: "\(currentStreak)",
                    icon: "flame.fill",
                        accent: .kosmicGreen
                )
            }
            
            if !memoryBubble.isEmpty {
                    DashboardTile(accent: .kosmicPurple.opacity(0.9), padding: 16) {
                        HStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                                .foregroundColor(.kosmicPurple)
                    Text(memoryBubble)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(glassColorSystem.textPrimary())
                        .italic()
                }
                    }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
                Text("Momentum begins with awareness.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(glassColorSystem.textSecondary())
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
            
                GlassButton("End of Day Summary", icon: "moon.stars.fill", style: .pill, role: .accent) {
                onEndOfDaySummary?()
                }
            .frame(maxWidth: .infinity)
        }
        }
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

private struct DashboardStatTile: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    let title: String
    let value: String
    let icon: String
    let accent: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(accent)
            
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(glassColorSystem.textPrimary())
            
            Text(title.uppercased())
                .font(.caption2)
                .foregroundColor(glassColorSystem.textSecondary())
                .tracking(0.6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accent.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent.opacity(0.28), lineWidth: 0.8)
                )
        )
    }
}

#Preview {
    DashboardFooterView(onEndOfDaySummary: nil)
        .padding()
        .environmentObject(GlassColorSystem())
}

