//
//  AuroraInsightsDrawer.swift
//  Cloutmate
//
//  Dashboard V2 - Aurora Insights Drawer Side Panel
//

import SwiftUI
import SwiftData

struct AuroraInsightsDrawer: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.dismiss) private var dismiss
    
    @Binding var isPresented: Bool
    
    @State private var forecast: FocusForecast?
    @State private var trends: String = ""
    @State private var focusIntent: String = ""
    @State private var emotionalSummary: String = ""
    @State private var smallWins: String = ""
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Aurora Insights")
                            .font(.headline)
                            .foregroundColor(glassColorSystem.textPrimary())
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(glassColorSystem.textSecondary())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [.kosmicGreen.opacity(0.2), .kosmicBlue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    
                    // Content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Today's Forecast
                            if let forecast = forecast {
                                InsightSection(
                                    title: "Today's Forecast",
                                    content: forecastContent(forecast)
                                )
                            }
                            
                            // Behavioral Trends
                            if !trends.isEmpty {
                                InsightSection(
                                    title: "Behavioral Trends",
                                    content: trends
                                )
                            }
                            
                            // Suggested Focus Intent
                            if !focusIntent.isEmpty {
                                InsightSection(
                                    title: "Suggested Focus Intent",
                                    content: focusIntent
                                )
                            }
                            
                            // Emotional Summary
                            if !emotionalSummary.isEmpty {
                                InsightSection(
                                    title: "Emotional Summary",
                                    content: emotionalSummary
                                )
                            }
                            
                            // Small Wins
                            if !smallWins.isEmpty {
                                InsightSection(
                                    title: "Small Wins",
                                    content: smallWins
                                )
                            }
                        }
                        .padding(20)
                    }
                }
                .frame(width: min(400, geometry.size.width * 0.4))
                .background(
                    GlassPanel(tier: .contentCard, cornerRadius: 0) {
                        EmptyView()
                    }
                )
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width > 100 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isPresented = false
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
        }
        .background(Color.black.opacity(0.3))
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPresented = false
            }
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        .task {
            await loadInsights()
        }
    }
    
    private func forecastContent(_ forecast: FocusForecast) -> String {
        var content = "Fatigue Risk: \(Int(forecast.fatigueRisk * 100))%\n"
        content += "Focus Stability: \(Int(forecast.focusStability * 100))%\n"
        content += "Energy Trend: \(forecast.energyTrend.displayName)"
        if let window = forecast.nextFocusWindow {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            let startTime = timeFormatter.string(from: window.start)
            let endTime = timeFormatter.string(from: window.end)
            content += "\n\nNext Focus Window: \(startTime) - \(endTime)"
        }
        return content
    }
    
    @MainActor
    private func loadInsights() async {
        // Load forecast
        forecast = CognitionPredictor.shared.fetchLatestForecast(modelContext: modelContext)
        
        // Load trends (simplified)
        trends = "Your productivity patterns show consistent morning focus sessions."
        
        // Load focus intent
        let priorities = PriorityEngine.shared.getTopObjects(limit: 3, modelContext: modelContext)
        if !priorities.isEmpty {
            focusIntent = "Top priorities: \(priorities.map { $0.title }.joined(separator: ", "))"
        }
        
        // Load emotional summary
        let state = ReactiveThemeManager.shared.currentState
        emotionalSummary = "Current state: \(state.displayName). \(state.description)"
        
        // Load small wins
        let summary = RitualAnalytics.shared.generateSummary(for: .thisWeek, modelContext: modelContext)
        if summary.morningStreak > 0 || summary.eveningStreak > 0 {
            smallWins = "Maintaining \(max(summary.morningStreak, summary.eveningStreak)) day ritual streak!"
        }
    }
}

struct InsightSection: View {
    let title: String
    let content: String
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(glassColorSystem.textSecondary())
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(glassColorSystem.cardColor().opacity(0.5))
        .cornerRadius(8)
    }
}

#Preview {
    AuroraInsightsDrawer(isPresented: .constant(true))
        .environmentObject(GlassColorSystem())
}

