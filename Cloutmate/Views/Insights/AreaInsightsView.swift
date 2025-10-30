//
//  AreaInsightsView.swift
//  Cloutmate
//
//  Area health and publishing analytics
//

import SwiftUI
import SwiftData
import CloutmateShared

struct AreaInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var areas: [Area]
    @Query private var posts: [CloutmateShared.Post]
    @Query private var tasks: [Task]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Text("Area Insights")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding()
                .glassPanel(tier: .overlay, cornerRadius: 12)
                
                // Summary cards
                HStack(spacing: 16) {
                    SummaryCard(
                        icon: "rectangle.stack.fill",
                        title: "Areas",
                        value: "\(areas.count)",
                        color: .blue
                    )
                    SummaryCard(
                        icon: "checkmark.circle",
                        title: "Active Tasks",
                        value: "\(activeTasksCount)",
                        color: .green
                    )
                    SummaryCard(
                        icon: "calendar",
                        title: "Publishing Cadence",
                        value: "\(postsThisWeek)/week avg",
                        color: .purple
                    )
                }
                .padding(.horizontal)
                
                // Area cards
                ForEach(areas) { area in
                    AreaHealthCard(area: area, posts: posts, tasks: tasks)
                        .padding(.horizontal)
                }
            }
        }
        .background(Color.clear)
        .navigationTitle("Area Insights")
    }
    
    var activeTasksCount: Int {
        areas.reduce(0) { total, area in
            total + tasks.filter { $0.areaId == area.id && $0.status != .done }.count
        }
    }
    
    var postsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return posts.filter { post in
            guard let scheduled = post.scheduledDate else { return false }
            return scheduled >= weekAgo
        }.count
    }
}

struct AreaHealthCard: View {
    let area: Area
    let posts: [Post]
    let tasks: [Task]
    
    var areaPosts: [Post] {
        // Posts linked to this area (if we had area post linkage)
        posts.filter { _ in true } // Placeholder - would filter by area
    }
    
    var areaTasks: [Task] {
        tasks.filter { $0.areaId == area.id }
    }
    
    var taskCompletionRate: Double {
        let total = areaTasks.count
        guard total > 0 else { return 0 }
        let completed = areaTasks.filter { $0.status == .done }.count
        return Double(completed) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "rectangle.stack.fill")
                    .foregroundStyle(.blue.gradient)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(area.title)
                        .font(.headline)
                    if let notes = area.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Health indicator
                Circle()
                    .fill(healthColor)
                    .frame(width: 12, height: 12)
            }
            
            Divider()
            
            // Stats
            HStack(spacing: 24) {
                Label("\(areaTasks.count) tasks", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Label("\(Int(taskCompletionRate * 100))% done", systemImage: "chart.bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .glassPanel(tier: .contentCard, cornerRadius: 12)
    }
    
    var healthColor: Color {
        if taskCompletionRate > 0.8 {
            return .green
        } else if taskCompletionRate > 0.5 {
            return .yellow
        } else {
            return .red
        }
    }
}

#Preview {
    AreaInsightsView()
        .modelContainer(for: [Area.self, Post.self, Task.self])
}

