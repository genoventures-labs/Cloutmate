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
    @State private var isGeneratingForecast = false
    
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
            
            // Always show Aurora's advice (generate from available data)
            if !auroraAdvice.isEmpty {
                auroraAdviceCard
            } else {
                defaultAdviceCard
            }
            
            // Show forecast data if available
            if let forecast = latestForecast {
                if let nextWindow = forecast.nextFocusWindowStart {
                    nextFocusPeakCard(forecast: forecast, nextWindow: nextWindow)
                }
                fatigueRiskCard(forecast: forecast)
            } else {
                // Fallback: Show basic cognitive insights based on focus patterns
                cognitiveInsightsCard
            }
            
            if driftCount > 0 {
                driftAlertsCard
            }
            
            if !forecastHistory.isEmpty {
                forecastConfidenceChart
            } else {
                // Show a message about building forecast history
                forecastBuildingCard
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
            
            // Manual forecast trigger button
            Button(action: {
                _Concurrency.Task {
                    await triggerForecast()
                }
            }) {
                HStack(spacing: 6) {
                    if isGeneratingForecast {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    Text("Generate Forecast")
                        .font(.system(.caption, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.kosmicBlue.opacity(0.2))
                )
                .foregroundColor(.kosmicBlue)
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingForecast)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private func triggerForecast() async {
        isGeneratingForecast = true
        await CognitionPredictor.shared.triggerPrediction(modelContext: modelContext)
        // Reload data after generating forecast
        await loadForecastData()
        isGeneratingForecast = false
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
    
    private var defaultAdviceCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicPurple)
                    Text("Aurora's Insights")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Text("Continue using focus sessions and rituals to build cognitive forecasts. Aurora learns from your patterns over time.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .padding(.horizontal, 20)
        .floatLift()
    }
    
    private var cognitiveInsightsCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cognitive Insights")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                
                if let snapshot = snapshot {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.kosmicBlue)
                            Text("Focus Completion: \(Int(snapshot.focusCompletionRate * 100))%")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.kosmicPurple)
                            Text("Emotional Trend: \(snapshot.emotionalTrend.rawValue.capitalized)")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        
                        if snapshot.focusSessionsCount > 0 {
                            Text("With \(snapshot.focusSessionsCount) focus sessions tracked, Aurora can start building predictive insights.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(20)
        }
        .padding(.horizontal, 20)
        .floatLift()
    }
    
    private var forecastBuildingCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Building Forecast History")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("As Aurora generates more forecasts and tracks their accuracy, you'll see a confidence graph here showing prediction reliability over time.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .padding(.horizontal, 20)
        .floatLift()
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
        
        // If no forecast exists, try to fetch the most recent one regardless of time range
        if latestForecast == nil {
            var allForecastsDescriptor = FetchDescriptor<FocusForecast>(
                sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
            )
            allForecastsDescriptor.fetchLimit = 1
            latestForecast = (try? modelContext.fetch(allForecastsDescriptor))?.first
        }
        
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
        
        // Generate Aurora advice - always generate something
        if let forecast = latestForecast {
            auroraAdvice = AuroraInsightGenerator.shared.generateForecastAdvice(
                forecast: forecast,
                currentEmotionalState: themeManager.currentState
            )
        } else {
            // Generate advice based on focus patterns and emotional state
            auroraAdvice = generateFallbackAdvice(snapshot: snapshot)
        }
    }
    
    private func generateFallbackAdvice(snapshot: AnalyticsSnapshot) -> String {
        let focusRate = snapshot.focusCompletionRate
        let emotionalTrend = snapshot.emotionalTrend
        let dominantEmotion = snapshot.dominantEmotion
        
        if focusRate > 0.7 && emotionalTrend == .improving {
            return "Your focus patterns are strong and emotions are improving. Consider scheduling your most important work during your peak hours."
        } else if focusRate < 0.5 {
            return "Focus completion is below your usual pace. Try blocking time for deep work and minimizing distractions."
        } else if emotionalTrend == .declining {
            return "Your emotional patterns suggest some challenges. Remember to balance work with reflection and rest."
        } else {
            return "Aurora is learning your cognitive patterns. Continue using focus sessions and rituals to build more accurate forecasts."
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

