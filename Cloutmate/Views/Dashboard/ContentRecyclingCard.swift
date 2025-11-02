//
//  ContentRecyclingCard.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct ContentRecyclingCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.publishedDate, order: .reverse) private var allPosts: [Post]
    @Query(sort: \RecyclablePost.nextSuggestedDate) private var recyclablePosts: [RecyclablePost]
    
    @State private var suggestions: [RecyclablePost] = []
    @State private var isLoading = false
    
    var body: some View {
        GlassCard(showHeader: true, headerContent: {
            AnyView(
                HStack {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundColor(.kosmicGreen)
                    Text("Content Recycling")
                        .font(.headline)
                }
            )
        }) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if suggestions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No posts ready to recycle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Post more content to see recycling suggestions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(suggestions.count) posts ready to recycle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(suggestions.prefix(3)) { recyclable in
                                RecyclingPostRow(recyclable: recyclable)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .onAppear {
            _Concurrency.Task {
                await loadSuggestions()
            }
        }
    }
    
    private func loadSuggestions() async {
        isLoading = true
        defer { isLoading = false }
        
        // Ensure recyclable posts are up to date
        let posts = allPosts.filter { $0.status == "published" }
        _ = await ContentRecyclingService.shared.identifyEvergreenContent(
            posts: posts,
            context: modelContext
        )
        
        // Get suggestions for today
        let todaySuggestions = await ContentRecyclingService.shared.getSuggestionsForToday(context: modelContext)
        
        await MainActor.run {
            self.suggestions = todaySuggestions
        }
    }
}

private struct RecyclingPostRow: View {
    @Environment(\.modelContext) private var modelContext
    
    let recyclable: RecyclablePost
    @State private var isGeneratingVariations = false
    
    private var originalPost: Post? {
        let postId = recyclable.originalPostId
        let descriptor = FetchDescriptor<Post>(
            predicate: #Predicate { $0.id == postId }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let post = originalPost {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.caption.prefix(60) + (post.caption.count > 60 ? "..." : ""))
                            .font(.caption)
                            .lineLimit(2)
                        
                        HStack(spacing: 8) {
                            Label("\(Int(recyclable.engagementScore * 100))%", systemImage: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                            
                            if recyclable.recycleCount > 0 {
                                Label("\(recyclable.recycleCount)x", systemImage: "arrow.clockwise")
                                    .font(.caption2)
                                    .foregroundColor(.kosmicBlue)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        _Concurrency.Task {
                            await generateAndSchedule()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.kosmicBlue)
                    }
                    .buttonStyle(.plain)
                    .disabled(isGeneratingVariations)
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func generateAndSchedule() async {
        guard let post = originalPost else { return }
        
        isGeneratingVariations = true
        defer { isGeneratingVariations = false }
        
        let variations = await ContentRecyclingService.shared.generateVariations(for: post)
        
        guard !variations.isEmpty else { return }
        
        // Use first variation
        await ContentRecyclingService.shared.scheduleRecycledPost(
            recyclable,
            variation: variations.first!,
            context: modelContext
        )
    }
}

