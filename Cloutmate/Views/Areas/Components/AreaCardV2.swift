//
//  AreaCardV2.swift
//  Cloutmate
//
//  Areas V2 - Card component with stability tracking
//

import SwiftUI
import SwiftData
import CloutmateShared

struct AreaCardV2: View {
    let area: Area
    let projects: [CloutmateShared.Project]
    let notes: [Note]
    let onTap: () -> Void
    let onEdit: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let isReviewDue: Bool
    let onReview: (() -> Void)?
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isHovered = false
    @State private var stabilityScore: Double = 0.0
    @State private var statusSignal: StabilitySignal = .steady
    
    var linkedProjectsCount: Int {
        projects.filter { $0.areaId == area.id }.count
    }
    
    var linkedNotesCount: Int {
        notes.filter { $0.areaId == area.id }.count
    }
    
    var iconName: String {
        area.categoryIcon ?? "rectangle.stack.fill"
    }
    
    var accentColor: Color {
        switch area.colorAccent {
        case "kosmicBlue": return .kosmicBlue
        case "kosmicPurple": return .kosmicPurple
        case "kosmicGreen": return .kosmicGreen
        default: return .kosmicBlue
        }
    }
    
    var statusSignalColor: Color {
        switch statusSignal {
        case .calm: return .kosmicGreen
        case .steady: return .kosmicBlue
        case .chaotic: return .red
        }
    }
    
    var body: some View {
        DashboardTile(accent: accentColor) {
        VStack(alignment: .leading, spacing: 12) {
            // Top Row: Icon, Title, Menu
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(accentColor)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(area.title)
                        .font(.headline)
                            .foregroundStyle(glassColorSystem.textPrimary())
                        .lineLimit(2)
                    
                    if isReviewDue, let onReview {
                        Button {
                            onReview()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.caption.weight(.semibold))
                                Text("Review")
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.16))
                                .foregroundStyle(.orange)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Review area")
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(action: onArchive) {
                        Label("Archive", systemImage: "archivebox")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(glassColorSystem.textSecondary())
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            
            // Body: Description
            if let notes = area.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                        .foregroundStyle(glassColorSystem.textSecondary())
                    .lineLimit(3)
            }
            
            // Linked Entity Badges
            if linkedProjectsCount > 0 || linkedNotesCount > 0 {
                HStack(spacing: 6) {
                    if linkedProjectsCount > 0 {
                        BadgePill(count: linkedProjectsCount, label: "Projects", color: .kosmicBlue)
                    }
                    if linkedNotesCount > 0 {
                        BadgePill(count: linkedNotesCount, label: "Notes", color: .kosmicPurple)
                    }
                }
            }
            
            // Status Signal Bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(statusSignalColor.opacity(0.6))
                        .frame(width: geometry.size.width * (stabilityScore / 100.0))
                    
                    Rectangle()
                        .fill(glassColorSystem.glassTint(for: .surface).opacity(0.2))
                }
            }
            .frame(height: 3)
            .cornerRadius(1.5)
            
            // Footer: Review Date + Stability Score
            HStack {
                if let lastReview = area.lastReviewDate {
                    Text("Reviewed \(lastReview, style: .relative)")
                        .font(.caption2)
                            .foregroundStyle(glassColorSystem.textTertiary())
                } else {
                    Text("Never reviewed")
                        .font(.caption2)
                            .foregroundStyle(glassColorSystem.textTertiary())
                }
                
                Spacer()
                
                StabilityScoreBadge(score: stabilityScore)
            }
        }
        }
        .scaleEffect(reduceMotion ? 1.0 : (isHovered ? 1.015 : 1.0))
        .animation(reduceMotion ? nil : GlassMotion.Easing.spring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .task {
            await updateStabilityMetrics()
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to open area details")
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    
    private var accessibilityLabel: String {
        let title = area.title
        let reviewText = area.lastReviewDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Never"
        return "Area: \(title), Stability: \(Int(stabilityScore)), Last reviewed: \(reviewText)"
    }
    
    @MainActor
    private func updateStabilityMetrics() async {
        // Capture area ID to avoid accessing deallocated object
        let areaId = area.id
        
        // Safely calculate stability metrics with error handling
        do {
            // Verify modelContext is accessible and area still exists
            let descriptor = FetchDescriptor<Area>(predicate: #Predicate<Area> { $0.id == areaId })
            guard let _ = try? modelContext.fetch(descriptor).first else {
                // Area was deleted, use defaults
                stabilityScore = 50.0
                statusSignal = .steady
                return
            }
            
            stabilityScore = AreaStabilityService.shared.stabilityScore(for: area, modelContext: modelContext)
            statusSignal = AreaStabilityService.shared.statusSignal(for: area, modelContext: modelContext)
        } catch {
            // If modelContext is invalid, use default values
            stabilityScore = 50.0
            statusSignal = .steady
        }
    }
}

// MARK: - Supporting Views

struct BadgePill: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color)
        .cornerRadius(8)
    }
}

struct StabilityScoreBadge: View {
    let score: Double
    
    var color: Color {
        if score >= 70 {
            return .kosmicGreen
        } else if score >= 40 {
            return .kosmicBlue
        } else {
            return .red
        }
    }
    
    var body: some View {
        Text("\(Int(score))")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(8)
    }
}

#Preview {
    let area = Area(title: "Health & Wellness", notes: "Maintaining physical and mental health through regular exercise and mindfulness practices.")
    area.categoryIcon = "heart.fill"
    area.colorAccent = "kosmicGreen"
    area.lastReviewDate = Date().addingTimeInterval(-86400 * 3) // 3 days ago
    
    return AreaCardV2(
        area: area,
        projects: [],
        notes: [],
        onTap: {},
        onEdit: {},
        onArchive: {},
        onDelete: {},
        isReviewDue: true,
        onReview: {}
    )
    .padding()
    .background(Color(.windowBackgroundColor))
    .environmentObject(GlassColorSystem())
}

