//
//  JournalTimelineView.swift
//  Cloutmate
//
//  Emotional timeline visualization for Journal V2
//

import SwiftUI
import SwiftData
import CloutmateShared

struct JournalTimelineView: View {
    let journals: [Journal]
    let onEntryTap: (Journal) -> Void
    
    @State private var hoveredEntry: Journal?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    private var sortedJournals: [Journal] {
        journals.sorted { $0.entryDate < $1.entryDate }
    }
    
    private var dateRange: (start: Date, end: Date)? {
        guard let first = sortedJournals.first,
              let last = sortedJournals.last else { return nil }
        return (first.entryDate, last.entryDate)
    }
    
    var body: some View {
        guard !sortedJournals.isEmpty else {
            return AnyView(EmptyView())
        }
        
        let trackHeight: CGFloat = 150
        let spacing: CGFloat = 88
        let horizontalPadding: CGFloat = 52
        let verticalPadding: CGFloat = 28
        let minTrackWidth: CGFloat = 360
        let availableHeight = trackHeight - verticalPadding * 2
        let trackWidth = max(horizontalPadding * 2 + spacing * CGFloat(max(sortedJournals.count - 1, 0)), minTrackWidth)
        
        let timelinePoints: [TimelinePoint] = sortedJournals.enumerated().map { index, journal in
            let score = moodScore(for: journal.journalMood)
            let x = horizontalPadding + CGFloat(index) * spacing
            let y = trackHeight - verticalPadding - CGFloat(score) * availableHeight
            return TimelinePoint(journal: journal, index: index, position: CGPoint(x: x, y: y), score: score)
        }
        
        let monthMarkers = monthMarkers(for: sortedJournals, spacing: spacing, horizontalPadding: horizontalPadding)
        let baselineY = trackHeight - verticalPadding
        
        return AnyView(
            GlassPanel(tier: .contentCard, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Emotional Timeline")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if let range = dateRange {
                                Text("\(range.start.formatted(.dateTime.month().day())) – \(range.end.formatted(.dateTime.month().day().year()))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text("\(sortedJournals.count) entries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        ZStack {
                            Canvas { context, size in
                                // Month separators
                                for marker in monthMarkers {
                                    var markerPath = Path()
                                    markerPath.move(to: CGPoint(x: marker.positionX, y: verticalPadding - 8))
                                    markerPath.addLine(to: CGPoint(x: marker.positionX, y: baselineY + 12))
                                    context.stroke(
                                        markerPath,
                                        with: .color(Color.secondary.opacity(0.12)),
                                        style: StrokeStyle(lineWidth: 1, dash: [6, 8])
                                    )
                                }
                                
                                // Baseline
                                var baseline = Path()
                                baseline.move(to: CGPoint(x: horizontalPadding, y: baselineY))
                                baseline.addLine(to: CGPoint(x: trackWidth - horizontalPadding, y: baselineY))
                                context.stroke(
                                    baseline,
                                    with: .linearGradient(
                                        Gradient(colors: [.kosmicBlue.opacity(0.35), .kosmicPurple.opacity(0.35), .kosmicGreen.opacity(0.35)]),
                                        startPoint: CGPoint(x: horizontalPadding, y: baselineY),
                                        endPoint: CGPoint(x: trackWidth - horizontalPadding, y: baselineY)
                                    ),
                                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                                )
                                
                                guard timelinePoints.count >= 2 else { return }
                                
                                // Mood drift fill
                                var fill = Path()
                                fill.move(to: CGPoint(x: timelinePoints.first!.position.x, y: baselineY))
                                timelinePoints.forEach { fill.addLine(to: $0.position) }
                                fill.addLine(to: CGPoint(x: timelinePoints.last!.position.x, y: baselineY))
                                fill.closeSubpath()
                                context.fill(
                                    fill,
                                    with: .linearGradient(
                                        Gradient(colors: [
                                            Color.kosmicBlue.opacity(0.08),
                                            Color.kosmicPurple.opacity(0.08),
                                            Color.kosmicGreen.opacity(0.08)
                                        ]),
                                        startPoint: CGPoint(x: horizontalPadding, y: verticalPadding),
                                        endPoint: CGPoint(x: trackWidth - horizontalPadding, y: baselineY)
                                    )
                                )
                                
                                // Mood drift line
                                var drift = Path()
                                drift.move(to: timelinePoints.first!.position)
                                timelinePoints.dropFirst().forEach { drift.addLine(to: $0.position) }
                                context.stroke(
                                    drift,
                                    with: .linearGradient(
                                        Gradient(colors: [.kosmicBlue, .kosmicPurple, .kosmicGreen]),
                                        startPoint: CGPoint(x: horizontalPadding, y: verticalPadding),
                                        endPoint: CGPoint(x: trackWidth - horizontalPadding, y: baselineY)
                                    ),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                                )
                            }
                            .frame(width: trackWidth, height: trackHeight)
                            .drawingGroup()
                            
                            // Month labels
                            ForEach(monthMarkers) { marker in
                                Text(marker.label)
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .position(x: marker.positionX, y: trackHeight - 10)
                            }
                            
                            // Timeline markers
                            ForEach(timelinePoints) { data in
                                TimelineMarker(
                                    journal: data.journal,
                                    isHovered: hoveredEntry?.id == data.journal.id,
                                    moodColor: moodColor(for: data.journal.journalMood),
                                    shortDate: timelineShortDateFormatter.string(from: data.journal.entryDate),
                                    onTap: { onEntryTap(data.journal) },
                                    onHover: { hovering in
                                        if reduceMotion {
                                            hoveredEntry = hovering ? data.journal : nil
                                        } else {
                                            withAnimation(GlassMotion.Easing.spring) {
                                                hoveredEntry = hovering ? data.journal : nil
                                            }
                                        }
                                    }
                                )
                                .position(data.position)
                            }
                        }
                        .frame(width: trackWidth, height: trackHeight)
                        .padding(.vertical, 4)
                    }
                    
                    if let hovered = hoveredEntry {
                        TimelinePreview(journal: hovered)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        MoodLegend()
                            .transition(.opacity)
                    }
                }
                .padding(16)
            }
            .animation(.easeInOut(duration: 0.35), value: hoveredEntry?.id)
        )
    }
}

