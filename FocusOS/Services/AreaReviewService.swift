//
//  AreaReviewService.swift
//  FocusOS
//
//  Created by GPT-5 Codex on 11/12/25.
//

import Foundation
import SwiftData
import FocusOSShared

struct AreaReviewStatus {
    let isDue: Bool
    let reason: String
    let overdueDays: Int?
    let intervalDays: Int
    let lastReviewDate: Date?
    let nextReviewDate: Date
}

struct AreaReviewSummary {
    let status: AreaReviewStatus
    let pendingTasks: [FocusOSShared.Task]
    let overdueTasks: [FocusOSShared.Task]
    let stalledProjects: [FocusOSShared.Project]
    let recentNotes: [Note]
    let checklistItems: [AreaReviewChecklistItem]
}

struct AreaReviewChecklistItem: Identifiable {
    enum State {
        case complete
        case attention
    }
    
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let state: State
}

final class AreaReviewService {
    static let shared = AreaReviewService()
    
    private init() {}
    
    // MARK: - Public API
    
    func status(for area: Area) -> AreaReviewStatus {
        guard area.status != .archived else {
            return AreaReviewStatus(
                isDue: false,
                reason: "Archived areas are excluded from review.",
                overdueDays: nil,
                intervalDays: 0,
                lastReviewDate: area.lastReviewDate,
                nextReviewDate: Date.distantFuture
            )
        }
        
        let interval = reviewIntervalDays(for: area)
        let now = Date()
        
        if let lastReview = area.lastReviewDate {
            let daysSinceReview = Calendar.current.dateComponents([.day], from: lastReview, to: now).day ?? 0
            let overdueDays = max(0, daysSinceReview - interval)
            let nextReview = Calendar.current.date(byAdding: .day, value: interval, to: lastReview) ?? lastReview
            let isOverdue = overdueDays > 0
            let isFlagged = area.status == .reviewNeeded
            let isDue = isOverdue || isFlagged
            
            let reason: String
            if isFlagged && !isOverdue {
                reason = "Manually flagged for review."
            } else if overdueDays > 0 {
                reason = overdueDays == 1 ? "Review was due yesterday." : "Review overdue by \(overdueDays) days."
            } else {
                reason = "Scheduled every \(interval) days."
            }
            
            return AreaReviewStatus(
                isDue: isDue,
                reason: reason,
                overdueDays: overdueDays > 0 ? overdueDays : nil,
                intervalDays: interval,
                lastReviewDate: lastReview,
                nextReviewDate: nextReview
            )
        } else {
            let nextReview = Calendar.current.date(byAdding: .day, value: interval, to: now) ?? now
            return AreaReviewStatus(
                isDue: true,
                reason: "This area has never been reviewed.",
                overdueDays: nil,
                intervalDays: interval,
                lastReviewDate: nil,
                nextReviewDate: nextReview
            )
        }
    }
    
