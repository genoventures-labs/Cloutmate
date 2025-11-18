//
//  MoodEntry.swift
//  FocusOS
//
//  Daily mood snapshots for Emotional Context Engine
//

import Foundation
import SwiftData

enum MoodType: String, Codable, CaseIterable {
    case calm
    case ambitious
    case drained
    case inspired
    
    var color: String {
        switch self {
        case .calm: return "blue"
        case .ambitious: return "green"
        case .drained: return "orange"
        case .inspired: return "purple"
        }
    }
}

@Model
final class MoodEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var mood: String                // MoodType rawValue
    var valence: Double             // -1.0 to 1.0
    var intensity: Double           // 0.0 to 1.0
    var source: String              // "journal", "reflection", "ai_conversation"
    var notes: String?
    var createdAt: Date
    
    init(
        date: Date = Date(),
        mood: MoodType,
        valence: Double,
        intensity: Double,
        source: String,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.mood = mood.rawValue
        self.valence = valence
        self.intensity = intensity
        self.source = source
        self.notes = notes
        self.createdAt = Date()
    }
    
    var moodType: MoodType {
        get { MoodType(rawValue: mood) ?? .calm }
        set { mood = newValue.rawValue }
    }
}

