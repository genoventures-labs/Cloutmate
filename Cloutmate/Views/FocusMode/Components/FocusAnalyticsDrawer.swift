//
//  FocusAnalyticsDrawer.swift
//  Cloutmate
//
//  Focus Mode V2 - Analytics & Review Drawer
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct FocusAnalyticsDrawer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var snapshot: FocusAnalyticsSnapshot?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if let snapshot {
                        totalSessionsCard(snapshot: snapshot)
                        avgDurationCard(snapshot: snapshot)
                        topDomainsCard(snapshot: snapshot)
                        calmChaosRatioCard(snapshot: snapshot)
                        streakTimelineCard(snapshot: snapshot)
                        predictiveDriftCard(snapshot: snapshot)
                    } else {
                        ContentUnavailableView(
                            "No Focus Data",
                            systemImage: "bolt.slash",
                            description: Text("Start a focus session to unlock analytics.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(24)
            }
            .background(Color(.windowBackgroundColor))
            .navigationTitle("Focus Analytics")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 700, height: 600)
        .task {
            await loadAnalytics()
        }
    }
    
    // MARK: - Cards
    
    private func totalSessionsCard(snapshot: FocusAnalyticsSnapshot) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.kosmicBlue)
                    Text("Total Sessions")
                        .font(.headline)
                    Spacer()
                }
                
                HStack(spacing: 32) {
                    statBlock(title: "\(snapshot.dailyStats.totalSessions)", subtitle: "Today")
                    statBlock(title: "\(snapshot.weeklyStats.totalSessions)", subtitle: "This Week")
                    statBlock(title: "\(snapshot.monthlyStats.totalSessions)", subtitle: "Last 30 Days")
                }
            }
            .padding(20)
        }
    }
    
    private func avgDurationCard(snapshot: FocusAnalyticsSnapshot) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.kosmicPurple)
                    Text("Average Duration")
                        .font(.headline)
                    Spacer()
                }
                
                let avgDuration = snapshot.weeklyStats.averageSessionDuration
                if avgDuration > 0 {
                    Text(formatDuration(avgDuration))
                        .font(.title2)
                        .fontWeight(.bold)
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }
    
    private func topDomainsCard(snapshot: FocusAnalyticsSnapshot) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.kosmicGreen)
                    Text("Top Focus Domains")
                        .font(.headline)
                    Spacer()
                }
                
                if snapshot.topDomains.isEmpty {
                    Text("No domain data yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(snapshot.topDomains.prefix(5)) { domain in
                            HStack {
                                Text(domain.label)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(domain.count)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.kosmicBlue)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    private func calmChaosRatioCard(snapshot: FocusAnalyticsSnapshot) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "heart.circle.fill")
                        .foregroundColor(.kosmicPurple)
                    Text("Calm vs Chaos Ratio")
                        .font(.headline)
                    Spacer()
                }
                
                HStack(spacing: 16) {
                    ratioBlock(value: snapshot.calmRatio, title: "Calm", color: .kosmicGreen)
                    ratioBlock(value: 1 - snapshot.calmRatio, title: "Chaos", color: .orange)
                }
            }
            .padding(20)
        }
    }
    
    private func streakTimelineCard(snapshot: FocusAnalyticsSnapshot) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Streak Timeline")
                        .font(.headline)
                    Spacer()
                }
                
                if snapshot.streakTimeline.isEmpty {
                    Text("Complete sessions to build your streak timeline")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Chart(snapshot.streakTimeline) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Streak", point.streakCount)
                        )
                        .foregroundStyle(.orange)
                        
                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Streak", point.streakCount)
                        )
                        .foregroundStyle(.orange.opacity(0.2))
                    }
                    .transaction { $0.animation = nil }
                    .frame(height: 140)
                }
            }
            .padding(20)
        }
    }
    
    private func predictiveDriftCard(snapshot: FocusAnalyticsSnapshot) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicBlue)
                    Text("Predictive Drift Score")
                        .font(.headline)
                    Spacer()
                }
                
                if let forecast = snapshot.latestForecast {
                    VStack(alignment: .leading, spacing: 12) {
                        metricRow(label: "Focus Stability", value: "\(Int(forecast.focusStability * 100))%", color: .kosmicBlue)
                        let fatigueColor: Color = forecast.fatigueRisk > 0.65 ? .orange : .kosmicGreen
                        metricRow(label: "Fatigue Risk", value: "\(Int(forecast.fatigueRisk * 100))%", color: fatigueColor)
                    }
                } else {
                    Text("No forecast available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Helpers
    
    private func statBlock(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func ratioBlock(value: Double, title: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(Int(value * 100))%")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func metricRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label + ":")
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
        }
    }
    
    private func loadAnalytics() async {
        isLoading = true
        snapshot = FocusAnalyticsService.shared.snapshot(modelContext: modelContext)
        isLoading = false
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}

#Preview {
    FocusAnalyticsDrawer()
        .modelContainer(for: [FocusSession.self, FocusForecast.self])
}

