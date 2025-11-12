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
    
    @State private var hoveredEntryID: UUID?
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
    
    private var journalData: [PositionedJournalData] {
        guard let range = dateRange else { return [] }
        let totalDuration = range.end.timeIntervalSince(range.start)
        let calendar = Calendar.current
        
        var counts: [Date: Int] = [:]
        sortedJournals.forEach { journal in
            let bucket = calendar.startOfDay(for: journal.entryDate)
            counts[bucket, default: 0] += 1
        }
        
        var laneAssignments: [Date: Int] = [:]
        
        return sortedJournals.map { journal in
            let bucket = calendar.startOfDay(for: journal.entryDate)
            let laneIndex = laneAssignments[bucket, default: 0]
            laneAssignments[bucket] = laneIndex + 1
            let laneCount = counts[bucket] ?? 1
            
            let offsetFromStart = journal.entryDate.timeIntervalSince(range.start)
            let ratio: CGFloat
            if totalDuration <= 0 {
                ratio = 0.5
            } else {
                ratio = min(max(CGFloat(offsetFromStart / totalDuration), 0), 1)
            }
            
            return PositionedJournalData(
                journal: journal,
                ratio: ratio,
                laneIndex: laneIndex,
                laneCount: laneCount,
                moodScore: moodScore(for: journal.journalMood)
            )
        }
    }
    
    var body: some View {
        if journalData.isEmpty {
            EmptyView()
        } else {
            timelineCard
        }
    }
    
    private var timelineCard: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 16) {
                header
                
                ScrollView(.horizontal, showsIndicators: false) {
                    GeometryReader { geometry in
                        let trackWidth = max(geometry.size.width, TimelineLayout.minTrackWidth)
                        timelineContent(trackWidth: trackWidth)
                            .frame(width: trackWidth, height: TimelineLayout.trackHeight)
                    }
                    .frame(height: TimelineLayout.trackHeight)
                }
                .scrollIndicators(.hidden)
                
                if let hovered = hoveredEntryID.flatMap({ id in sortedJournals.first(where: { $0.id == id }) }) {
                    TimelinePreview(journal: hovered)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    MoodLegend()
                        .transition(.opacity)
                }
            }
            .padding(16)
            .animation(.easeInOut(duration: 0.3), value: hoveredEntryID)
        }
    }
    
    private var header: some View {
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
    }
    
    @ViewBuilder
    private func timelineContent(trackWidth: CGFloat) -> some View {
        let availableWidth = trackWidth - (TimelineLayout.horizontalPadding * 2)
        let amplitude = TimelineLayout.trackHeight * 0.42
        let baselineY = TimelineLayout.baselineY
        
        let positioned = journalData.map { data -> PositionedJournal in
            let baseX = TimelineLayout.horizontalPadding + data.ratio * availableWidth
            let duplicateSpread = CGFloat(max(data.laneCount - 1, 0)) * TimelineLayout.duplicateSpacing
            let duplicateOffset = CGFloat(data.laneIndex) * TimelineLayout.duplicateSpacing - duplicateSpread / 2
            let clampedX = min(max(baseX + duplicateOffset, TimelineLayout.horizontalPadding), trackWidth - TimelineLayout.horizontalPadding)
            let y = baselineY - CGFloat(data.moodScore) * amplitude
            return PositionedJournal(journal: data.journal, x: clampedX, y: y)
        }
        
        let monthMarkers = computeMonthMarkers(for: positioned)
        
        ZStack(alignment: .topLeading) {
            timelineBackground(width: trackWidth, positioned: positioned, baselineY: baselineY)
            
            ForEach(monthMarkers) { marker in
                Text(marker.label)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
                    .position(x: marker.x, y: TimelineLayout.trackHeight - 10)
            }
            
            ForEach(positioned) { entry in
                TimelineMarker(
                    journal: entry.journal,
                    isActive: hoveredEntryID == entry.journal.id,
                    moodColor: moodColor(for: entry.journal.journalMood),
                    shortDate: timelineShortDateFormatter.string(from: entry.journal.entryDate),
                    reduceMotion: reduceMotion,
                    onTap: { onEntryTap(entry.journal) },
                    onHoverChanged: { hovering in
                        hoveredEntryID = hovering ? entry.journal.id : nil
                    }
                )
                .position(x: entry.x, y: entry.y)
                .zIndex(hoveredEntryID == entry.journal.id ? 2 : 1)
            }
        }
    }
    
    private func timelineBackground(width: CGFloat, positioned: [PositionedJournal], baselineY: CGFloat) -> some View {
        Canvas { context, size in
            guard positioned.count >= 1 else { return }
            
            // Baseline
            var baseline = Path()
            baseline.move(to: CGPoint(x: TimelineLayout.horizontalPadding, y: baselineY))
            baseline.addLine(to: CGPoint(x: width - TimelineLayout.horizontalPadding, y: baselineY))
            context.stroke(
                baseline,
                with: .linearGradient(
                    Gradient(colors: [.kosmicBlue.opacity(0.3), .kosmicPurple.opacity(0.3), .kosmicGreen.opacity(0.3)]),
                    startPoint: CGPoint(x: TimelineLayout.horizontalPadding, y: baselineY),
                    endPoint: CGPoint(x: width - TimelineLayout.horizontalPadding, y: baselineY)
                ),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )
            
            guard positioned.count >= 2 else { return }
            
            // Mood drift fill
            var fill = Path()
            fill.move(to: CGPoint(x: positioned.first!.x, y: baselineY))
            positioned.forEach { fill.addLine(to: CGPoint(x: $0.x, y: $0.y)) }
            fill.addLine(to: CGPoint(x: positioned.last!.x, y: baselineY))
            fill.closeSubpath()
            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.kosmicBlue.opacity(0.08),
                        Color.kosmicPurple.opacity(0.08),
                        Color.kosmicGreen.opacity(0.08)
                    ]),
                    startPoint: CGPoint(x: TimelineLayout.horizontalPadding, y: TimelineLayout.baselineY - TimelineLayout.trackHeight * 0.4),
                    endPoint: CGPoint(x: width - TimelineLayout.horizontalPadding, y: baselineY)
                )
            )
            
            // Mood drift line
            var line = Path()
            line.move(to: CGPoint(x: positioned.first!.x, y: positioned.first!.y))
            positioned.dropFirst().forEach { line.addLine(to: CGPoint(x: $0.x, y: $0.y)) }
            context.stroke(
                line,
                with: .linearGradient(
                    Gradient(colors: [.kosmicBlue, .kosmicPurple, .kosmicGreen]),
                    startPoint: CGPoint(x: TimelineLayout.horizontalPadding, y: TimelineLayout.baselineY - TimelineLayout.trackHeight * 0.4),
                    endPoint: CGPoint(x: width - TimelineLayout.horizontalPadding, y: baselineY)
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
    }
    
    private struct PositionedJournalData {
        let journal: Journal
        let ratio: CGFloat
        let laneIndex: Int
        let laneCount: Int
        let moodScore: Double
    }
    
    private struct PositionedJournal: Identifiable {
        let journal: Journal
        let x: CGFloat
        let y: CGFloat
        
        var id: UUID { journal.id }
    }
    
    private func computeMonthMarkers(for entries: [PositionedJournal]) -> [TimelineMonthMarker] {
        var markers: [TimelineMonthMarker] = []
        let calendar = Calendar.current
        var seenKeys: Set<String> = []
        
        for entry in entries {
            let components = calendar.dateComponents([.year, .month], from: entry.journal.entryDate)
            let key = "\(components.year ?? 0)-\(components.month ?? 0)"
            if !seenKeys.contains(key) {
                let label = timelineMonthFormatter.string(from: entry.journal.entryDate)
                markers.append(TimelineMonthMarker(label: label, x: entry.x))
                seenKeys.insert(key)
            }
        }
        
        return markers
    }
}

