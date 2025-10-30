//
//  HashtagPerformanceView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct HashtagPerformanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.publishedDate, order: .reverse) private var allPosts: [Post]
    @State private var selectedPlatform: Platform = .facebook
    @State private var topHashtags: [HashtagPerformance] = []
    @State private var trendingHashtags: [String] = []
    @State private var hashtagSets: [(HashtagSet, Double)] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hashtag Performance")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Track which hashtags drive engagement and discover new ones")
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
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                if topHashtags.isEmpty {
                    ContentUnavailableView(
                        "No Hashtag Data",
                        systemImage: "number",
                        description: Text("Use hashtags in your posts to see performance insights.")
                    )
                    .frame(height: 200)
                } else {
                    // Hashtag leaderboard
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Performing Hashtags")
                            .font(.headline)
                        
                        Table(topHashtags.prefix(10)) {
                            TableColumn("Hashtag") { hashtag in
                                Text("#\(hashtag.hashtag)")
                            }
                            TableColumn("Avg Engagement") { hashtag in
                                Text(String(format: "%.1f", hashtag.averageEngagement))
                            }
                            TableColumn("Used") { hashtag in
                                Text("\(hashtag.useCount)")
                            }
                            TableColumn("Last Used") { hashtag in
                                if let last = hashtag.lastUsedAt {
                                    Text(last.formatted(date: .abbreviated, time: .shortened))
                                } else {
                                    Text("Never")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(minHeight: 200)
                    }
                }
                
                if !trendingHashtags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trending Hashtags")
                            .font(.headline)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(trendingHashtags, id: \.self) { hashtag in
                                HashtagChip(
                                    hashtag: hashtag,
                                    performance: 0,
                                    isSelected: false,
                                    action: {}
                                )
                            }
                        }
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(12)
                    }
                }
                
                if !hashtagSets.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hashtag Sets")
                            .font(.headline)
                        
                        ForEach(hashtagSets, id: \.0.id) { set, performance in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(set.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(String(format: "%.1f", performance))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                FlowLayout(spacing: 6) {
                                    ForEach(set.hashtags, id: \.self) { hashtag in
                                        HashtagChip(
                                            hashtag: hashtag,
                                            performance: 0,
                                            isSelected: false,
                                            action: {}
                                        )
                                    }
                                }
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .padding()
        .task {
            await loadData()
        }
        .onChange(of: selectedPlatform) { _, _ in
            _Concurrency.Task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Update performance metrics for published posts
        let publishedPosts = allPosts.filter { $0.status == PostStatus.published.rawValue }
        for post in publishedPosts {
            await HashtagPerformanceService.shared.trackHashtagPerformance(post: post, context: modelContext)
        }
        
        let top = await HashtagPerformanceService.shared.getTopPerformingHashtags(
            platform: selectedPlatform,
            limit: 20,
            context: modelContext
        )
        let trending = await HashtagPerformanceService.shared.detectTrendingHashtags(
            platform: selectedPlatform,
            context: modelContext
        )
        let sets = await HashtagPerformanceService.shared.compareHashtagSets(context: modelContext)
        
        await MainActor.run {
            self.topHashtags = top
            self.trendingHashtags = trending
            self.hashtagSets = sets
        }
    }
}

