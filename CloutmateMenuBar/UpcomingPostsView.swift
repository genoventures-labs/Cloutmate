//
//  UpcomingPostsView.swift
//  CloutmateMenuBar
//
//  Shows recent artifacts
//

import SwiftUI
import SwiftData
import CloutmateShared

struct UpcomingPostsView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @Query(filter: #Predicate<CloutmateShared.Artifact> { artifact in
        artifact.state == "published" || artifact.state == "final"
    }, sort: \.publishedAt, order: .reverse) var publishedArtifacts: [CloutmateShared.Artifact]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Show recent artifacts
                if !publishedArtifacts.isEmpty {
                    ForEach(publishedArtifacts.prefix(10), id: \.id) { artifact in
                        ArtifactCard(artifact: artifact)
                            .padding(.horizontal, 16)
                    }
                }
                
                if publishedArtifacts.isEmpty {
                    VStack(spacing: 12) {
                        Text("✨")
                            .font(.system(size: 40))
                        Text("No artifacts yet")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 72/255, green: 131/255, blue: 255/255), // kosmicBlue
                                        Color(red: 124/255, green: 77/255, blue: 255/255)  // kosmicPurple
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("Create an artifact to see it here")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(glassColorSystem.textSecondary())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                }
            }
            .padding(.vertical, 16)
        }
    }
}

struct ArtifactCard: View {
    let artifact: CloutmateShared.Artifact
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(glassColorSystem.cardColor())
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    // Time and format
                    HStack {
                        if let publishedAt = artifact.publishedAt {
                            Text(publishedAt, style: .time)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(glassColorSystem.textPrimary())
                        }
                        Spacer()
                        ArtifactStateBadge(state: artifact.artifactState)
                    }
                    
                    // Title/content preview
                    Text(artifact.title.isEmpty ? artifact.content.prefix(50).description : artifact.title)
                        .font(.system(size: 13))
                        .lineLimit(2)
                        .foregroundColor(glassColorSystem.textPrimary())
                    
                    // Format badge
                    HStack(spacing: 4) {
                        Image(systemName: formatIcon)
                            .font(.system(size: 10))
                        Text(artifact.format.displayName)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(formatColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(formatColor.opacity(0.15))
                    )
                }
                .padding(12)
            )
            .frame(height: 80)
            .floatLift()
    }
    
    private var formatIcon: String {
        switch artifact.format {
        case .brief: return "doc.text"
        case .summary: return "doc.text.below.ecg"
        case .reflection: return "brain.head.profile"
        case .report: return "doc.text.magnifyingglass"
        case .releaseNote: return "megaphone"
        case .lessonLearned: return "lightbulb"
        }
    }
    
    private var formatColor: Color {
        switch artifact.format {
        case .brief: return .cyan
        case .summary: return Color(red: 72/255, green: 131/255, blue: 255/255) // kosmicBlue
        case .reflection: return Color(red: 124/255, green: 77/255, blue: 255/255) // kosmicPurple
        case .report: return .indigo
        case .releaseNote: return .green
        case .lessonLearned: return .orange
        }
    }
}

struct ArtifactStateBadge: View {
    let state: ArtifactState
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        Text(state.displayName)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(state == .published ? glassColorSystem.buttonColor(for: .success).opacity(0.2) : Color.clear)
            )
            .foregroundColor(state == .published ? glassColorSystem.buttonColor(for: .success) : glassColorSystem.textSecondary())
    }
}

#Preview {
    UpcomingPostsView()
        .modelContainer(for: [CloutmateShared.Artifact.self])
}
