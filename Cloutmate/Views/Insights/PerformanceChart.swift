//
//  PerformanceChart.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import Charts
import CloutmateShared

struct PerformanceChart: View {
    let posts: [CloutmateShared.Post]
    @State private var isVisible = false
    
    private var sortedPosts: [CloutmateShared.Post] {
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
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                
                LineMark(
                    x: .value("Date", publishedDate),
                    y: .value("Engagement", engagementRate)
                )
                .foregroundStyle(Color.gray.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                
                PointMark(
                    x: .value("Date", publishedDate),
                    y: .value("Engagement", engagementRate)
                )
                .foregroundStyle(Color.gray)
                .symbolSize(40)
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
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95)
    }
}

#Preview {
    PerformanceChart(posts: [])
        .frame(height: 200)
        .padding()
}

