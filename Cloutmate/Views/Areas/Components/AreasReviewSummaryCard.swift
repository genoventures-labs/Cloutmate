//
//  AreasReviewSummaryCard.swift
//  Cloutmate
//
//  Summary card highlighting areas that require review.
//

import SwiftUI

struct AreasReviewSummaryCard: View {
    let items: [(Area, AreaReviewStatus)]
    let onSelect: (Area) -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        DashboardTile(accent: .orange) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(items.count) area\(items.count == 1 ? "" : "s") need review")
                            .font(.headline)
                            .foregroundStyle(glassColorSystem.textPrimary())
                        
                        if let nextUpcoming = items.min(by: { ($0.1.overdueDays ?? 0) > ($1.1.overdueDays ?? 0) }) {
                            let reason = nextUpcoming.1.reason
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        if let first = items.first {
                            onSelect(first.0)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Open Queue")
                                .font(.caption.weight(.semibold))
                            Image(systemName: "arrow.forward.circle.fill")
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.kosmicBlue, .kosmicPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items.prefix(3), id: \.0.id) { area, status in
                        Button {
                            onSelect(area)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: area.categoryIcon ?? "rectangle.stack.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(colorAccent(for: area))
                                    .frame(width: 24, height: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(area.title)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(glassColorSystem.textPrimary())
                                        .lineLimit(1)
                                    
                                    Text(status.reason)
                                        .font(.caption)
                                        .foregroundStyle(glassColorSystem.textSecondary())
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                if let overdue = status.overdueDays, overdue > 0 {
                                    badge(title: "\(overdue)d overdue", color: .red)
                                } else {
                                    badge(title: "Due soon", color: .orange)
                                }
                            }
                            .padding(12)
                            .background(glassColorSystem.glassTint(for: .surface).opacity(0.25))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private func badge(title: String, color: Color) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }
    
    private func colorAccent(for area: Area) -> Color {
        switch area.colorAccent {
        case "kosmicBlue": return .kosmicBlue
        case "kosmicPurple": return .kosmicPurple
        case "kosmicGreen": return .kosmicGreen
        default: return .kosmicBlue
        }
    }
}

#Preview {
    let area1 = Area(title: "Wellness")
    area1.colorAccent = "kosmicGreen"
    let area2 = Area(title: "Family Systems")
    let area3 = Area(title: "Product Vision")
    
    let status1 = AreaReviewStatus(
        isDue: true,
        reason: "Review overdue by 3 days.",
        overdueDays: 3,
        intervalDays: 14,
        lastReviewDate: Calendar.current.date(byAdding: .day, value: -17, to: Date()),
        nextReviewDate: Date()
    )
    let status2 = AreaReviewStatus(
        isDue: true,
        reason: "This area has never been reviewed.",
        overdueDays: nil,
        intervalDays: 14,
        lastReviewDate: nil,
        nextReviewDate: Date()
    )
    let status3 = AreaReviewStatus(
        isDue: true,
        reason: "Manually flagged for review.",
        overdueDays: nil,
        intervalDays: 7,
        lastReviewDate: Date().addingTimeInterval(-2 * 86400),
        nextReviewDate: Date()
    )
    
    let items: [(Area, AreaReviewStatus)] = [(area1, status1), (area2, status2), (area3, status3)]
    
    return AreasReviewSummaryCard(
        items: items,
        onSelect: { _ in }
    )
    .environmentObject(GlassColorSystem())
    .padding()
}


