//
//  CognitiveForecastView.swift
//  Cloutmate
//
//  Insights V2 - Cognitive Forecast Panel
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct CognitiveForecastView: View {
    let snapshot: AnalyticsSnapshot?
    let timeRange: AnalyticsTimeRange
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var themeManager = ReactiveThemeManager.shared
    
    @State private var latestForecast: FocusForecast?
    @State private var forecastHistory: [(Date, Double)] = []
    @State private var driftCount: Int = 0
    @State private var auroraAdvice: String = ""
    
    var body: some View {
        ScrollView {
            contentView
        }
        .task {
            await loadForecastData()
        }
        .onChange(of: timeRange) { _, _ in
            _Concurrency.Task {
                await loadForecastData()
            }
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader
            if let forecast = latestForecast, let nextWindow = forecast.nextFocusWindowStart {
                nextFocusPeakCard(forecast: forecast, nextWindow: nextWindow)
            }
            if let forecast = latestForecast {
                fatigueRiskCard(forecast: forecast)
            }
            if driftCount > 0 {
                driftAlertsCard
            }
            if !auroraAdvice.isEmpty {
                auroraAdviceCard
            }
            if !forecastHistory.isEmpty {
                forecastConfidenceChart
            }
        }
        .padding(.bottom, 40)
    }
    
    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Predictive & Cognitive")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.kosmicBlue, Color.kosmicPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Aurora's forecasts and cognitive insights")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private func nextFocusPeakCard(forecast: FocusForecast, nextWindow: Date) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.kosmicBlue)
                    Text("Next Focus Peak")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Text(formatFocusPeak(nextWindow))
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let endWindow = forecast.nextFocusWindowEnd {
                    Text("Until \(formatTime(endWindow))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .padding(.horizontal, 20)
        .floatLift()
    }
    
    private func fatigueRiskCard(forecast: FocusForecast) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Fatigue Risk")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                
                FatigueRiskMeter(risk: forecast.fatigueRisk)
            }
            .padding(20)
        }
        .padding(.horizontal, 20)
        .floatLift()
    }
    
    private var driftAlertsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Drift Alerts")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Text("\(driftCount) recent deviations from baseline")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .padding(.horizontal, 20)
        .floatLift()
    }
    
    private var auroraAdviceCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicPurple)
                    Text("Aurora's Advice")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Text(auroraAdvice)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .padding(.horizontal, 20)
        .floatLift()
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private var forecastConfidenceChart: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Forecast Confidence")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                
                Chart {
                    ForEach(forecastHistory, id: \.0) { point in
                        LineMark(
                            x: .value("Date", point.0, unit: .day),
                            y: .value("Confidence", point.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.kosmicBlue, Color.kosmicPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Date", point.0, unit: .day),
                            y: .value("Confidence", point.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.kosmicBlue.opacity(0.3), Color.kosmicPurple.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day(), centered: false)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        if let doubleValue = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(doubleValue * 100))%")
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
            .padding(20)
        }
        .padding(.horizontal, 20)
        .floatLift()
    }
    
    // MARK: - Data Loading
    
    private func loadForecastData() async {
        guard let snapshot = snapshot else { return }
        
        // Get latest forecast
        latestForecast = snapshot.latestForecast
        
        // Load forecast history for confidence graph
        let (startDate, endDate) = timeRange.dateRange
        
        let forecastDescriptor = FetchDescriptor<FocusForecast>(
            predicate: #Predicate { forecast in
                forecast.generatedAt >= startDate && forecast.generatedAt <= endDate
            },
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        
        let forecasts = (try? modelContext.fetch(forecastDescriptor)) ?? []
        
        forecastHistory = forecasts.compactMap { forecast in
            if let accuracy = forecast.predictionAccuracy {
                return (forecast.generatedAt, accuracy)
            }
            return nil
        }
        .sorted(by: { $0.0 < $1.0 })
        
        // Calculate drift count (simplified - using forecast accuracy variance)
        driftCount = snapshot.driftEventsCount
        
        // Generate Aurora advice
        if let forecast = latestForecast {
            auroraAdvice = AuroraInsightGenerator.shared.generateForecastAdvice(
                forecast: forecast,
                currentEmotionalState: themeManager.currentState
            )
        }
    }
    
    // MARK: - Helpers
    
    private func formatFocusPeak(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
        }
        
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Fatigue Risk Meter

struct FatigueRiskMeter: View {
    let risk: Double
    
    private var riskColor: Color {
        if risk < 0.3 {
            return .kosmicGreen
        } else if risk < 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var riskLabel: String {
        if risk < 0.3 {
            return "Low"
        } else if risk < 0.6 {
            return "Moderate"
        } else {
            return "High"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(riskLabel)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(riskColor)
                
                Spacer()
                
                Text("\(Int(risk * 100))%")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                    
                    // Risk indicator
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [riskColor, riskColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * risk)
                        .animation(GlassMotion.Easing.spring, value: risk)
                }
            }
            .frame(height: 12)
        }
    }
}

#Preview {
    CognitiveForecastView(
        snapshot: nil,
        timeRange: .thisWeek
    )
    .modelContainer(for: [FocusForecast.self])
    .environmentObject(GlassColorSystem())
    .environmentObject(ReactiveThemeManager.shared)
    .padding()
}

