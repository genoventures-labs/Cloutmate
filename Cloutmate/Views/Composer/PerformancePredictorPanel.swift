//
//  PerformancePredictorPanel.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import CloutmateShared

struct PerformancePredictorPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.publishedDate, order: .reverse) private var allPosts: [Post]
    
    let post: Post
    let refreshID: UUID
    @State private var prediction: PerformancePrediction?
    @State private var isAnalyzing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.kosmicBlue)
                    .font(.title3)
                
                Text("Performance Prediction")
                    .font(.headline)
                
                Spacer()
                
                if isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            if let prediction = prediction {
                // Score display
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Predicted Engagement")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            Text("\(Int(prediction.predictedEngagementRate))%")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(scoreColor(prediction.predictedEngagementRate))
                            
                            Text("±\(Int((1 - prediction.confidence) * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Confidence indicator
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Confidence")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            ProgressView(value: prediction.confidence)
                                .frame(width: 60)
                            
                            Text("\(Int(prediction.confidence * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // Factor breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("Factors")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    FactorRow(
                        icon: "text.alignleft",
                        name: "Caption Length",
                        score: prediction.captionLengthScore,
                        color: .kosmicBlue
                    )
                    
                    FactorRow(
                        icon: "face.smiling",
                        name: "Tone",
                        score: prediction.toneScore,
                        color: .kosmicGreen
                    )
                    
                    FactorRow(
                        icon: "number",
                        name: "Hashtags",
                        score: prediction.hashtagScore,
                        color: .kosmicPurple
                    )
                    
                    FactorRow(
                        icon: "globe",
                        name: "Platform",
                        score: prediction.platformScore,
                        color: .orange
                    )
                    
                    FactorRow(
                        icon: "clock",
                        name: "Timing",
                        score: prediction.timeScore,
                        color: .red
                    )
                    
                    FactorRow(
                        icon: "square.on.square",
                        name: "Similarity",
                        score: prediction.similarityScore,
                        color: .pink
                    )
                }
                
                // Optimal time suggestion
                if let optimalTime = prediction.optimalPostingTime {
                    Divider()
                    
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundColor(.kosmicGreen)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Optimal Posting Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(optimalTime.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
            } else {
                Text("Analyzing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .onAppear {
            _Concurrency.Task {
                await analyzePost()
            }
        }
        .onChange(of: post.caption) { _, _ in
            _Concurrency.Task {
                await analyzePost()
            }
        }
        .onChange(of: refreshID) { _, _ in
            _Concurrency.Task {
                await analyzePost()
            }
        }
    }
    
    private func analyzePost() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        // Note: PerformancePredictionService was removed as part of social media posting removal
        // Create a placeholder prediction
        let placeholderPrediction = PerformancePrediction(
            postId: post.id,
            predictedEngagementRate: 50.0,
            confidence: 0.5,
            factors: [
                "Caption Length": 0.5,
                "Tone": 0.5,
                "Hashtags": 0.5,
                "Platform": 0.5,
                "Timing": 0.5
            ]
        )
        
        // Set individual factor scores
        placeholderPrediction.captionLengthScore = 0.5
        placeholderPrediction.toneScore = 0.5
        placeholderPrediction.hashtagScore = 0.5
        placeholderPrediction.platformScore = 0.5
        placeholderPrediction.timeScore = 0.5
        
        await MainActor.run {
            self.prediction = placeholderPrediction
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 {
            return .kosmicGreen
        } else if score >= 50 {
            return .orange
        } else {
            return .red
        }
    }
}

private struct FactorRow: View {
    let icon: String
    let name: String
    let score: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(name)
                .font(.caption)
            
            Spacer()
            
            HStack(spacing: 4) {
                ProgressView(value: score)
                    .frame(width: 60)
                    .tint(color)
                
                Text("\(Int(score * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
