//
//  PerformanceChart.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import Charts

struct PerformanceChart: View {
    let posts: [Post]
    
    private var sortedPosts: [Post] {
        posts.compactMap { post in
            guard post.publishedDate != nil, post.engagementRate != nil else { return nil }
            return post
        }.sorted { ($0.publishedDate ?? Date()) < ($1.publishedDate ?? Date()) }
    }
    
    var body: some View {
        Chart(sortedPosts, id: \.id) { post in
            if let publishedDate = post.publishedDate, let engagementRate = post.engagementRate {
                AreaMark(
                    x: .value("Date", publishedDate),
                    y: .value("Engagement", engagementRate)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                
                LineMark(
                    x: .value("Date", publishedDate),
                    y: .value("Engagement", engagementRate)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                
                PointMark(
                    x: .value("Date", publishedDate),
                    y: .value("Engagement", engagementRate)
                )
                .foregroundStyle(Color.blue)
                .symbolSize(60)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel(format: .dateTime.month().day())
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel()
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartBackground { chartProxy in
            Rectangle()
                .fill(Color.clear)
        }
    }
}

#Preview {
    PerformanceChart(posts: [])
        .frame(height: 200)
        .padding()
}

