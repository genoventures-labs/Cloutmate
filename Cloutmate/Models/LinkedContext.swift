//
//  LinkedContext.swift
//  Cloutmate
//
//  Model for storing linked workspace objects from @ mentions
//

import Foundation
import SwiftData

enum ObjectType: String, Codable {
    case project
    case task
    case note
    case artifact
    case post
    case reminder
    case inboxItem
    case focusSession
    
    var icon: String {
        switch self {
        case .project: return "folder.fill"
        case .task: return "checkmark.circle"
        case .note: return "doc.text.fill"
        case .artifact: return "doc.richtext"
        case .post: return "square.and.pencil"
        case .reminder: return "bell.fill"
        case .inboxItem: return "tray.fill"
        case .focusSession: return "timer"
        }
    }
}

struct LinkedContext: Codable {
    var linkedProjects: [UUID] = []
    var linkedTasks: [UUID] = []
    var linkedNotes: [UUID] = []
    var linkedArtifacts: [UUID] = []
    var linkedPosts: [UUID] = []
    var linkedReminders: [UUID] = []
    var linkedInboxItems: [UUID] = []
    var linkedFocusSessions: [UUID] = []
    
    /// Maps mention text (e.g., "@projectname") to object type and ID
    /// Note: mentionMap is not Codable (tuples aren't Codable), so it's excluded from encoding/decoding
    var mentionMap: [String: (type: ObjectType, id: UUID, displayName: String)] = [:]
    
    /// Custom Codable implementation that excludes mentionMap
    enum CodingKeys: String, CodingKey {
        case linkedProjects
        case linkedTasks
        case linkedNotes
        case linkedArtifacts
        case linkedPosts
        case linkedReminders
        case linkedInboxItems
        case linkedFocusSessions
    }
    
    /// Add a linked object
    mutating func addLinkedObject(type: ObjectType, id: UUID, mentionText: String, displayName: String) {
        mentionMap[mentionText.lowercased()] = (type: type, id: id, displayName: displayName)
        
        switch type {
        case .project:
            if !linkedProjects.contains(id) {
                linkedProjects.append(id)
            }
        case .task:
            if !linkedTasks.contains(id) {
                linkedTasks.append(id)
            }
        case .note:
            if !linkedNotes.contains(id) {
                linkedNotes.append(id)
            }
        case .artifact:
            if !linkedArtifacts.contains(id) {
                linkedArtifacts.append(id)
            }
        case .post:
            if !linkedPosts.contains(id) {
                linkedPosts.append(id)
            }
        case .reminder:
            if !linkedReminders.contains(id) {
                linkedReminders.append(id)
            }
        case .inboxItem:
            if !linkedInboxItems.contains(id) {
                linkedInboxItems.append(id)
            }
        case .focusSession:
            if !linkedFocusSessions.contains(id) {
                linkedFocusSessions.append(id)
            }
        }
    }
    
    /// Get object ID for a mention text
    func getObjectId(for mentionText: String) -> UUID? {
        return mentionMap[mentionText.lowercased()]?.id
    }
    
    /// Get object type for a mention text
    func getObjectType(for mentionText: String) -> ObjectType? {
        return mentionMap[mentionText.lowercased()]?.type
    }
    
    /// Clear all linked objects
    mutating func clear() {
        linkedProjects.removeAll()
        linkedTasks.removeAll()
        linkedNotes.removeAll()
        linkedArtifacts.removeAll()
        linkedPosts.removeAll()
        linkedReminders.removeAll()
        linkedInboxItems.removeAll()
        linkedFocusSessions.removeAll()
        mentionMap.removeAll()
    }
    
    /// Check if linked context is empty
    var isEmpty: Bool {
        return linkedProjects.isEmpty &&
               linkedTasks.isEmpty &&
               linkedNotes.isEmpty &&
               linkedArtifacts.isEmpty &&
               linkedPosts.isEmpty &&
               linkedReminders.isEmpty &&
               linkedInboxItems.isEmpty &&
               linkedFocusSessions.isEmpty
    }
}


