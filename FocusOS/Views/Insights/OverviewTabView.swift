//
//  OverviewTabView.swift
//  FocusOS
//

import SwiftUI
import SwiftData
import Charts

struct OverviewTabView: View {
    @Environment(\.modelContext) private var modelContext
    let snapshot: AnalyticsSnapshot?
    let ritualTrend: [(Date, Double)]
    @Query(sort: \ReflectionNote.timestamp, order: .reverse) private var reflections: [ReflectionNote]

    var body: some View {
        if !hasMeaningfulOverviewData {
            ContentUnavailableView(
                "No Overview Data",
                systemImage: "waveform.path.ecg",
                description: Text("Complete focus sessions, rituals, or reflections to unlock overview insights.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 32) {
                currentModeCard
                statsGrid
                EmotionalStateIndicator()
                focusRitualsCard
                recentReflectionsCard
                if let snapshot, snapshot.feedbackEventsCount > 0 { experimentCard(snapshot) }
            }
        }
    }

    private var currentModeCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain.head.profile").font(.system(size: 24)).foregroundColor(KosmicPalette.cyan)
                    Text("Current Mode").font(.system(size: 20, weight: .bold))
                    Spacer()
                }
                if let snapshot, hasMeaningfulSnapshot(snapshot) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(getCurrentMode(from: snapshot))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(KosmicPalette.violet)
                        Text(getModeDescription(from: snapshot))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                } else {
                    ContentUnavailableView(
                        "No Recent Activity",
                        systemImage: "waveform",
                        description: Text("Work with Aurora or log focus sessions to identify your current mode.")
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var statsGrid: some View {
        if let snapshot, hasMeaningfulSnapshot(snapshot) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                IntelligenceStatCard(
                    title: "Emotional Pulse",
                    value: formatEmotionalPulse(),
                    subtitle: "7-day average",
                    icon: "heart.circle.fill",
                    color: getEmotionalColor()
                )
                IntelligenceStatCard(
                    title: "Learning Score",
                    value: String(format: "%.0f%%", snapshot.learningScore * 100),
                    subtitle: "Aurora's growth",
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    color: KosmicPalette.cyan
                )
                IntelligenceStatCard(
                    title: "Active Themes",
                    value: "\(snapshot.activeThemes)",
                    subtitle: "in memory graph",
                    icon: "network",
                    color: KosmicPalette.violet
                )
            }
        } else {
            ContentUnavailableView(
                "No Overview Metrics",
                systemImage: "rectangle.grid.3x2",
                description: Text("Metrics will appear once Aurora has enough recent activity to analyze.")
            )
        }
    }

    private var focusRitualsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "target").foregroundColor(KosmicPalette.violet)
                    Text("Focus Rituals").font(.system(size: 18, weight: .bold))
                    Spacer()
                    if let snapshot {
                        Text(String(format: "%.0f%%", snapshot.ritualCompletionRate * 100))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(KosmicPalette.violet)
                    }
                }
                if let snapshot, snapshot.morningRitualStreak > 0 || snapshot.eveningRitualStreak > 0 || snapshot.nudgeResponseRate > 0 {
                    HStack(spacing: 16) {
                        ritualMetric(title: "Morning Streak", value: "\(snapshot.morningRitualStreak) days")
                        ritualMetric(title: "Evening Streak", value: "\(snapshot.eveningRitualStreak) days")
                        ritualMetric(title: "Nudge Response", value: String(format: "%.0f%%", snapshot.nudgeResponseRate * 100))
                        if let lastReview = snapshot.lastWeeklyReview {
                            ritualMetric(title: "Last Review", value: lastReview.formatted(date: .abbreviated, time: .omitted))
                        } else {
                            ritualMetric(title: "Last Review", value: "Pending")
                        }
                    }
                } else {
                    Text("Ritual metrics will appear once you log a few consistent sessions.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                if !ritualTrend.isEmpty {
                    Chart {
                        ForEach(ritualTrend, id: \.0) { point in
                            LineMark(x: .value("Date", point.0, unit: .day), y: .value("Completion", point.1))
                                .foregroundStyle(KosmicPalette.violet)
                            AreaMark(x: .value("Date", point.0, unit: .day), y: .value("Completion", point.1))
                                .foregroundStyle(KosmicPalette.violet.opacity(0.2))
                        }
                    }
                    .transaction { $0.animation = nil }
                    .frame(height: 120)
                } else {
                    Text("Complete a few rituals to unlock consistency insights.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(18)
        }
    }

    private func ritualMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(size: 16, weight: .bold))
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func experimentCard(_ snapshot: AnalyticsSnapshot) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles").foregroundColor(KosmicPalette.violet)
                    Text("Aurora's Current Experiment").font(.system(size: 16, weight: .semibold))
                }
                Text(getAuroraExperiment(from: snapshot)).font(.system(size: 14)).foregroundColor(.secondary)
            }
            .padding(16)
        }
    }
    
    private var recentReflectionsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "sparkles.rectangle.stack").foregroundColor(KosmicPalette.violet)
                    Text("Recent Reflections").font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                
                if reflections.isEmpty {
                    Text("No reflections yet. Aurora will prompt you when helpful.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(reflections.prefix(3)) { reflection in
                            Button(action: {
                                // Open reflection panel
                                FlowCompanionEngine.shared.shouldShowPanel = true
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(reflection.prompt)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                        Spacer()
                                        Circle()
                                            .fill(sentimentColor(reflection.sentimentScore))
                                            .frame(width: 8, height: 8)
                                    }
                                    Text(reflection.response)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            if reflection.id != reflections.prefix(3).last?.id {
                                Divider()
                            }
                        }
                    }
                    
                    // Sentiment trend
                    HStack(spacing: 8) {
                        ForEach(reflections.prefix(5), id: \.id) { reflection in
                            Circle()
                                .fill(sentimentColor(reflection.sentimentScore))
                                .frame(width: 12, height: 12)
                        }
                        Text("Sentiment trend")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(18)
        }
    }
    
    private func sentimentColor(_ score: Double) -> Color {
        if score > 0.3 {
            return .green
        } else if score < -0.3 {
            return .red
        } else {
            return .gray
        }
    }

    // MARK: - Helper Functions
    
    private func getCurrentMode(from snapshot: AnalyticsSnapshot) -> String {
        let focusScore = snapshot.focusSessionsCount > 0 ? Double(snapshot.focusSessionsCount) : 0
        let taskScore = snapshot.completionRate
        let emotionalScore = abs(snapshot.emotionalSnapshot.valence)
        
        if focusScore > 3 && taskScore > 0.7 {
            return "Deep Work"
        } else if taskScore > 0.5 {
            return "Productive Flow"
        } else if emotionalScore > 0.6 {
            return "High Energy"
        } else if snapshot.feedbackEventsCount > 10 {
            return "Learning Mode"
        } else {
            return "Exploring"
        }
    }
    
    private func getModeDescription(from snapshot: AnalyticsSnapshot) -> String {
        let mode = getCurrentMode(from: snapshot)
        switch mode {
        case "Deep Work":
            return "You're in a highly focused state with multiple deep work sessions. Keep this momentum going."
        case "Productive Flow":
            return "You're completing tasks at a strong pace. Your productivity rhythm is healthy."
        case "High Energy":
            return "Your emotional state is vibrant. Channel this energy into creative work."
        case "Learning Mode":
            return "Aurora is learning rapidly from your patterns. Your feedback loop is strong."
        default:
            return "You're exploring and building habits. Your intelligence system is warming up."
        }
    }
    
    private func formatEmotionalPulse() -> String {
        guard let snapshot = snapshot else { return "--" }
        let valence = snapshot.emotionalSnapshot.valence
        
        if valence > 0.5 {
            return "Positive"
        } else if valence > 0 {
            return "Stable"
        } else if valence > -0.5 {
            return "Reflective"
        } else {
            return "Challenging"
        }
    }
    
    private func getEmotionalColor() -> Color {
        guard let snapshot = snapshot else { return .gray }
        let valence = snapshot.emotionalSnapshot.valence
        
        if valence > 0.5 {
            return .kosmicGreen
        } else if valence > 0 {
            return KosmicPalette.cyan
        } else if valence > -0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func getAuroraExperiment(from snapshot: AnalyticsSnapshot) -> String {
        if snapshot.focusSessionsCount > 5 {
            return "Testing response tone adaptation based on your weekly focus ratio. Aurora is learning to match your energy levels."
        } else if snapshot.completionRate > 0.7 {
            return "Analyzing task completion patterns to predict optimal work times. You've been finishing tasks faster when you tag them by mood."
        } else if snapshot.emotionalTrend == .improving {
            return "Observing emotional continuity patterns. Your positive trend is being factored into recommendation algorithms."
        } else {
            return "Building your baseline cognitive profile. Aurora adapts more intelligently the more you interact."
        }
    }

    private var hasMeaningfulOverviewData: Bool {
        if let snapshot, hasMeaningfulSnapshot(snapshot) { return true }
        if !ritualTrend.isEmpty { return true }
        return false
    }
    
    private func hasMeaningfulSnapshot(_ snapshot: AnalyticsSnapshot) -> Bool {
        let activityMetrics = [
            snapshot.tasksCreated,
            snapshot.tasksCompleted,
            snapshot.focusSessionsCount,
            snapshot.feedbackEventsCount,
            snapshot.activeThemes,
            snapshot.morningRitualStreak,
            snapshot.eveningRitualStreak
        ]
        if activityMetrics.contains(where: { $0 > 0 }) { return true }
        if snapshot.ritualCompletionRate > 0 { return true }
        if snapshot.learningScore > 0 { return true }
        if abs(snapshot.emotionalSnapshot.valence) > 0.05 || snapshot.emotionalSnapshot.intensity > 0.05 { return true }
        return false
    }
}


