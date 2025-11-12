//
//  ArteTintManager.swift
//  Cloutmate
//
//  ARTE Tint Manager - Provides consistent tint colors based on emotional states
//

import SwiftUI
import Combine

@MainActor
@Observable
final class ArteTintManager {
    static let shared = ArteTintManager()
    
    private var glassColorSystem: GlassColorSystem? {
        GlassColorSystem.active
    }
    
    private init() {}
    
    /// Get the appropriate tint color based on ARTE emotional state
    var tintColor: Color {
        guard let glassSystem = glassColorSystem, glassSystem.isARTEEnabled else {
            return Color.secondary
        }
        
        let kosmicBlue = Color(red: 72/255, green: 131/255, blue: 255/255)
        let kosmicPurple = Color(red: 124/255, green: 77/255, blue: 255/255)
        
        switch glassSystem.emotionalState {
        case .focused:
            return kosmicBlue
        case .calm:
            return Color.secondary
        case .reflective:
            return kosmicPurple.opacity(0.8)
        case .energized:
            return kosmicBlue.opacity(0.9)
        case .fatigued:
            return Color.secondary.opacity(0.7)
        }
    }
    
    /// Get tint color based on activity type (for cases where emotional state isn't set)
    func tintColor(for activity: AIAssistantViewModel.ActivityType?) -> Color {
        guard let activity = activity else {
            return tintColor
        }
        
        let kosmicBlue = Color(red: 72/255, green: 131/255, blue: 255/255)
        
        // Map activities to tint colors
        switch activity {
        case .warmingUp:
            return Color.orange.opacity(0.75)
        case .analyzingDocument, .analyzingImage:
            return Color.orange.opacity(0.8) // Warm amber for analyzing
        case .thinking, .reflecting:
            return kosmicBlue.opacity(0.7)
        case .generatingResponse:
            return kosmicBlue
        case .creatingTasks, .creatingProject, .creatingNote, .creatingPost:
            return kosmicBlue
        case .searching:
            return Color.secondary
        }
    }
    
    /// Get tint color combining both emotional state and activity
    func combinedTintColor(activity: AIAssistantViewModel.ActivityType?) -> Color {
        // Prioritize analyzing activities (amber) over emotional state
        if let activity = activity,
           activity == .analyzingDocument || activity == .analyzingImage {
            return Color.orange.opacity(0.8)
        }
        
        return tintColor
    }
}

