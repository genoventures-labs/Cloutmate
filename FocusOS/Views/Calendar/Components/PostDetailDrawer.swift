//
//  PostDetailDrawer.swift
//  FocusOS
//
//  Drawer presentation for calendar post previews
//

import SwiftUI
import SwiftData
import FocusOSShared

struct PostDetailDrawer: View {
    @Bindable var post: FocusOSShared.Post
    @Binding var isPresented: Bool
    let onEdit: (FocusOSShared.Post) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    
    @State private var showDeleteConfirmation = false
    
    private var accentColor: Color {
        post.postStatus == .published ? .kosmicGreen : .kosmicBlue
    }
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                gradientSidebar
                
                VStack(spacing: 0) {
                    header
                        .padding()
                        .background(.ultraThinMaterial)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            captionSection
                            scheduleSection
                            publishedSection
                            statusSection
                            engagementSection
                            mediaSection
                            tagsSection
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                    }
                    .background(Color(.windowBackgroundColor))
                    
                    footer
                        .padding(20)
                        .background(.ultraThinMaterial)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(glassColorSystem.backgroundColor())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        closeDrawer()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .frame(idealWidth: 800, idealHeight: 600)
        .alert("Delete Post?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private var gradientSidebar: some View {
        RoundedRectangle(cornerRadius: 0, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [accentColor.opacity(0.85), accentColor.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4)
    }
    
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(post.caption.isEmpty ? "Untitled Post" : post.caption)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(glassColorSystem.textPrimary())
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button {
                onEdit(post)
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }
            .buttonStyle(.bordered)
            
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Caption")
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
            Text(post.caption.isEmpty ? "No caption provided" : post.caption)
                .font(.body)
                .foregroundColor(glassColorSystem.textSecondary())
        }
    }
    
    private var scheduleSection: some View {
        Group {
            if let scheduledDate = post.scheduledDate {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scheduled")
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    HStack(spacing: 16) {
                        Text(scheduledDate, style: .date)
                        Text(scheduledDate, style: .time)
                            .foregroundColor(.secondary)
                    }
                    .font(.body)
                    
                    if scheduledDate < Date() {
                        Label("Past due", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
    }
    
    private var publishedSection: some View {
        Group {
            if let publishedDate = post.publishedDate {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Published")
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    HStack(spacing: 16) {
                        Text(publishedDate, style: .date)
                        Text(publishedDate, style: .time)
                            .foregroundColor(.secondary)
                    }
                    .font(.body)
                }
            }
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
            PostStatusBadge(status: post.postStatus)
        }
    }
    
    private var engagementSection: some View {
        Group {
            if post.engagementRate != nil || post.likes != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Engagement Metrics")
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    VStack(alignment: .leading, spacing: 6) {
                        if let engagementRate = post.engagementRate {
                            metricRow(icon: "chart.line.uptrend.xyaxis", title: "Engagement Rate", value: String(format: "%.2f%%", engagementRate))
                        }
                        if let impressions = post.impressions {
                            metricRow(icon: "eye", title: "Impressions", value: "\(impressions)")
                        }
                        if let likes = post.likes {
                            metricRow(icon: "heart.fill", title: "Likes", value: "\(likes)")
                        }
                        if let comments = post.comments {
                            metricRow(icon: "bubble.left", title: "Comments", value: "\(comments)")
                        }
                        if let reach = post.reach {
                            metricRow(icon: "person.3", title: "Reach", value: "\(reach)")
                        }
                    }
                }
            }
        }
    }
    
    private func metricRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
        .foregroundColor(glassColorSystem.textSecondary())
    }
    
    private var mediaSection: some View {
        Group {
            if !post.mediaURLs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Media Attachments")
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(post.mediaURLs, id: \.self) { urlString in
                                MediaPreviewView(url: URL(fileURLWithPath: urlString), onRemove: {})
                                    .frame(width: 120, height: 120)
                                    .cornerRadius(12)
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    private var tagsSection: some View {
        Group {
            if !post.tags.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tags")
                        .font(.headline)
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                        ForEach(post.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.kosmicBlue.opacity(0.15))
                                .foregroundColor(.kosmicBlue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: copyCaption) {
                Label("Copy Caption", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button(action: reschedulePost) {
                Label("Reschedule", systemImage: "calendar")
            }
            .buttonStyle(.bordered)
            
            Button(action: closeDrawer) {
                Text("Done")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func copyCaption() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(post.caption, forType: .string)
    }
    
    private func reschedulePost() {
        onEdit(post)
    }
    
    private func closeDrawer() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
    
    private func deletePost() {
        modelContext.delete(post)
        try? modelContext.save()
        closeDrawer()
    }
}
