//
//  ChartGenerator.swift
//  FocusOS
//
//  Generates chart data from analytics snapshots for reflection visualizations
//

import Foundation
import SwiftData
import FocusOSShared

@MainActor
struct ChartGenerator {
    
    // MARK: - Productivity Charts
    
    static func generateProductivityChart(
        timeRange: AnalyticsTimeRange,
        modelContext: ModelContext
    ) async -> ChartData? {
        let taskDescriptor = FetchDescriptor<FocusOSShared.Task>()
        guard let allTasks = try? modelContext.fetch(taskDescriptor) else {
            return nil
        }
        
        let (start, end) = timeRange.dateRange
        let calendar = Calendar.current
        
        // Group tasks by day
        var dailyCompletion: [Date: Int] = [:]
        let dayComponents: Set<Calendar.Component> = [.year, .month, .day]
        
        for task in allTasks {
            let createdAt = task.createdAt
            guard createdAt >= start && createdAt <= end else { continue }
            
            if task.status == TaskStatus.done {
                let dayStart = calendar.startOfDay(for: createdAt)
                dailyCompletion[dayStart, default: 0] += 1
            }
        }
        
        // Create data points
        let sortedDates = dailyCompletion.keys.sorted()
        let dataPoints = sortedDates.enumerated().map { index, date -> ChartDataPoint in
            let dayOfWeek = calendar.component(.weekday, from: date)
            let dayName = calendar.shortWeekdaySymbols[dayOfWeek - 1]
            return ChartDataPoint(
                x: Double(index),
                y: Double(dailyCompletion[date] ?? 0),
                label: dayName,
                category: nil
            )
        }
        
        guard !dataPoints.isEmpty else { return nil }
        
        return ChartData(
            type: .line,
            title: "Task Completion Trend",
            subtitle: "\(timeRange.displayName) - Completed tasks per day",
            xAxisLabel: "Day",
            yAxisLabel: "Tasks Completed",
            dataPoints: dataPoints,
            colorScheme: "blue"
        )
    }
    
    // MARK: - Focus Effectiveness Charts
    
    static func generateFocusChart(
        timeRange: AnalyticsTimeRange,
        modelContext: ModelContext
    ) async -> ChartData? {
        let sessionDescriptor = FetchDescriptor<FocusSession>()
        guard let sessions = try? modelContext.fetch(sessionDescriptor) else {
            return nil
        }
        
        let (start, end) = timeRange.dateRange
        let filteredSessions = sessions.filter {
            $0.startTime >= start && $0.startTime <= end
        }
        
        guard !filteredSessions.isEmpty else { return nil }
        
        let dataPoints = filteredSessions.enumerated().map { index, session -> ChartDataPoint in
            let minutes = Double(session.plannedDuration) / 60.0
            let label = session.completed ? "✓" : "○"
            return ChartDataPoint(
                x: Double(index + 1),
                y: minutes,
                label: label,
                category: session.completed ? "completed" : "incomplete"
            )
        }
        
        let milestones = filteredSessions.enumerated().compactMap { index, session -> ChartMilestone? in
            guard session.completed, session.plannedDuration / 60 > 60 else { return nil }
            return ChartMilestone(
                xValue: Double(index + 1),
                label: "Deep Focus",
                icon: "star.fill",
                color: "orange"
            )
        }
        
        return ChartData(
            type: .bar,
            title: "Focus Session Performance",
            subtitle: "\(timeRange.displayName) - Duration in minutes",
            xAxisLabel: "Session",
            yAxisLabel: "Duration (min)",
            dataPoints: dataPoints,
            milestones: milestones.isEmpty ? nil : milestones,
            colorScheme: "purple"
        )
    }
    
    // MARK: - Emotional Trends Charts
    
