//
//  CreateActionUsage.swift
//  Cloutmate
//
//  Tracks usage patterns for create actions to enable smart defaults
//

import Foundation
import SwiftData

@Model
final class CreateActionUsage {
    var id: UUID = UUID()
    var tabRaw: String = "" // TabIdentifier raw value
    var actionType: String = "" // e.g., "New Note", "Task", "Subtask"
    var timestamp: Date = Date()
    var weekOfYear: Int = 0 // For "most used last week" queries
    var year: Int = 0
    
    init(tab: TabIdentifier, actionType: String) {
        self.tabRaw = tab.rawValue
        self.actionType = actionType
        self.timestamp = Date()
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear, .year], from: Date())
        self.weekOfYear = components.weekOfYear ?? 0
        self.year = components.year ?? 0
    }
    
    var tab: TabIdentifier? {
        get {
            TabIdentifier(rawValue: tabRaw)
        }
        set {
            tabRaw = newValue?.rawValue ?? ""
        }
    }
}

