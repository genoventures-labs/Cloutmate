//
//  HashtagSuggestionPanel.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct HashtagSuggestionPanel: View {
    @Environment(\.modelContext) private var modelContext
    
    let caption: String
    let selectedHashtags: Binding<[String]>
    
    @State private var suggestions: [HashtagSuggestion] = []
    @State private var hashtagSets: [HashtagSet] = []
    @State private var topHashtags: [HashtagPerformance] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "number")
                    .foregroundColor(.kosmicPurple)
                
                Text("Hashtag Suggestions")
                    .font(.headline)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            // Hashtag Sets
            if !hashtagSets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Saved Sets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(hashtagSets) { set in
                                Button(action: {
                                    addHashtags(set.hashtags)
                                }) {
                                    HStack(spacing: 4) {
                                        Text(set.name)
                                            .font(.caption)
                                        
                                        if set.averagePerformance > 0 {
                                            Label("\(Int(set.averagePerformance * 100))%", systemImage: "chart.line.uptrend.xyaxis")
                                                .font(.caption2)
                                                .foregroundColor(.kosmicGreen)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.kosmicBlue.opacity(0.2))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Suggested hashtags
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Smart Suggestions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(suggestions) { suggestion in
                            HashtagChip(
                                hashtag: suggestion.hashtag,
                                performance: suggestion.performance,
                                isSelected: selectedHashtags.wrappedValue.contains(suggestion.hashtag),
                                action: {
                                    toggleHashtag(suggestion.hashtag)
                                }
                            )
                        }
                    }
                }
            }
            
            // Top performing hashtags
            if !topHashtags.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Top Performers")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(topHashtags.prefix(10)) { hashtag in
                                HashtagChip(
                                    hashtag: "#\(hashtag.hashtag)",
                                    performance: hashtag.averageEngagement,
                                    isSelected: selectedHashtags.wrappedValue.contains("#\(hashtag.hashtag)"),
                                    action: {
                                        toggleHashtag("#\(hashtag.hashtag)")
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .onAppear {
            _Concurrency.Task {
                await loadData()
            }
        }
        .onChange(of: caption) { _, _ in
            _Concurrency.Task {
                await loadSuggestions()
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load hashtag sets
        let setsDescriptor = FetchDescriptor<HashtagSet>()
        if let sets = try? modelContext.fetch(setsDescriptor) {
            await MainActor.run {
                self.hashtagSets = sets
            }
        }
        
        // Note: HashtagPerformanceService was removed as part of social media posting removal
        // Load top performing hashtags directly from SwiftData (all platforms)
        var hashtagDescriptor = FetchDescriptor<HashtagPerformance>(
            sortBy: [SortDescriptor(\.averageEngagement, order: .reverse)]
        )
        hashtagDescriptor.fetchLimit = 10
        if let hashtags = try? modelContext.fetch(hashtagDescriptor) {
            await MainActor.run {
                self.topHashtags = Array(hashtags.prefix(10))
            }
        }
        
        await loadSuggestions()
    }
    
    private func loadSuggestions() async {
        guard !caption.isEmpty else {
            await MainActor.run {
                self.suggestions = []
            }
            return
        }
        
        // Note: HashtagPerformanceService was removed as part of social media posting removal
        // Extract hashtags from caption (simple implementation)
        let words = caption.components(separatedBy: .whitespacesAndNewlines)
        let hashtags = words.filter { $0.hasPrefix("#") }
        
        // Load performance data for suggestions
        var suggestionObjects: [HashtagSuggestion] = []
        
        for hashtag in hashtags {
            let cleaned = hashtag.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            let descriptor = FetchDescriptor<HashtagPerformance>(
                predicate: #Predicate<HashtagPerformance> { performance in
                    performance.hashtag == cleaned
                }
            )
            
            let performance = (try? modelContext.fetch(descriptor).first?.averageEngagement) ?? 0.0
            
            suggestionObjects.append(HashtagSuggestion(
                hashtag: hashtag,
                performance: performance
            ))
        }
        
        await MainActor.run {
            self.suggestions = suggestionObjects.sorted { $0.performance > $1.performance }
        }
    }
    
    private func toggleHashtag(_ hashtag: String) {
        if selectedHashtags.wrappedValue.contains(hashtag) {
            selectedHashtags.wrappedValue.removeAll { $0 == hashtag }
        } else {
            selectedHashtags.wrappedValue.append(hashtag)
        }
    }
    
    private func addHashtags(_ hashtags: [String]) {
        for hashtag in hashtags {
            if !selectedHashtags.wrappedValue.contains(hashtag) {
                selectedHashtags.wrappedValue.append(hashtag)
            }
        }
    }
}

private struct HashtagSuggestion: Identifiable {
    let id = UUID()
    let hashtag: String
    let performance: Double
}

struct HashtagChip: View {
    let hashtag: String
    let performance: Double
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(hashtag)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if performance > 0 {
                    Image(systemName: performance > 5 ? "arrow.up.circle.fill" : "circle.fill")
                        .font(.caption2)
                        .foregroundColor(performance > 5 ? .kosmicGreen : .gray)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.kosmicBlue.opacity(0.3) : Color.secondary.opacity(0.1))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.kosmicBlue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