    func summary(
        for area: Area,
        tasks: [FocusOSShared.Task],
        projects: [FocusOSShared.Project],
        notes: [Note]
    ) -> AreaReviewSummary {
        let status = status(for: area)
        
        let areaTasks = tasks.filter { $0.areaId == area.id }
        let pendingTasks = areaTasks.filter { $0.status != .done && $0.status != .cancelled }
        let overdueTasks = pendingTasks.filter {
            if let due = $0.dueDate {
                return due < Date() && Calendar.current.isDateInToday(due) == false
            }
            return false
        }
        
        let areaProjects = projects.filter { $0.areaId == area.id }
        let stalledProjects = areaProjects.filter { project in
            switch project.status {
            case .paused:
                return true
            case .active:
                if let due = project.dueDate {
                    return due < Date()
                }
                return false
            case .completed:
                return false
            }
        }
        
        let recentNotes = notes
            .filter { $0.areaId == area.id }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(5)
            .map { $0 }
        
        var checklist: [AreaReviewChecklistItem] = []
        
        if let overdueDays = status.overdueDays, overdueDays > 0 {
            checklist.append(
                AreaReviewChecklistItem(
                    title: "Review cadence overdue",
                    detail: status.reason,
                    icon: "exclamationmark.triangle.fill",
                    state: .attention
                )
            )
        } else if area.lastReviewDate == nil {
            checklist.append(
                AreaReviewChecklistItem(
                    title: "First review required",
                    detail: "Complete an initial review to establish cadence.",
                    icon: "sparkles",
                    state: .attention
                )
            )
        } else {
            checklist.append(
                AreaReviewChecklistItem(
                    title: "Cadence on schedule",
                    detail: status.reason,
                    icon: "calendar.badge.checkmark",
                    state: status.isDue ? .attention : .complete
                )
            )
        }
        
        if !pendingTasks.isEmpty {
            checklist.append(
                AreaReviewChecklistItem(
                    title: "\(pendingTasks.count) active task\(pendingTasks.count == 1 ? "" : "s")",
                    detail: "Review open tasks and update their status.",
                    icon: "checklist",
                    state: pendingTasks.isEmpty ? .complete : .attention
                )
            )
        } else {
            checklist.append(
                AreaReviewChecklistItem(
                    title: "Tasks up to date",
                    detail: "No pending tasks in this area.",
                    icon: "checkmark.circle.fill",
                    state: .complete
                )
            )
        }
        
        if !stalledProjects.isEmpty {
            checklist.append(
                AreaReviewChecklistItem(
                    title: "\(stalledProjects.count) project\(stalledProjects.count == 1 ? "" : "s") require attention",
                    detail: "Pause or reschedule projects that no longer align.",
                    icon: "folder.badge.questionmark",
                    state: .attention
                )
            )
        }
        
        if recentNotes.isEmpty {
            checklist.append(
                AreaReviewChecklistItem(
                    title: "Capture new insights",
                    detail: "Add a note to reflect on progress since the last review.",
                    icon: "doc.text.fill",
                    state: .attention
                )
            )
        } else {
            checklist.append(
                AreaReviewChecklistItem(
                    title: "Recent notes available",
                    detail: "Review your latest reflections to inform next steps.",
                    icon: "note.text",
                    state: .complete
                )
            )
        }
        
        return AreaReviewSummary(
            status: status,
            pendingTasks: pendingTasks.sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) },
            overdueTasks: overdueTasks.sorted { ($0.dueDate ?? Date.distantPast) < ($1.dueDate ?? Date.distantPast) },
            stalledProjects: stalledProjects.sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) },
            recentNotes: Array(recentNotes),
            checklistItems: checklist
        )
    }
    
    func syncStatus(for area: Area, modelContext: ModelContext) {
        guard area.status != .archived else { return }
        
        let currentStatus = status(for: area)
        if currentStatus.isDue && area.status != .reviewNeeded {
            area.status = .reviewNeeded
            area.updatedAt = Date()
            try? modelContext.save()
        } else if !currentStatus.isDue && area.status == .reviewNeeded {
            area.status = .active
            area.updatedAt = Date()
            try? modelContext.save()
        }
    }
    
    func markReviewed(area: Area, modelContext: ModelContext, note: String? = nil) {
        area.lastReviewDate = Date()
        area.status = .active
        area.updatedAt = Date()
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var existing = area.notes ?? ""
            if !existing.isEmpty {
                existing += "\n\n"
            }
            existing += note
            area.notes = existing
        }
        try? modelContext.save()
    }
    
    func snoozeReview(area: Area, by days: Int, modelContext: ModelContext) {
        let interval = reviewIntervalDays(for: area)
        let adjustment = max(0, interval - days)
        let newLastReview = Calendar.current.date(byAdding: .day, value: -adjustment, to: Date()) ?? Date()
        area.lastReviewDate = newLastReview
        area.status = .active
        area.updatedAt = Date()
        try? modelContext.save()
    }
    
    // MARK: - Helpers
    
    private func reviewIntervalDays(for area: Area) -> Int {
        if let cadence = area.cadenceSetting, !cadence.isEmpty {
            if let interval = parseInterval(from: cadence) {
                return max(3, interval)
            }
        }
        
        // Fallback based on stability
        if area.stabilityScore >= 70 {
            return 21
        } else if area.stabilityScore >= 40 {
            return 14
        } else {
            return 7
        }
    }
    
    private struct CadenceSettings: Codable {
        var reviewIntervalDays: Int?
        var frequency: String?
        var cadence: String?
    }
    
    private func parseInterval(from raw: String) -> Int? {
        let data = raw.data(using: .utf8) ?? Data()
        if let settings = try? JSONDecoder().decode(CadenceSettings.self, from: data) {
            if let interval = settings.reviewIntervalDays {
                return interval
            }
            if let frequency = settings.frequency ?? settings.cadence {
                return mapFrequencyToDays(frequency)
            }
        }
        
        return mapFrequencyToDays(raw)
    }
    
    private func mapFrequencyToDays(_ value: String) -> Int {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("weekly") {
            return 7
        } else if normalized.contains("bi-weekly") || normalized.contains("biweekly") {
            return 14
        } else if normalized.contains("monthly") {
            return 30
        } else if normalized.contains("quarter") {
            return 90
        } else if normalized.contains("daily") {
            return 1
        }
        return 14
    }
}


