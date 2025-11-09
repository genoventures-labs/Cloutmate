//
//  ArcViewTimeline.swift
//  Cloutmate
//
//  Arc View Timeline - Cinematic visualization of work history
//

import SwiftUI
import SwiftData
import Charts

struct ArcViewTimeline: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoryArc.startDate, order: .forward) private var arcs: [StoryArc]
    @Query(sort: \StoryChapter.startDate, order: .forward) private var chapters: [StoryChapter]
    @Query(sort: \StoryScene.timestamp, order: .forward) private var scenes: [StoryScene]
    
    @State private var selectedArc: StoryArc?
    @State private var selectedChapter: StoryChapter?
    @State private var selectedScene: StoryScene?
    @State private var scrollPosition: Date?
    @State private var timeRange: TimeRange = .quarter
    @State private var isLoading = false
    @State private var showingSceneDetail = false
    @Query(sort: \AIMessage.timestamp, order: .forward) private var messages: [AIMessage]
    @Query(sort: \StoryToken.startDate, order: .forward) private var tokens: [StoryToken]
    
    enum TimeRange: String, CaseIterable {
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
        case all = "All Time"
    }
    
    var filteredArcs: [StoryArc] {
        guard let range = dateRange else { return arcs }
        return arcs.filter { arc in
            range.contains(arc.startDate) || (arc.endDate != nil && range.contains(arc.endDate!))
        }
    }
    
    var filteredChapters: [StoryChapter] {
        guard let selectedArc = selectedArc else {
            guard let range = dateRange else { return chapters }
            return chapters.filter { range.contains($0.startDate) }
        }
        return chapters.filter { $0.arcId == selectedArc.id }
    }
    
    var filteredScenes: [StoryScene] {
        guard let selectedChapter = selectedChapter else {
            guard let selectedArc = selectedArc else {
                guard let range = dateRange else { return scenes }
                return scenes.filter { range.contains($0.timestamp) }
            }
            let chapterIds = chapters.filter { $0.arcId == selectedArc.id }.map { $0.id }
            return scenes.filter { chapterIds.contains($0.chapterId) }
        }
        return scenes.filter { $0.chapterId == selectedChapter.id }
    }
    
    var dateRange: DateInterval? {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeRange {
        case .month:
            guard let start = calendar.date(byAdding: .month, value: -1, to: now) else { return nil }
            return DateInterval(start: start, end: now)
        case .quarter:
            guard let start = calendar.date(byAdding: .month, value: -3, to: now) else { return nil }
            return DateInterval(start: start, end: now)
        case .year:
            guard let start = calendar.date(byAdding: .year, value: -1, to: now) else { return nil }
            return DateInterval(start: start, end: now)
        case .all:
            return nil
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            timelineContent
        }
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showingSceneDetail) {
            if let scene = selectedScene {
                SceneDetailView(scene: scene, messages: messages, tokens: tokens)
            }
        }
        .task {
            await loadArcs()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arc View Timeline")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("Your work history as a cinematic timeline")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Time range picker
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            
            // Arc filter chips
            if !filteredArcs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button(action: { selectedArc = nil }) {
                            Text("All Arcs")
                                .font(.system(size: 12))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedArc == nil ? Color.kosmicBlue : Color.secondary.opacity(0.1))
                                .foregroundColor(selectedArc == nil ? .white : .primary)
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                        
                        ForEach(filteredArcs, id: \.id) { arc in
                            Button(action: { selectedArc = arc }) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(arcColor(for: arc))
                                        .frame(width: 8, height: 8)
                                    Text(arc.label)
                                        .font(.system(size: 12))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedArc?.id == arc.id ? Color.kosmicBlue : Color.secondary.opacity(0.1))
                                .foregroundColor(selectedArc?.id == arc.id ? .white : .primary)
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(24)
    }
    
    private var timelineContent: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            GeometryReader { geometry in
                timelineCanvas(width: max(geometry.size.width, calculateTimelineWidth()))
            }
        }
        .frame(height: 600)
    }
    
    private func timelineCanvas(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Timeline baseline
            timelineBaseline(width: width)
            
            // Arc highlights
            ForEach(filteredArcs, id: \.id) { arc in
                arcHighlight(arc: arc, width: width)
            }
            
            // Chapter markers
            ForEach(filteredChapters, id: \.id) { chapter in
                chapterMarker(chapter: chapter, width: width)
            }
            
            // Scene markers
            ForEach(filteredScenes, id: \.id) { scene in
                sceneMarker(scene: scene, width: width)
            }
            
            // Current time indicator
            currentTimeIndicator(width: width)
        }
        .frame(width: width, height: 600)
    }
    
    private func timelineBaseline(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: width, height: 2)
            .offset(y: 300)
    }
    
    private func arcHighlight(arc: StoryArc, width: CGFloat) -> some View {
        let startX = dateToX(arc.startDate, width: width)
        let endX = arc.endDate != nil ? dateToX(arc.endDate!, width: width) : width
        let arcWidth = max(20, endX - startX)
        
        return RoundedRectangle(cornerRadius: 8)
            .fill(arcColor(for: arc).opacity(0.2))
            .frame(width: arcWidth, height: 100)
            .offset(x: startX, y: 250)
            .overlay(
                VStack(alignment: .leading, spacing: 4) {
                    Text(arc.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(arcColor(for: arc))
                    if !arc.themes.isEmpty {
                        Text(arc.themes.joined(separator: ", "))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .frame(maxWidth: arcWidth - 16, alignment: .leading),
                alignment: .topLeading
            )
            .onTapGesture {
                selectedArc = arc
            }
    }
    
    private func chapterMarker(chapter: StoryChapter, width: CGFloat) -> some View {
        let x = dateToX(chapter.startDate, width: width)
        
        return VStack(spacing: 4) {
            Circle()
                .fill(Color.kosmicPurple)
                .frame(width: 12, height: 12)
            
            Text(chapter.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: 100)
                .multilineTextAlignment(.center)
            
            Text(chapter.startDate.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .offset(x: x - 50, y: 280)
        .onTapGesture {
            selectedChapter = chapter
        }
    }
    
    private func sceneMarker(scene: StoryScene, width: CGFloat) -> some View {
        let x = dateToX(scene.timestamp, width: width)
        let sceneColor = sceneColor(for: scene.eventType)
        
        return VStack(spacing: 2) {
            Image(systemName: sceneIcon(for: scene.eventType))
                .font(.system(size: 14))
                .foregroundColor(sceneColor)
            
            Text(scene.title)
                .font(.system(size: 10))
                .foregroundColor(.primary)
                .frame(maxWidth: 80)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(6)
        .background(
            Circle()
                .fill(sceneColor.opacity(0.1))
                .frame(width: 40, height: 40)
        )
        .offset(x: x - 20, y: 320)
        .onTapGesture {
            selectedScene = scene
            showingSceneDetail = true
        }
    }
    
    private func currentTimeIndicator(width: CGFloat) -> some View {
        let x = dateToX(Date(), width: width)
        
        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color.kosmicBlue)
                .frame(width: 2, height: 200)
            
            Text("Now")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.kosmicBlue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.kosmicBlue.opacity(0.1))
                .cornerRadius(4)
        }
        .offset(x: x - 1, y: 200)
    }
    
    private func dateToX(_ date: Date, width: CGFloat) -> CGFloat {
        guard let range = dateRange else {
            // All time - use arc dates
            guard let firstArc = arcs.first,
                  let lastArc = arcs.last else {
                return 0
            }
            let lastDate = lastArc.endDate ?? lastArc.startDate
            let totalDays = Calendar.current.dateComponents([.day], from: firstArc.startDate, to: lastDate).day ?? 1
            let daysFromStart = Calendar.current.dateComponents([.day], from: firstArc.startDate, to: date).day ?? 0
            return CGFloat(daysFromStart) / CGFloat(totalDays) * width
        }
        
        let totalDays = Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 1
        let daysFromStart = Calendar.current.dateComponents([.day], from: range.start, to: date).day ?? 0
        return CGFloat(daysFromStart) / CGFloat(totalDays) * width
    }
    
    private func calculateTimelineWidth() -> CGFloat {
        guard let range = dateRange else {
            // All time - calculate from arcs
            guard let firstArc = arcs.first,
                  let lastArc = arcs.last else {
                return 1000
            }
            let lastDate = lastArc.endDate ?? lastArc.startDate
            let days = Calendar.current.dateComponents([.day], from: firstArc.startDate, to: lastDate).day ?? 30
            return CGFloat(days * 20) // 20 points per day
        }
        
        let days = Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 30
        return CGFloat(days * 20) // 20 points per day
    }
    
    private func arcColor(for arc: StoryArc) -> Color {
        if arc.momentum > 0.5 {
            return .kosmicGreen
        } else if arc.momentum < -0.3 {
            return .orange
        } else {
            return .kosmicBlue
        }
    }
    
    private func sceneColor(for eventType: String) -> Color {
        switch eventType {
        case "completion":
            return .kosmicGreen
        case "reflection":
            return .kosmicPurple
        case "milestone":
            return .kosmicBlue
        default:
            return .secondary
        }
    }
    
    private func sceneIcon(for eventType: String) -> String {
        switch eventType {
        case "completion":
            return "checkmark.circle.fill"
        case "reflection":
            return "brain.head.profile"
        case "milestone":
            return "star.fill"
        default:
            return "circle.fill"
        }
    }
    
    private func loadArcs() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let range = dateRange else { return }
        
        let detectedArcs = await NarrativeEngine.shared.detectArcs(
            in: range,
            modelContext: modelContext
        )
        
        // Arcs are already saved by ArcDetectionService
    }
}

// MARK: - Scene Detail View

struct SceneDetailView: View {
    let scene: StoryScene
    let messages: [AIMessage]
    let tokens: [StoryToken]
    @Environment(\.dismiss) private var dismiss
    
    var relatedMessages: [AIMessage] {
        // Find messages around the scene timestamp
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .hour, value: -2, to: scene.timestamp) ?? scene.timestamp
        let endDate = calendar.date(byAdding: .hour, value: 2, to: scene.timestamp) ?? scene.timestamp
        
        return messages.filter { message in
            guard let timestamp = message.timestamp else { return false }
            return timestamp >= startDate && timestamp <= endDate
        }
    }
    
    var relatedTokens: [StoryToken] {
        // Find tokens linked to this scene
        guard let linkedId = scene.linkedObjectId else { return [] }
        return tokens.filter { token in
            token.linkedResourceIds.contains(linkedId)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(scene.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            
            Text(scene.timestamp.formatted(date: .complete, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Scene Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        
                        Text(scene.sceneDescription)
                            .font(.body)
                    }
                    
                    // Dialogue from AIMessage
                    if !relatedMessages.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Related Conversations")
                                .font(.headline)
                            
                            ForEach(relatedMessages.prefix(5), id: \.id) { message in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(message.role == "assistant" ? "Aurora" : "You")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(message.role == "assistant" ? .kosmicPurple : .kosmicBlue)
                                        
                                        Spacer()
                                        
                                        if let timestamp = message.timestamp {
                                            Text(timestamp.formatted(date: .omitted, time: .shortened))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    if let content = message.content, !content.isEmpty {
                                        Text(content)
                                            .font(.body)
                                            .padding(12)
                                            .background(message.role == "assistant" ? Color.kosmicPurple.opacity(0.1) : Color.kosmicBlue.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Dialogue from scene
                    if let dialogue = scene.dialogue, !dialogue.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dialogue")
                                .font(.headline)
                            
                            Text(dialogue)
                                .font(.body)
                                .italic()
                                .foregroundColor(.secondary)
                                .padding(12)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Linked Artifacts from StoryToken
                    if !relatedTokens.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Related Story Tokens")
                                .font(.headline)
                            
                            ForEach(relatedTokens.prefix(3), id: \.id) { token in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(token.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text(token.summary)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .padding(24)
        .frame(width: 600, height: 500)
    }
}

#Preview {
    ArcViewTimeline()
        .modelContainer(for: [StoryArc.self, StoryChapter.self, StoryScene.self], inMemory: true)
}