private struct TimelineMarker: View {
    let journal: Journal
    let isActive: Bool
    let moodColor: Color
    let shortDate: String
    let reduceMotion: Bool
    let onTap: () -> Void
    let onHoverChanged: (Bool) -> Void
    
    @State private var isHovered = false
    
    private var nodeScale: CGFloat {
        guard !reduceMotion else { return 1 }
        return (isHovered || isActive) ? TimelineLayout.activeNodeScale : 1
    }
    
    var body: some View {
        VStack(spacing: TimelineLayout.infoCardSpacing) {
            if isHovered || isActive {
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
                            moodColor.opacity((isHovered || isActive) ? 0.85 : 0.6),
                            moodColor.opacity((isHovered || isActive) ? 0.18 : 0.08)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: (isHovered || isActive) ? 22 : 16
                    )
                )
                .frame(width: TimelineLayout.nodeBaseSize, height: TimelineLayout.nodeBaseSize)
                .overlay(
                    Circle()
                        .stroke(.white.opacity((isHovered || isActive) ? 0.85 : 0.55), lineWidth: (isHovered || isActive) ? 2 : 1)
                )
                .shadow(color: moodColor.opacity((isHovered || isActive) ? 0.4 : 0.18), radius: (isHovered || isActive) ? 12 : 6, y: (isHovered || isActive) ? 6 : 3)
                .scaleEffect(nodeScale, anchor: .center)
                .animation(reduceMotion ? nil : GlassMotion.Easing.spring, value: nodeScale)
            
            Text(shortDate)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 92)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { hovering in
            if isHovered != hovering {
                isHovered = hovering
                onHoverChanged(hovering)
            }
        }
    }
}

private struct TimelineMonthMarker: Identifiable {
    let id = UUID()
    let label: String
    let x: CGFloat
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

private func moodLegendColor(for mood: JournalMood) -> Color {
    moodColor(for: mood)
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

