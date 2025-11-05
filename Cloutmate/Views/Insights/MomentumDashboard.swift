//
//  MomentumDashboard.swift
//  Cloutmate
//
//  Visualizes focus momentum trends for Phase 9 adaptive intelligence.
//

import SwiftUI
import SwiftData
import Combine
import Charts

struct MomentumDashboard: View {
    @Environment(\.modelContext) private var modelContext

    @State private var metrics: MomentumMetrics?
    @State private var trendPoints: [MomentumTrendPoint] = []
    @State private var cancellable: AnyCancellable?

    private let calendar = Calendar.current

    var body: some View {
        GlassCard(showHeader: true) {
            VStack(alignment: .leading, spacing: 16) {
                header
                trendSection
                statsRow
            }
            .padding(20)
        }
        .task {
            metrics = DriftMonitor.shared.latestMomentum ?? calculateSnapshot()
            trendPoints = loadTrendPoints()

            cancellable = DriftMonitor.shared.momentumPublisher
                .receive(on: RunLoop.main)
                .sink { metrics in
                    self.metrics = metrics
                    self.trendPoints = loadTrendPoints()
                }
        }
        .onDisappear {
            cancellable?.cancel()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Momentum")
                    .font(.system(size: 18, weight: .semibold))
                Text("How your focus rhythm is trending")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let metrics {
                FlowStateBadge(flowState: metrics.flowState)
            } else {
                FlowStateBadge(flowState: .steadyFlow)
            }
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completion streak")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Chart(trendPoints) { point in
                LineMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Sessions", point.completedSessions)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.kosmicPurple)

                BarMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Abandoned", point.abandonedSessions)
                )
                .foregroundStyle(Color.kosmicPurple.opacity(0.2))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine().foregroundStyle(Color.gray.opacity(0.1))
                    AxisValueLabel(format: .dateTime.weekday(), centered: true)
                }
            }
            .chartYScale(domain: 0...maxYValue)
            .frame(height: 160)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 18) {
            statTile(
                title: "Streak",
                value: streakText,
                detail: "consecutive days with a completed block"
            )

            statTile(
                title: "Velocity",
                value: velocityText,
                detail: "completed sessions per day"
            )

            statTile(
                title: "Recovery",
                value: recoveryText,
                detail: "avg. bounce-back after stalls"
            )
        }
    }

    private func statTile(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var streakText: String {
        guard let metrics else { return "–" }
        return metrics.streakDays == 1 ? "1 day" : "\(metrics.streakDays) days"
    }

    private var velocityText: String {
        guard let metrics else { return "–" }
        return String(format: "%.2f/day", metrics.completionVelocity)
    }

    private var recoveryText: String {
        guard let metrics else { return "–" }
        if metrics.averageRecoveryTime == 0 {
            return "instant"
        }
        let minutes = metrics.averageRecoveryTime / 60
        return String(format: "%.0fm", minutes)
    }

    private var maxYValue: Double {
        let maxSessions = trendPoints.map { Double($0.completedSessions + $0.abandonedSessions) }.max() ?? 1.0
        return max(1.0, maxSessions + 1.0)
    }

    private func calculateSnapshot() -> MomentumMetrics? {
        DriftMonitor.shared.latestMomentum
    }

    private func loadTrendPoints() -> [MomentumTrendPoint] {
        let now = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -6, to: now) else { return [] }

        var descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= start
            },
            sortBy: [SortDescriptor(\.startTime, order: .forward)]
        )

        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        var buckets: [Date: MomentumTrendPoint] = [:]

        for offset in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: offset, to: start) {
                buckets[day] = MomentumTrendPoint(day: day, completedSessions: 0, abandonedSessions: 0)
            }
        }

        for session in sessions {
            let day = calendar.startOfDay(for: session.startTime)
            guard var point = buckets[day] else { continue }
            if session.status == .completed {
                point.completedSessions += 1
            } else if session.status == .abandoned {
                point.abandonedSessions += 1
            }
            buckets[day] = point
        }

        return buckets.values.sorted { $0.day < $1.day }
    }
}

private struct MomentumTrendPoint: Identifiable {
    let id = UUID()
    let day: Date
    var completedSessions: Int
    var abandonedSessions: Int
}

private struct FlowStateBadge: View {
    let flowState: MomentumMetrics.FlowState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
            Text(flowStateLabel)
        }
        .font(.system(size: 12, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor.opacity(0.15), in: Capsule())
        .foregroundColor(backgroundColor)
    }

    private var flowStateLabel: String {
        switch flowState {
        case .highFlow: return "High Flow"
        case .steadyFlow: return "Steady"
        case .slowingFlow: return "Slowing"
        case .stalled: return "Stalled"
        }
    }

    private var iconName: String {
        switch flowState {
        case .highFlow: return "bolt.fill"
        case .steadyFlow: return "waveform.path"
        case .slowingFlow: return "tortoise.fill"
        case .stalled: return "pause.circle.fill"
        }
    }

    private var backgroundColor: Color {
        switch flowState {
        case .highFlow: return .green
        case .steadyFlow: return .blue
        case .slowingFlow: return .orange
        case .stalled: return .red
        }
    }
}


