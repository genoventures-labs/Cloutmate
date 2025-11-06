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
    private let airplaneModeKey = "com.kosmicapps.cloutmate.airplaneMode"
    private let selectedOllamaModelKey = "com.kosmicapps.cloutmate.selectedOllamaModel"
    private let useHybridBridgeKey = "com.kosmicapps.cloutmate.useHybridBridge"
    private let ollamaCloudAPIKeyKey = "com.kosmicapps.cloutmate.ollamaCloudAPIKey"
    private let preferredCloudModelKey = "com.kosmicapps.cloutmate.preferredCloudModel"
    private let latencyThresholdKey = "com.kosmicapps.cloutmate.latencyThreshold"
    
    var isAIEnabled: Bool {
        get {
            userDefaults.bool(forKey: aiEnabledKey)
        }
        set {
            userDefaults.set(newValue, forKey: aiEnabledKey)
        }
    }
    
    var airplaneMode: Bool {
        get {
            userDefaults.bool(forKey: airplaneModeKey)
        }
        set {
            userDefaults.set(newValue, forKey: airplaneModeKey)
            // Notify FallbackRoutingService when airplane mode changes
            Task {
                await FallbackRoutingService.shared.setAirplaneMode(newValue)
            }
        }
    }
    
    var selectedOllamaModel: String {
        get {
            userDefaults.string(forKey: selectedOllamaModelKey) ?? "llama3.1"
        }
        set {
            userDefaults.set(newValue, forKey: selectedOllamaModelKey)
            // Notify OllamaBridgeService when model changes
            Task {
                await OllamaBridgeService.shared.setModel(newValue)
            }
        }
    }
    
    var useHybridBridge: Bool {
        get {
            // Default to true if key doesn't exist (new feature, default ON)
            if userDefaults.object(forKey: useHybridBridgeKey) == nil {
                return true
            }
            return userDefaults.bool(forKey: useHybridBridgeKey)
        }
        set {
            userDefaults.set(newValue, forKey: useHybridBridgeKey)
        }
    }
    
    var ollamaCloudAPIKey: String? {
        get {
            userDefaults.string(forKey: ollamaCloudAPIKeyKey)
        }
        set {
            if let key = newValue {
                userDefaults.set(key, forKey: ollamaCloudAPIKeyKey)
            } else {
                userDefaults.removeObject(forKey: ollamaCloudAPIKeyKey)
            }
        }
    }
    
    var preferredCloudModel: String? {
        get {
            userDefaults.string(forKey: preferredCloudModelKey)
        }
        set {
            if let model = newValue {
                userDefaults.set(model, forKey: preferredCloudModelKey)
            } else {
                userDefaults.removeObject(forKey: preferredCloudModelKey)
            }
        }
    }
    
    var latencyThreshold: TimeInterval {
        get {
            let threshold = userDefaults.double(forKey: latencyThresholdKey)
            return threshold > 0 ? threshold : 6.0 // Default 6 seconds
        }
        set {
            userDefaults.set(newValue, forKey: latencyThresholdKey)
        }
    }
    
    private init() {}
    
    func toggleAI() {
        isAIEnabled.toggle()
    }
}
