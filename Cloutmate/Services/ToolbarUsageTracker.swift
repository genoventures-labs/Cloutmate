//
//  ToolbarUsageTracker.swift
//  Cloutmate
//
//  Tracks toolbar button usage and provides smart reordering
//

import Foundation

enum ToolbarAction: String, Codable, CaseIterable {
    case createTask = "Create Task"
    case createProject = "Create Project"
    case createNote = "Create Note"
    case createReminder = "Create Reminder"
    case analyzeDocument = "Analyze Document"
    case analyzeImage = "Analyze Image"
    
    var icon: String {
        switch self {
        case .createTask: return "checkmark.circle.fill"
        case .createProject: return "folder.fill"
        case .createNote: return "note.text"
        case .createReminder: return "bell.fill"
        case .analyzeDocument: return "doc.text.viewfinder"
        case .analyzeImage: return "photo.fill"
        }
    }
}

@MainActor
final class ToolbarUsageTracker {
    static let shared = ToolbarUsageTracker()
    
    private let usageKey = "AIAssistantToolbarUsage"
    private var usageCounts: [ToolbarAction: Int] = [:]
    
    private init() {
        loadUsage()
    }
    
    /// Track usage of a toolbar action
    func trackUsage(_ action: ToolbarAction) {
        usageCounts[action, default: 0] += 1
        saveUsage()
    }
    
    /// Get ordered toolbar actions by usage frequency (most-used first)
    func orderedActions() -> [ToolbarAction] {
        ToolbarAction.allCases.sorted { action1, action2 in
            let count1 = usageCounts[action1] ?? 0
            let count2 = usageCounts[action2] ?? 0
            return count1 > count2
        }
    }
    
    /// Reset usage counts
    func resetUsage() {
        usageCounts.removeAll()
        saveUsage()
    }
    
    /// Get usage count for an action
    func usageCount(for action: ToolbarAction) -> Int {
        usageCounts[action] ?? 0
    }
    
    private func loadUsage() {
        guard let data = UserDefaults.standard.data(forKey: usageKey),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            // Initialize with default order
            return
        }
        
        usageCounts = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
            guard let action = ToolbarAction(rawValue: key) else { return nil }
            return (action, value)
        })
    }
    
    private func saveUsage() {
        let stringKeyed = usageCounts.mapKeys { $0.rawValue }
        if let encoded = try? JSONEncoder().encode(stringKeyed) {
            UserDefaults.standard.set(encoded, forKey: usageKey)
        }
    }
}

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0), $1) })
    }
}

