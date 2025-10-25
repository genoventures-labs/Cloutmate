//
//  ActivityChart.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import Charts

struct ActivityChart: View {
    let posts: [Post]
    
    private var activityData: [ActivityDataPoint] {
        let last14Days = Array(0..<14).map { dayOffset in
            Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
        }.reversed()
        
        return last14Days.map { date in
            let postsOnDay = posts.filter { post in
                guard let postDate = post.scheduledDate ?? post.publishedDate else { return false }
                return Calendar.current.isDate(postDate, inSameDayAs: date)
            }
            return ActivityDataPoint(date: date, count: postsOnDay.count)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Posting Activity")
                .font(.headline)
            
            Chart(activityData) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date, unit: .day),
                    y: .value("Posts", dataPoint.count)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", dataPoint.date, unit: .day),
                    y: .value("Posts", dataPoint.count)
                )
                .foregroundStyle(.blue.opacity(0.2))
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 100)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ActivityDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

#Preview {
    ActivityChart(posts: [])
}

