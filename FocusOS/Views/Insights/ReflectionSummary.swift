//
//  ReflectionSummary.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import FocusOSShared

struct ReflectionSummary: View {
    let posts: [FocusOSShared.Post]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let summary = generateSummary() {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.orange.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.orange.opacity(0.08))
                        )
                    
                    Text(summary)
                        .font(.system(size: 15, weight: .regular))
                        .lineSpacing(6)
                        .foregroundColor(.primary)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Post content to see insights and reflections.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(tier: .contentCard, cornerRadius: 16)
    }
    
    private func generateSummary() -> String? {
        guard !posts.isEmpty else { return nil }
        
        let postsWithMetrics = posts.filter { $0.engagementRate != nil }
        guard !postsWithMetrics.isEmpty else { return nil }
        
        let totalPosts = posts.count
        let avgEngagement = postsWithMetrics.reduce(0) { $0 + ($1.engagementRate ?? 0) } / Double(postsWithMetrics.count)
        let bestPerforming = postsWithMetrics.max(by: { ($0.engagementRate ?? 0) < ($1.engagementRate ?? 0) })
        
        var summary = "Over the past period, you've published \(totalPosts) posts with an average engagement rate of \(String(format: "%.1f", avgEngagement))%."
        
        if let best = bestPerforming, let engagement = best.engagementRate {
            summary += " Your best-performing post achieved \(String(format: "%.1f", engagement))% engagement."
        }
        
        return summary
    }
}

#Preview {
    ReflectionSummary(posts: [])
        .padding()
}

