//
//  PostDetailPopup.swift
//  Cloutmate
//
//  Post Detail Popup for Chart Interactions
//

import SwiftUI
import CloutmateShared

struct PostDetailPopup: View {
    let post: CloutmateShared.Post
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    captionSection
                    engagementMetricsSection
                    postDetailsSection
                }
                .padding(.vertical)
            }
            .background(Color(.windowBackgroundColor))
            .navigationTitle("Post Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Caption")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(post.caption)
                .font(.body)
        }
        .glassPanel(tier: .contentCard, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    private var engagementMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Engagement Metrics")
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                PostDetailMetricRow(
                    label: "Engagement Rate",
                    value: String(format: "%.1f%%", post.engagementRate ?? 0),
                    icon: "heart.fill",
                    color: .pink
                )
                PostDetailMetricRow(
                    label: "Likes",
                    value: "\(post.likes ?? 0)",
                    icon: "hand.thumbsup.fill",
                    color: .orange
                )
                PostDetailMetricRow(
                    label: "Comments",
                    value: "\(post.comments ?? 0)",
                    icon: "bubble.left.fill",
                    color: .kosmicBlue
                )
                PostDetailMetricRow(
                    label: "Reach",
                    value: "\(post.reach ?? 0)",
                    icon: "eye.fill",
                    color: .kosmicPurple
                )
            }
        }
        .glassPanel(tier: .contentCard, cornerRadius: 12)
        .padding(.horizontal)
    }
    
    private var postDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Published", systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                if let publishedDate = post.publishedDate {
                    Text(publishedDate, format: .dateTime.month().day().year().hour().minute())
                        .font(.subheadline)
                }
            }
            
            Divider()
            
            HStack {
                Label("Status", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(post.postStatus.displayName)
                    .font(.subheadline)
            }
        }
        .glassPanel(tier: .contentCard, cornerRadius: 12)
        .padding(.horizontal)
    }
}

struct PostDetailMetricRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
                        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .glassPanel(tier: .overlay, cornerRadius: 8, tintColor: color.opacity(0.1))
    }
}

#Preview {
    PostDetailPopup(post: CloutmateShared.Post(caption: "Sample post caption"))
}
