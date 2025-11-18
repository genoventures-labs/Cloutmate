//
//  ArchiveAnalyticsService.swift
//  FocusOS
//
//  Aggregates metrics for the Archives experience.
//

import Foundation
import SwiftData
import FocusOSShared

enum ArchiveReviewRange: CaseIterable {
    case thisWeek
    case thisMonth
    case allTime
}

struct ArchiveReviewEntry: Identifiable {
    let id: UUID
    let item: ArchiveItem
    let reflection: ArchiveReflection?
    let archivedAt: Date?
    let tone: EmotionalState?
    let summary: String?
    
    var filter: ArchiveFilter {
        switch item {
        case .project: return .projects
        case .area: return .areas
        case .note: return .notes
        case .artifact: return .artifacts
        case .draft: return .drafts
        }
    }
    
    var title: String {
        item.title
    }
    
    var entityType: String {
        item.entityType
    }
}

struct ArchiveAnalyticsSnapshot {
    let range: ArchiveReviewRange
    let entries: [ArchiveReviewEntry]
    let countsByType: [ArchiveFilter: Int]
    let toneCounts: [EmotionalState: Int]
    let reflectionsCount: Int
    let learningThemes: [String: Int]
    
    var totalArchived: Int {
        entries.count
    }
    
    var recentItems: [ArchiveReviewEntry] {
        entries.sorted { (lhs, rhs) in
            let lhsDate = lhs.archivedAt ?? Date.distantPast
            let rhsDate = rhs.archivedAt ?? Date.distantPast
            return lhsDate > rhsDate
        }
    }
    
    var mostCommonTone: EmotionalState? {
        toneCounts.max(by: { $0.value < $1.value })?.key
    }
}

@MainActor
final class ArchiveAnalyticsService {
    static let shared = ArchiveAnalyticsService()
    private let calendar = Calendar.current
    
    private init() {}
    
    func snapshot(
        for range: ArchiveReviewRange,
        modelContext: ModelContext
    ) -> ArchiveAnalyticsSnapshot {
        let reflections = (try? modelContext.fetch(FetchDescriptor<ArchiveReflection>())) ?? []
        let reflectionsById = Dictionary(uniqueKeysWithValues: reflections.map { ($0.entityId, $0) })
        
        let dateInterval = interval(for: range)
        
        var entries: [ArchiveReviewEntry] = []
        var countsByType: [ArchiveFilter: Int] = [:]
        var toneCounts: [EmotionalState: Int] = [:]
        var learningThemeCounts: [String: Int] = [:]
        
        // Collect archived projects
        let projects = (try? modelContext.fetch(FetchDescriptor<FocusOSShared.Project>())) ?? []
        for project in projects {
            guard project.status == .completed || project.status == .paused else { continue }
            let archivedDate = project.archivedAt ?? project.updatedAt
            if let interval = dateInterval, !interval.contains(archivedDate) { continue }
            let item = ArchiveItem.project(project)
            let entry = makeEntry(for: item, archivedAt: archivedDate, reflections: reflectionsById)
            accumulate(entry, countsByType: &countsByType, toneCounts: &toneCounts, learningThemeCounts: &learningThemeCounts)
            entries.append(entry)
        }
        
        // Areas
        let areas = (try? modelContext.fetch(FetchDescriptor<Area>())) ?? []
        for area in areas where area.status == .archived {
            let archivedDate = area.archivedAt ?? area.updatedAt
            if let interval = dateInterval, !interval.contains(archivedDate) { continue }
            let item = ArchiveItem.area(area)
            let entry = makeEntry(for: item, archivedAt: archivedDate, reflections: reflectionsById)
            accumulate(entry, countsByType: &countsByType, toneCounts: &toneCounts, learningThemeCounts: &learningThemeCounts)
            entries.append(entry)
        }
        
        // Notes
        let notes = (try? modelContext.fetch(FetchDescriptor<FocusOSShared.Note>())) ?? []
        for note in notes where note.isArchived {
            let archivedDate = note.archivedAt ?? note.updatedAt
            if let interval = dateInterval, !interval.contains(archivedDate) { continue }
            let item = ArchiveItem.note(note)
            let entry = makeEntry(for: item, archivedAt: archivedDate, reflections: reflectionsById)
            accumulate(entry, countsByType: &countsByType, toneCounts: &toneCounts, learningThemeCounts: &learningThemeCounts)
            entries.append(entry)
        }
        
        // Artifacts
        let artifacts = (try? modelContext.fetch(FetchDescriptor<FocusOSShared.Artifact>())) ?? []
        for artifact in artifacts where artifact.artifactState == .archived {
            let archivedDate = artifact.archivedAt ?? artifact.updatedAt
            if let interval = dateInterval, !interval.contains(archivedDate) { continue }
            let item = ArchiveItem.artifact(artifact)
            let entry = makeEntry(for: item, archivedAt: archivedDate, reflections: reflectionsById)
            accumulate(entry, countsByType: &countsByType, toneCounts: &toneCounts, learningThemeCounts: &learningThemeCounts)
            entries.append(entry)
        }
        
        // Drafts
        let drafts = (try? modelContext.fetch(FetchDescriptor<Draft>())) ?? []
        for draft in drafts where draft.isArchived {
            let archivedDate = draft.archivedAt ?? draft.updatedAt
            if let interval = dateInterval, !interval.contains(archivedDate) { continue }
            let item = ArchiveItem.draft(draft)
            let entry = makeEntry(for: item, archivedAt: archivedDate, reflections: reflectionsById)
            accumulate(entry, countsByType: &countsByType, toneCounts: &toneCounts, learningThemeCounts: &learningThemeCounts)
            entries.append(entry)
        }
        
        return ArchiveAnalyticsSnapshot(
            range: range,
            entries: entries,
            countsByType: countsByType,
            toneCounts: toneCounts,
            reflectionsCount: reflectionsById.count,
            learningThemes: learningThemeCounts
        )
    }
    
    // MARK: - Helpers
    
    private func makeEntry(
        for item: ArchiveItem,
        archivedAt: Date?,
        reflections: [UUID: ArchiveReflection]
    ) -> ArchiveReviewEntry {
        let reflection = reflections[item.id]
        let tone = reflection?.arteToneSnapshot.flatMap { EmotionalState(rawValue: $0) }
        let summary = item.description ?? reflection?.reflectionText
        return ArchiveReviewEntry(
            id: item.id,
            item: item,
            reflection: reflection,
            archivedAt: archivedAt,
            tone: tone,
            summary: summary
        )
    }
    
    private func accumulate(
        _ entry: ArchiveReviewEntry,
        countsByType: inout [ArchiveFilter: Int],
        toneCounts: inout [EmotionalState: Int],
        learningThemeCounts: inout [String: Int]
    ) {
        countsByType[entry.filter, default: 0] += 1
        if let tone = entry.tone {
            toneCounts[tone, default: 0] += 1
        }
        if let themes = entry.reflection?.learningThemes {
            for theme in themes {
                learningThemeCounts[theme, default: 0] += 1
            }
        }
    }
    
    private func interval(for range: ArchiveReviewRange) -> DateInterval? {
        let now = Date()
        switch range {
        case .thisWeek:
            guard let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return nil }
            return DateInterval(start: start, end: now)
        case .thisMonth:
            guard let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) else { return nil }
            return DateInterval(start: start, end: now)
        case .allTime:
            return nil
        }
    }
}


