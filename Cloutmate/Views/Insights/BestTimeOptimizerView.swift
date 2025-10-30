//
//  BestTimeOptimizerView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct BestTimeOptimizerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.publishedDate, order: .reverse) private var allPosts: [Post]
    @Query(sort: \PostingTimeTest.testStartDate, order: .reverse) private var activeTests: [PostingTimeTest]
    
    @State private var heatmapData: [[Double]] = Array(repeating: Array(repeating: 0, count: 24), count: 7)
    @State private var suggestedTimes: [Date] = []
    @State private var isLoading = false
    @State private var selectedPlatform: Platform = .facebook
    
    private var publishedPosts: [Post] {
        allPosts.filter { $0.status == PostStatus.published.rawValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best Time Optimizer")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Find the perfect time to post for maximum engagement")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Picker("Platform", selection: $selectedPlatform) {
                    ForEach(Platform.allCases, id: \.self) { platform in
                        Text(platform.displayName).tag(platform)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            
            // Heatmap
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Engagement Heatmap")
                        .font(.headline)
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Button(action: {
                            _Concurrency.Task {
                                await refreshHeatmap()
                            }
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                HeatmapView(data: heatmapData)
                    .frame(height: 220)
            }
            
            // Suggested times list
            VStack(alignment: .leading, spacing: 12) {
                Text("Suggested Times")
                    .font(.headline)
                
                if suggestedTimes.isEmpty {
                    Text("Insufficient data to provide suggestions. Publish more posts to unlock this feature.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(suggestedTimes.enumerated()), id: \.offset) { index, date in
                        HStack {
                            Label("\(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                                .font(.subheadline)
                            Spacer()
                            if index == 0 {
                                Text("Best")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(6)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Active tests
            if !activeTests.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active A/B Tests")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        ForEach(activeTests) { test in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Test \(test.id.uuidString.prefix(6))")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(test.status == .active ? "Active" : "Completed")
                                        .font(.caption)
                                        .foregroundColor(test.status == .active ? .blue : .secondary)
                                }
                                
                                HStack(spacing: 12) {
                                    Label("Variants: \(test.testVariants.count)", systemImage: "square.grid.3x1.folder.fill")
                                        .font(.caption)
                                    if let winning = test.winningTime {
                                        Label(
                                            "Winner: \(winning.formatted(date: .omitted, time: .shortened))",
                                            systemImage: "checkmark.circle"
                                        )
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .padding()
        .task {
            await refreshHeatmap()
        }
    }
    
    private func refreshHeatmap() async {
        guard publishedPosts.count >= 5 else {
            await MainActor.run {
                heatmapData = Array(repeating: Array(repeating: 0, count: 24), count: 7)
                suggestedTimes = []
            }
            return
        }
        isLoading = true
        defer { isLoading = false }
        
        await BestTimeOptimizerService.shared.learnFromHistory(posts: publishedPosts, context: modelContext)
        
        // buildPostingHeatmap is synchronous and not actor-isolated
        // but we need to await the actor to call it
        let (platform, posts) = await MainActor.run {
            (selectedPlatform, publishedPosts)
        }
        let heatmap = BestTimeOptimizerService.shared.buildPostingHeatmap(
            platform: platform,
            posts: posts
        )
        let suggestions = await BestTimeOptimizerService.shared.suggestOptimalTimes(
            platform: selectedPlatform,
            context: modelContext
        )
        
        await MainActor.run {
            self.heatmapData = heatmap
            self.suggestedTimes = suggestions
        }
    }
}

private struct HeatmapView: View {
    let data: [[Double]]
    private let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / 24
            let cellHeight = geometry.size.height / 7
            
            VStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { day in
                    HStack(spacing: 0) {
                        Text(days[day])
                            .font(.caption2)
                            .frame(width: 30)
                            .padding(4)
                        
                        ForEach(0..<24, id: \.self) { hour in
                            Rectangle()
                                .fill(color(for: data[day][hour]))
                                .frame(width: cellWidth, height: cellHeight)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
        }
        .frame(minHeight: 200)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func color(for value: Double) -> Color {
        let normalized = min(1.0, max(0.0, value / 10.0))
        return Color(.sRGB, red: 0.2, green: normalized, blue: 0.3, opacity: normalized + 0.1)
    }
}

