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
    
    // Model selection is now automatic - users cannot change models manually
    // Models are automatically selected based on task type (image/document vs regular chat)
    var selectedOllamaModel: String {
        get {
            // Always return default model - actual model selection happens automatically in OllamaBridgeService
            return "gemma3:1b"
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
            // Load from Info.plist or environment variable (like Meta API keys)
            if let envKey = ProcessInfo.processInfo.environment["OllamaCloudAPIKey"], !envKey.isEmpty {
                return envKey
            }
            if let bundle = Bundle.main.object(forInfoDictionaryKey: "OllamaCloudAPIKey") as? String, !bundle.isEmpty {
                return bundle
            }
            // Fallback to UserDefaults for backward compatibility
            return userDefaults.string(forKey: ollamaCloudAPIKeyKey)
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
    
    var googleAPIKey: String? {
        get {
            // Load from Config.plist (same way as other services do it)
            if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
               let plist = NSDictionary(contentsOfFile: path),
               let key = plist["GoogleAPIKey"] as? String, !key.isEmpty {
                return key
            }
            // Fallback to environment variable
            if let envKey = ProcessInfo.processInfo.environment["GoogleAPIKey"], !envKey.isEmpty {
                return envKey
            }
            return nil
        }
    }
    
    private init() {}
    
    func toggleAI() {
        isAIEnabled.toggle()
    }
}