private struct TimelinePoint: Identifiable {
    let journal: Journal
    let index: Int
    let position: CGPoint
    let score: Double
    
    var id: UUID { journal.id }
}

private struct TimelineMonthMarker: Identifiable {
    let id = UUID()
    let label: String
    let positionX: CGFloat
}

private struct TimelineMarker: View {
    let journal: Journal
    let isHovered: Bool
    let moodColor: Color
    let shortDate: String
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            if isHovered {
                Text(journal.journalMood.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(moodColor.opacity(0.16))
                    .foregroundColor(moodColor)
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            moodColor.opacity(isHovered ? 0.8 : 0.6),
                            moodColor.opacity(isHovered ? 0.15 : 0.05)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: isHovered ? 22 : 16
                    )
                )
                .frame(width: isHovered ? 20 : 14, height: isHovered ? 20 : 14)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(isHovered ? 0.9 : 0.6), lineWidth: isHovered ? 2 : 1)
                )
                .shadow(color: moodColor.opacity(isHovered ? 0.45 : 0.15), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
                .scaleEffect(isHovered ? 1.12 : 1.0)
                .animation(GlassMotion.Easing.spring, value: isHovered)
            
            Text(shortDate)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 92)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { hovering in onHover(hovering) }
    }
}

private struct TimelinePreview: View {
    let journal: Journal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(journal.title.isEmpty ? "Untitled Entry" : journal.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(journal.entryDate.formatted(.dateTime.month().day().year()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if journal.author == .aurora {
                    AuroraAuthorBadge()
                }
                
                Label(journal.journalMood.rawValue, systemImage: moodIcon)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(moodColor.opacity(0.15))
                    .foregroundColor(moodColor)
                    .clipShape(Capsule())
            }
            
            if !journal.content.isEmpty {
                Text(String(journal.content.prefix(160)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            } else if let summary = journal.aiGeneratedContent, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08))
                )
        )
    }
    
    private var moodColor: Color {
        moodColorForPreview(for: journal.journalMood)
    }
    
    private var moodIcon: String {
        switch journal.journalMood {
        case .excited: return "sparkles"
        case .grateful: return "heart.fill"
        case .reflective: return "brain.head.profile"
        case .motivated: return "bolt.fill"
        case .contemplative: return "moon.fill"
        case .creative: return "paintbrush.fill"
        case .frustrated: return "exclamationmark.triangle.fill"
        case .calm: return "leaf.fill"
        case .none: return "circle"
        }
    }
}

private struct MoodLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            legendItem(color: .kosmicBlue, label: "Reflective")
            legendItem(color: .kosmicPurple, label: "Creative")
            legendItem(color: .kosmicGreen, label: "Motivated")
            legendItem(color: .orange, label: "Energized")
            legendItem(color: .red, label: "Tense")
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

private func monthMarkers(for journals: [Journal], spacing: CGFloat, horizontalPadding: CGFloat) -> [TimelineMonthMarker] {
    guard !journals.isEmpty else { return [] }
    
    var markers: [TimelineMonthMarker] = []
    let calendar = Calendar.current
    var previousKey: String?
    
    for (index, journal) in journals.enumerated() {
        let components = calendar.dateComponents([.year, .month], from: journal.entryDate)
        let key = "\(components.year ?? 0)-\(components.month ?? 0)"
        if previousKey == nil || key != previousKey {
            let label = timelineMonthFormatter.string(from: journal.entryDate)
            let positionX = horizontalPadding + CGFloat(index) * spacing
            markers.append(TimelineMonthMarker(label: label, positionX: positionX))
            previousKey = key
        }
    }
    
    return markers
}

private func moodColor(for mood: JournalMood) -> Color {
    switch mood {
    case .excited: return .orange
    case .grateful: return .yellow
    case .reflective: return .kosmicBlue
    case .motivated: return .kosmicGreen
    case .contemplative: return .kosmicPurple
    case .creative: return .pink
    case .frustrated: return .red
    case .calm: return .cyan
    case .none: return .gray
    }
}

private func moodColorForPreview(for mood: JournalMood) -> Color {
    moodColor(for: mood)
}

private func moodScore(for mood: JournalMood) -> Double {
    switch mood {
    case .excited: return 0.88
    case .grateful: return 0.76
    case .reflective: return 0.62
    case .motivated: return 0.82
    case .contemplative: return 0.48
    case .creative: return 0.7
    case .frustrated: return 0.24
    case .calm: return 0.65
    case .none: return 0.45
    }
}

#Preview {
    JournalTimelineView(
        journals: [
            Journal(title: "Morning Reflection", content: "Today I felt focused and grounded.", entryDate: Date(), mood: .motivated),
            Journal(title: "Midday Note", content: "Energy dipped in the afternoon, but recovered after a walk.", entryDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(), mood: .calm),
            Journal(title: "Creative Burst", content: "Ideas flowed effortlessly into the draft.", entryDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(), mood: .creative),
            Journal(title: "Evening Reflection", content: "Grateful for the small wins.", entryDate: Calendar.current.date(byAdding: .day, value: -9, to: Date()) ?? Date(), mood: .grateful)
        ],
        onEntryTap: { _ in }
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

private let timelineMonthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM"
    return formatter
}()

private let timelineShortDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter
}()

