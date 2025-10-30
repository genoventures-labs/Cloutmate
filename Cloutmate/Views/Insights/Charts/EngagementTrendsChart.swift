//
//  EngagementTrendsChart.swift
//  Cloutmate
//
//  Interactive Engagement Trends Chart
//

import SwiftUI
import Charts
import CloutmateShared

struct EngagementTrendsChart: View {
    let posts: [CloutmateShared.Post]
    @Binding var selectedPost: CloutmateShared.Post?
    
    private var sortedPosts: [CloutmateShared.Post] {
        posts.compactMap { post in
            guard post.publishedDate != nil, post.engagementRate != nil else { return nil }
            return post
        }.sorted { ($0.publishedDate ?? Date()) < ($1.publishedDate ?? Date()) }
    }
    
    var body: some View {
        Group {
            if sortedPosts.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No engagement data available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Publish posts to see engagement trends")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                Chart(sortedPosts, id: \.id) { post in
            if let publishedDate = post.publishedDate, let engagementRate = post.engagementRate {
                AreaMark(
                    x: .value("Date", publishedDate),
                    y: .value("Engagement", engagementRate)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                
                LineMark(
                    x: .value("Date", publishedDate),
                    y: .value("Engagement", engagementRate)
                )
                .foregroundStyle(Color.blue.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
                
                PointMark(
                    x: .value("Date", publishedDate),
                    y: .value("Engagement", engagementRate)
                )
                .foregroundStyle(Color.blue)
                .symbolSize(60)
                .opacity(0.7)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, sortedPosts.count / 5))) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
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
        .onTapGesture { location in
            // Find nearest post to tap location
            if let nearestPost = findNearestPost(at: location) {
                selectedPost = nearestPost
            }
        }
            }
        }
    }
    
    private func findNearestPost(at location: CGPoint) -> CloutmateShared.Post? {
        // Simple implementation - returns first post for now
        // Could be enhanced to calculate actual nearest point
        return sortedPosts.first
    }
}

#Preview {
    EngagementTrendsChart(posts: [], selectedPost: .constant(nil))
        .frame(height: 300)
        .padding()
}
