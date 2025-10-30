//
//  AISettings.swift
//  Cloutmate
//
//  AI Settings Management
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AISettings {
    static let shared = AISettings()
    
    private let userDefaults = UserDefaults.standard
    private let aiEnabledKey = "com.kosmicapps.cloutmate.aiEnabled"
    
    var isAIEnabled: Bool {
        get {
            userDefaults.bool(forKey: aiEnabledKey)
        }
        set {
            userDefaults.set(newValue, forKey: aiEnabledKey)
        }
    }
    
    private init() {}
    
    func toggleAI() {
        isAIEnabled.toggle()
    }
}
