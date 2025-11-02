//
//  ReflectionChartView.swift
//  Cloutmate
//
//  Renders charts for AI reflection responses
//

import SwiftUI
import Charts

/// Main chart rendering view for reflection responses
struct ReflectionChartView: View {
    let chartData: ChartData
    
    @State private var selectedPoint: ChartDataPoint?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Chart header
            VStack(alignment: .leading, spacing: 4) {
                Text(chartData.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let subtitle = chartData.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            // Chart body
            chartView
                .frame(height: 220)
            
            // Milestones legend (if any)
            if let milestones = chartData.milestones, !milestones.isEmpty {
                milestonesView(milestones)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var chartView: some View {
        switch chartData.type {
        case .line:
            lineChartView
        case .bar:
            barChartView
        case .area:
            areaChartView
        case .point:
            pointChartView
        case .multiLine:
            multiLineChartView
        case .heatmap:
            heatmapView
        }
    }
    
    // MARK: - Line Chart
    
    private var lineChartView: some View {
        Chart {
            ForEach(Array(chartData.dataPoints.enumerated()), id: \.element.id) { index, point in
                LineMark(
                    x: .value(chartData.xAxisLabel, point.x),
                    y: .value(chartData.yAxisLabel, point.y)
                )
                .foregroundStyle(chartColor(for: index))
                .interpolationMethod(.catmullRom)
                
                // Projection section (dashed line)
                if let projectionStart = chartData.projectionStart, index >= projectionStart {
                    LineMark(
                        x: .value(chartData.xAxisLabel, point.x),
                        y: .value(chartData.yAxisLabel, point.y)
                    )
                    .foregroundStyle(chartColor(for: index).opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
                
                // Data points
                PointMark(
                    x: .value(chartData.xAxisLabel, point.x),
                    y: .value(chartData.yAxisLabel, point.y)
                )
                .foregroundStyle(chartColor(for: index))
                .symbol(.circle)
                .symbolSize(40)
            }
            
            // Milestone markers
            if let milestones = chartData.milestones {
                ForEach(milestones) { milestone in
                    RuleMark(x: .value("Milestone", milestone.xValue))
                        .foregroundStyle(milestoneColor(milestone).opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [3, 3]))
                        .annotation(position: .top, alignment: .center) {
                            if let icon = milestone.icon {
                                Image(systemName: icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(milestoneColor(milestone))
                            }
                        }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
    
    // MARK: - Bar Chart
    
    private var barChartView: some View {
        Chart(chartData.dataPoints) { point in
            BarMark(
                x: .value(chartData.xAxisLabel, point.label ?? String(format: "%.0f", point.x)),
                y: .value(chartData.yAxisLabel, point.y)
            )
            .foregroundStyle(baseChartColor.gradient)
            .cornerRadius(4)
        }
    }
    
    // MARK: - Area Chart
    
    private var areaChartView: some View {
        Chart(chartData.dataPoints) { point in
            AreaMark(
                x: .value(chartData.xAxisLabel, point.x),
                y: .value(chartData.yAxisLabel, point.y)
            )
            .foregroundStyle(baseChartColor.gradient.opacity(0.3))
            
            LineMark(
                x: .value(chartData.xAxisLabel, point.x),
                y: .value(chartData.yAxisLabel, point.y)
            )
            .foregroundStyle(baseChartColor)
            .interpolationMethod(.catmullRom)
        }
    }
    
    // MARK: - Point Chart
    
    private var pointChartView: some View {
        Chart(chartData.dataPoints) { point in
            PointMark(
                x: .value(chartData.xAxisLabel, point.x),
                y: .value(chartData.yAxisLabel, point.y)
            )
            .foregroundStyle(baseChartColor)
            .symbolSize(60)
        }
    }
    
    // MARK: - Multi-Line Chart
    
    private var multiLineChartView: some View {
        Chart(chartData.dataPoints) { point in
            LineMark(
                x: .value(chartData.xAxisLabel, point.x),
                y: .value(chartData.yAxisLabel, point.y)
            )
            .foregroundStyle(by: .value("Category", point.category ?? "Default"))
            .interpolationMethod(.catmullRom)
            
            PointMark(
                x: .value(chartData.xAxisLabel, point.x),
                y: .value(chartData.yAxisLabel, point.y)
            )
            .foregroundStyle(by: .value("Category", point.category ?? "Default"))
        }
        .chartForegroundStyleScale([
            "Productivity": Color.kosmicBlue,
            "Focus": Color.kosmicPurple,
            "Emotional": Color.kosmicGreen,
            "Learning": Color.orange
        ])
    }
    
    // MARK: - Heatmap View
    
    private var heatmapView: some View {
        // Simplified heatmap using rectangles
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(chartData.dataPoints) { point in
                Rectangle()
                    .fill(heatmapColor(for: point.y))
                    .frame(height: 30)
                    .cornerRadius(4)
                    .overlay(
                        Text(point.label ?? "")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
    // MARK: - Milestones View
    
    private func milestonesView(_ milestones: [ChartMilestone]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Milestones")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            ForEach(milestones) { milestone in
                HStack(spacing: 6) {
                    if let icon = milestone.icon {
                        Image(systemName: icon)
                            .font(.system(size: 10))
                            .foregroundColor(milestoneColor(milestone))
                    }
                    
                    Text(milestone.label)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Color Helpers
    
    private func chartColor(for index: Int) -> Color {
        if let projectionStart = chartData.projectionStart, index >= projectionStart {
            return baseChartColor.opacity(0.6)
        }
        return baseChartColor
    }
    
    private var baseChartColor: Color {
        switch chartData.colorScheme?.lowercased() {
        case "green": return .kosmicGreen
        case "purple": return .kosmicPurple
        case "orange": return .orange
        case "red": return .red
        case "gradient": return .kosmicBlue
        default: return .kosmicBlue
        }
    }
    
    private func milestoneColor(_ milestone: ChartMilestone) -> Color {
        switch milestone.color?.lowercased() {
        case "red": return .red
        case "green": return .kosmicGreen
        case "blue": return .kosmicBlue
        case "orange": return .orange
        case "purple": return .kosmicPurple
        default: return .gray
        }
    }
    
    private func heatmapColor(for value: Double) -> Color {
        // Normalize value to 0-1 range (assuming 0-1 input)
        let intensity = max(0, min(1, value))
        
        if intensity < 0.2 {
            return Color.kosmicBlue.opacity(0.3)
        } else if intensity < 0.4 {
            return Color.kosmicGreen.opacity(0.5)
        } else if intensity < 0.6 {
            return Color.yellow.opacity(0.7)
        } else if intensity < 0.8 {
            return Color.orange.opacity(0.8)
        } else {
            return Color.red
        }
    }
}

/// View for rendering multiple charts in a collection
struct ChartCollectionView: View {
    let collection: ChartCollection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Collection header
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                if let description = collection.description {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Charts
            ForEach(collection.charts, id: \.id) { chart in
                ReflectionChartView(chartData: chart)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        ReflectionChartView(chartData: ChartData(
            type: .line,
            title: "Productivity Trend",
            subtitle: "Tasks completed per day",
            xAxisLabel: "Day",
            yAxisLabel: "Tasks",
            dataPoints: [
                ChartDataPoint(x: 1, y: 3, label: "Mon"),
                ChartDataPoint(x: 2, y: 5, label: "Tue"),
                ChartDataPoint(x: 3, y: 4, label: "Wed"),
                ChartDataPoint(x: 4, y: 7, label: "Thu"),
                ChartDataPoint(x: 5, y: 6, label: "Fri"),
                ChartDataPoint(x: 6, y: 8, label: "Sat (proj)", category: "projection"),
                ChartDataPoint(x: 7, y: 9, label: "Sun (proj)", category: "projection")
            ],
            milestones: [
                ChartMilestone(xValue: 4, label: "Breakthrough", icon: "star.fill", color: "orange")
            ],
            projectionStart: 5,
            colorScheme: "blue"
        ))
        .padding()
    }
}

