//
//  CognitiveForecastCard.swift
//  FocusOS
//
//  Phase 9: Predictive Reflection Engine
//  Displays upcoming cognitive forecasts and accuracy trendlines
//

import SwiftUI
import SwiftData
import Charts

struct CognitiveForecastCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusForecast.generatedAt, order: .reverse)
    private var allForecasts: [FocusForecast]

    @State private var summary: CognitionSummary?

    private var forecasts: [FocusForecast] {
        Array(allForecasts.prefix(7))
    }

    private var latestForecast: FocusForecast? {
        forecasts.first
    }

    private var accuracyPoints: [AccuracyPoint] {
        forecasts.reversed()
            .compactMap { forecast in
                guard let accuracy = forecast.predictionAccuracy else { return nil }
                return AccuracyPoint(date: forecast.generatedAt, value: accuracy)
            }
    }

    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let forecast = latestForecast {
                    focusWindowView(forecast)
                    fatigueRiskView(forecast)
                    toneStatusView(forecast)
                    accuracyTrendView
                } else {
                    emptyState
                }
            }
            .padding(18)
            .onAppear(perform: refreshSummary)
            .onChange(of: forecasts) { _ in refreshSummary() }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundColor(KosmicPalette.cyan)
                .font(.system(size: 22, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text("Cognitive Forecast")
                    .font(.system(size: 18, weight: .semibold))
                if let avgAccuracy = summary?.averageAccuracy {
                    Text("Avg accuracy \(formatPercentage(avgAccuracy)) • Last 24h")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }

    private func focusWindowView(_ forecast: FocusForecast) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next Focus Peak")
                .font(.system(size: 14, weight: .semibold))
            if let window = forecast.nextFocusWindow {
                Text(formatWindow(window))
                    .font(.system(size: 28, weight: .bold))
                Text("Confidence \(formatPercentage(forecast.confidence))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text("Calibrating your next focus window")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func fatigueRiskView(_ forecast: FocusForecast) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Fatigue Risk")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(formatPercentage(forecast.fatigueRisk))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(fatigueColor(for: forecast.fatigueRisk))
            }
            ProgressView(value: forecast.fatigueRisk)
                .tint(fatigueColor(for: forecast.fatigueRisk))
        }
    }

    private func toneStatusView(_ forecast: FocusForecast) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tone Adaptation")
                .font(.system(size: 14, weight: .semibold))
            HStack {
                Label(forecast.toneRecommendation.displayName, systemImage: forecast.toneRecommendation.iconName)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                if let profile = summary {
                    Text("Adaptations: \(profile.toneAdaptationCount)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            if let detail = forecast.metadata["fatigueComponentRitual"],
               let focus = forecast.metadata["fatigueComponentFocus"],
               let arte = forecast.metadata["fatigueComponentArte"] {
                Text("Inputs (ritual \(detail), focus \(focus), ARTE \(arte))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var accuracyTrendView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Forecast Accuracy")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if let falseRate = summary?.falsePositiveRate {
                    Text("False positives \(formatPercentage(falseRate))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            if accuracyPoints.count >= 2 {
                Chart(accuracyPoints) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Accuracy", point.value))
                        .foregroundStyle(KosmicPalette.violet)
                    AreaMark(x: .value("Date", point.date), y: .value("Accuracy", point.value))
                        .foregroundStyle(KosmicPalette.violet.opacity(0.2))
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 90)
            } else {
                Text("Accuracy trend appears once a few forecasts complete")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aurora is calibrating your cognition rhythm")
                .font(.system(size: 14, weight: .semibold))
            Text("Complete a few focus rituals and sessions so Aurora can predict ahead for you.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func refreshSummary() {
        summary = CognitionAnalytics.shared.generateSummary(modelContext: modelContext)
    }

    private func formatWindow(_ interval: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: interval.start)) – \(formatter.string(from: interval.end))"
    }

    private func formatPercentage(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private func fatigueColor(for risk: Double) -> Color {
        switch risk {
        case 0..<0.33: return .kosmicGreen
        case 0.33..<0.66: return .yellow
        default: return .red
        }
    }

    private struct AccuracyPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FocusForecast.self, configurations: config)
    
    return CognitiveForecastCard()
        .frame(width: 320)
        .modelContainer(container)
}


