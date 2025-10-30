//
//  PlatformComparisonChart.swift
//  Cloutmate
//
//  Platform Comparison Chart
//

import SwiftUI
import Charts
import CloutmateShared

struct PlatformComparisonChart: View {
    let posts: [CloutmateShared.Post]
    @Binding var selectedPost: CloutmateShared.Post?
    
    private var threadsPosts: [CloutmateShared.Post] {
        posts.filter { $0.postPlatforms.contains(.threads) }
    }
    
    private var facebookPosts: [CloutmateShared.Post] {
        posts.filter { $0.postPlatforms.contains(.facebook) }
    }
    
    private var chartData: [(platform: String, engagement: Double)] {
        let threadsAvg = averageEngagement(for: threadsPosts)
        let facebookAvg = averageEngagement(for: facebookPosts)
        return [
            ("Threads", threadsAvg),
            ("Facebook", facebookAvg)
        ]
    }
    
    var body: some View {
        Group {
            if chartData.allSatisfy({ $0.engagement == 0 }) {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No platform data available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                Chart(chartData, id: \.platform) { data in
            BarMark(
                x: .value("Platform", data.platform),
                y: .value("Engagement", data.engagement)
            )
            .foregroundStyle(by: .value("Platform", data.platform))
            .cornerRadius(8)
        }
        .chartForegroundStyleScale([
            "Threads": Color.purple.opacity(0.7),
            "Facebook": Color.blue.opacity(0.7)
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
    
    private func averageEngagement(for posts: [CloutmateShared.Post]) -> Double {
        let postsWithMetrics = posts.filter { $0.engagementRate != nil }
        guard !postsWithMetrics.isEmpty else { return 0 }
        return postsWithMetrics.reduce(0) { $0 + ($1.engagementRate ?? 0) } / Double(postsWithMetrics.count)
    }
}

#Preview {
    PlatformComparisonChart(posts: [], selectedPost: .constant(nil))
        .frame(height: 300)
        .padding()
}
