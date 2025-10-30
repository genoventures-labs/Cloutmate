//
//  ContentGapAnalyzerView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct ContentGapAnalyzerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.publishedDate, order: .reverse) private var allPosts: [Post]
    
    @State private var topics: [ContentTopic] = []
    @State private var contentBalance: ContentBalance?
    @State private var suggestedTopics: [String] = []
    @State private var isAnalyzing = false
    
    private var publishedPosts: [Post] {
        allPosts.filter { $0.status == PostStatus.published.rawValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Content Gap Analyzer")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Understand your content balance and uncover new opportunities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isAnalyzing {
                    ProgressView()
                } else {
                    Button(action: {
                        _Concurrency.Task {
                            await analyzeContent()
                        }
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if topics.isEmpty {
                ContentUnavailableView(
                    "No Insights Yet",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Publish at least 10 posts to unlock content gap analysis.")
                )
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                // Topic distribution chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Topic Distribution")
                        .font(.headline)
                    
                    Chart(topics) { topic in
                        BarMark(
                            x: .value("Posts", topic.postCount),
                            y: .value("Topic", topic.name)
                        )
                        .foregroundStyle(topic.isUnderrepresented ? Color.orange.gradient : Color.blue.gradient)
                    }
                    .frame(height: 220)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                }
                
                // Content balance summary
                if let balance = contentBalance {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Content Balance")
                            .font(.headline)
                        
                        if !balance.contentTypes.isEmpty {
                            Chart(Array(balance.contentTypes.keys), id: \.self) { key in
                                let value = balance.contentTypes[key] ?? 0
                                SectorMark(
                                    angle: .value("Share", value),
                                    innerRadius: .ratio(0.5)
                                )
                                .foregroundStyle(Color.randomGradient(for: key))
                                .annotation(position: .overlay) {
                                    Text("\(key.capitalized)\n\(Int(value * 100))%")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(height: 220)
                        }
                        
                        if !balance.recommendations.isEmpty {
                            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Recommendations")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    ForEach(balance.recommendations, id: \.self) { recommendation in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "lightbulb")
                                                .foregroundColor(.yellow)
                                                .font(.caption)
                                            Text(recommendation)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }
                
                // Suggested topics
                if !suggestedTopics.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suggested Topics")
                            .font(.headline)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(suggestedTopics, id: \.self) { topic in
                                HashtagChip(
                                    hashtag: topic,
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
            }
        }
        .padding()
        .task {
            await analyzeContent()
        }
    }
    
    private func analyzeContent() async {
        guard publishedPosts.count >= 5 else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let service = ContentGapAnalyzerService.shared
        let topics = await service.analyzeTopicClusters(posts: publishedPosts)
        let balance = await service.analyzeContentBalance(posts: publishedPosts)
        let suggestions = await service.suggestTopics(basedOn: topics)
        
        await MainActor.run {
            self.topics = topics
            self.contentBalance = balance
            self.suggestedTopics = suggestions
        }
    }
}

private extension Color {
    static func randomGradient(for key: String) -> LinearGradient {
        let hash = abs(key.hashValue)
        let hue = Double(hash % 360) / 360.0
        let color = Color(hue: hue, saturation: 0.6, brightness: 0.9)
        return LinearGradient(
            gradient: Gradient(colors: [color.opacity(0.8), color.opacity(0.4)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