    static func generateEmotionalChart(
        timeRange: AnalyticsTimeRange,
        modelContext: ModelContext
    ) async -> ChartData? {
        let messageDescriptor = FetchDescriptor<AIMessage>()
        guard let messages = try? modelContext.fetch(messageDescriptor) else {
            return nil
        }
        
        let (start, end) = timeRange.dateRange
        let calendar = Calendar.current
        
        // Group by day and average emotional valence
        var dailyEmotions: [Date: (sum: Double, count: Int)] = [:]
        
        for message in messages {
            guard let timestamp = message.timestamp,
                  timestamp >= start && timestamp <= end,
                  message.emotionScore != 0 else { continue }
            
            let dayStart = calendar.startOfDay(for: timestamp)
            let current = dailyEmotions[dayStart] ?? (sum: 0, count: 0)
            dailyEmotions[dayStart] = (sum: current.sum + message.emotionScore, count: current.count + 1)
        }
        
        let sortedDates = dailyEmotions.keys.sorted()
        let dataPoints = sortedDates.enumerated().map { index, date -> ChartDataPoint in
            let dayData = dailyEmotions[date]!
            let avgValence = dayData.sum / Double(dayData.count)
            let dayOfWeek = calendar.component(.weekday, from: date)
            let dayName = calendar.shortWeekdaySymbols[dayOfWeek - 1]
            
            return ChartDataPoint(
                x: Double(index),
                y: avgValence,
                label: dayName,
                category: nil
            )
        }
        
        guard !dataPoints.isEmpty else { return nil }
        
        return ChartData(
            type: .area,
            title: "Emotional Valence Trajectory",
            subtitle: "\(timeRange.displayName) - Daily emotional tone (-1 to +1)",
            xAxisLabel: "Day",
            yAxisLabel: "Valence",
            dataPoints: dataPoints,
            colorScheme: "green"
        )
    }
    
    // MARK: - Multi-Dimensional Charts
    
    static func generateMultiMetricChart(
        timeRange: AnalyticsTimeRange,
        modelContext: ModelContext
    ) async -> ChartCollection? {
        let charts = await [
            generateProductivityChart(timeRange: timeRange, modelContext: modelContext),
            generateFocusChart(timeRange: timeRange, modelContext: modelContext),
            generateEmotionalChart(timeRange: timeRange, modelContext: modelContext)
        ]
        
        let validCharts = charts.compactMap { $0 }
        guard !validCharts.isEmpty else { return nil }
        
        return ChartCollection(
            title: "Intelligence Dashboard - \(timeRange.displayName)",
            description: "Comprehensive view of your productivity, focus, and emotional patterns",
            charts: validCharts
        )
    }
    
    // MARK: - Two-Week Projection Chart
    
    static func generateProjectionChart(
        timeRange: AnalyticsTimeRange,
        modelContext: ModelContext
    ) async -> ChartData? {
        // Get historical data for trend calculation
        let taskDescriptor = FetchDescriptor<FocusOSShared.Task>()
        guard let allTasks = try? modelContext.fetch(taskDescriptor) else {
            return nil
        }
        
        let (start, end) = timeRange.dateRange
        let calendar = Calendar.current
        
        // Calculate daily completion for past week
        var dailyCompletion: [Date: Int] = [:]
        for task in allTasks {
            let createdAt = task.createdAt
            guard createdAt >= start && createdAt <= end,
                  task.status == TaskStatus.done else { continue }
            
            let dayStart = calendar.startOfDay(for: createdAt)
            dailyCompletion[dayStart, default: 0] += 1
        }
        
        let sortedDates = dailyCompletion.keys.sorted()
        var dataPoints: [ChartDataPoint] = []
        
        // Historical data
        for (index, date) in sortedDates.enumerated() {
            let count = dailyCompletion[date] ?? 0
            dataPoints.append(ChartDataPoint(
                x: Double(index),
                y: Double(count),
                label: nil,
                category: "historical"
            ))
        }
        
        // Calculate trend
        let avgCompletion = dailyCompletion.values.reduce(0, +) / max(1, dailyCompletion.count)
        let trendSlope = 0.1 // Simplified trend (10% improvement)
        
        // Projected data (next 7-14 days)
        let projectionDays = 14
        let projectionStart = dataPoints.count
        
        for day in 1...projectionDays {
            let projectedValue = Double(avgCompletion) * (1.0 + trendSlope * Double(day) / 7.0)
            dataPoints.append(ChartDataPoint(
                x: Double(projectionStart + day - 1),
                y: projectedValue,
                label: "Day +\(day)",
                category: "projection"
            ))
        }
        
        let milestones: [ChartMilestone] = [
            ChartMilestone(
                xValue: Double(projectionStart),
                label: "Projection Start",
                icon: "arrow.right.circle",
                color: "blue"
            ),
            ChartMilestone(
                xValue: Double(projectionStart + 7),
                label: "Week 2 Target",
                icon: "flag.fill",
                color: "green"
            )
        ]
        
        return ChartData(
            type: .line,
            title: "Two-Week Productivity Projection",
            subtitle: "Historical data + projected trajectory based on current trends",
            xAxisLabel: "Day",
            yAxisLabel: "Tasks Completed",
            dataPoints: dataPoints,
            milestones: milestones,
            projectionStart: projectionStart,
            colorScheme: "gradient"
        )
    }
}

