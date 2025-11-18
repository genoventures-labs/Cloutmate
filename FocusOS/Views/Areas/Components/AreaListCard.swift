//
//  AreaListCard.swift
//  FocusOS
//
//  Compact list card for Areas list view
//

import SwiftUI
import SwiftData
import FocusOSShared

struct AreaListCard: View {
    let area: Area
    let projects: [FocusOSShared.Project]
    let notes: [Note]
    let onTap: () -> Void
    let isReviewDue: Bool
    let onReview: (() -> Void)?
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var linkedProjectsCount: Int {
        projects.filter { $0.areaId == area.id }.count
    }
    
    var linkedNotesCount: Int {
        notes.filter { $0.areaId == area.id }.count
    }
    
    var accentColor: Color {
        switch area.colorAccent {
        case "kosmicBlue": return .kosmicBlue
        case "kosmicPurple": return .kosmicPurple
        case "kosmicGreen": return .kosmicGreen
        default: return .kosmicBlue
        }
    }
    
    var body: some View {
        DashboardTile(accent: accentColor) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: area.categoryIcon ?? "rectangle.stack.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(accentColor)
                    .frame(width: 40, height: 40)
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(area.title)
                            .font(.headline)
                            .foregroundStyle(glassColorSystem.textPrimary())
                        
                        if isReviewDue {
                            Button {
                                onReview?()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.caption2)
                                    Text("Review")
                                        .font(.caption2.weight(.semibold))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.16))
                                .foregroundStyle(.orange)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if let notes = area.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 12) {
                        if linkedProjectsCount > 0 {
                            Label("\(linkedProjectsCount)", systemImage: "folder.fill")
                                .font(.caption2)
                                .foregroundStyle(glassColorSystem.textTertiary())
                        }
                        if linkedNotesCount > 0 {
                            Label("\(linkedNotesCount)", systemImage: "note.text")
                                .font(.caption2)
                                .foregroundStyle(glassColorSystem.textTertiary())
                        }
                        if let lastReview = area.lastReviewDate {
                            Text("Reviewed \(lastReview, style: .relative)")
                                .font(.caption2)
                                .foregroundStyle(glassColorSystem.textTertiary())
                        }
                    }
                }
                
                Spacer()
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    let area = Area(title: "Health & Wellness", notes: "Maintaining physical and mental health")
    area.colorAccent = "kosmicGreen"
    
    return AreaListCard(
        area: area,
        projects: [],
        notes: [],
        onTap: {},
        isReviewDue: false,
        onReview: nil
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

