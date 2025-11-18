//
//  ContentPerformanceChart.swift
//  FocusOS
//
//  Content Performance Chart
//

import SwiftUI
import Charts
import FocusOSShared

struct ContentPerformanceChart: View {
    let posts: [FocusOSShared.Post]
    @Binding var selectedPost: FocusOSShared.Post?
    
    private var chartData: [(type: String, engagement: Double)] {
        let withMedia = posts.filter { !$0.mediaURLs.isEmpty }
        let textOnly = posts.filter { $0.mediaURLs.isEmpty }
        
        let withMediaAvg = averageEngagement(for: withMedia)
        let textOnlyAvg = averageEngagement(for: textOnly)
        
        return [
            ("With Media", withMediaAvg),
            ("Text Only", textOnlyAvg)
        ]
    }
    
    var body: some View {
        Group {
            if chartData.allSatisfy({ $0.engagement == 0 }) {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No content data available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                Chart(chartData, id: \.type) { data in
            BarMark(
                x: .value("Type", data.type),
                y: .value("Engagement", data.engagement)
            )
            .foregroundStyle(by: .value("Type", data.type))
            .cornerRadius(8)
        }
        .chartForegroundStyleScale([
            "With Media": Color.kosmicGreen.opacity(0.7),
            "Text Only": Color.gray.opacity(0.7)
        ])
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel() {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.1f%%", doubleValue))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
            }
        }
    }
    
    private func averageEngagement(for posts: [FocusOSShared.Post]) -> Double {
        let postsWithMetrics = posts.filter { $0.engagementRate != nil }
        guard !postsWithMetrics.isEmpty else { return 0 }
        return postsWithMetrics.reduce(0) { $0 + ($1.engagementRate ?? 0) } / Double(postsWithMetrics.count)
    }
}

#Preview {
    ContentPerformanceChart(posts: [], selectedPost: .constant(nil))
        .frame(height: 300)
        .padding()
}
