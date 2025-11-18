//
//  AISettings.swift
//  FocusOS
//
//  AI Settings Management
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AISettings {
    static let shared = AISettings()
    
    @ObservationIgnored private let userDefaults = UserDefaults.standard
    @ObservationIgnored private let aiEnabledKey = "com.kosmicapps.focusos.aiEnabled"
    @ObservationIgnored private let airplaneModeKey = "com.kosmicapps.focusos.airplaneMode"
    @ObservationIgnored private let selectedOllamaModelKey = "com.kosmicapps.focusos.selectedOllamaModel"
    @ObservationIgnored private let useHybridBridgeKey = "com.kosmicapps.focusos.useHybridBridge"
    @ObservationIgnored private let ollamaCloudAPIKeyKey = "com.kosmicapps.focusos.ollamaCloudAPIKey"
    @ObservationIgnored private let preferredCloudModelKey = "com.kosmicapps.focusos.preferredCloudModel"
    @ObservationIgnored private let latencyThresholdKey = "com.kosmicapps.focusos.latencyThreshold"
    
    // Use stored properties that sync with UserDefaults for @Observable to track changes
    var isAIEnabled: Bool {
        didSet {
            userDefaults.set(isAIEnabled, forKey: aiEnabledKey)
        }
    }
    
    var airplaneMode: Bool {
        didSet {
            userDefaults.set(airplaneMode, forKey: airplaneModeKey)
            // Notify FallbackRoutingService when airplane mode changes
            Task {
                await FallbackRoutingService.shared.setAirplaneMode(airplaneMode)
            }
        }
    }
    
    // Model selection is now automatic - users cannot change models manually
    // Models are automatically selected based on task type (image/document vs regular chat)
    @ObservationIgnored
    var selectedOllamaModel: String {
        // Always return default model - actual model selection happens automatically in OllamaBridgeService
        return "gemma3:4b"
    }
    
    var useHybridBridge: Bool {
        didSet {
            userDefaults.set(useHybridBridge, forKey: useHybridBridgeKey)
        }
    }
    
    @ObservationIgnored
    var ollamaCloudAPIKey: String? {
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
    
    var preferredCloudModel: String? {
        didSet {
            if let model = preferredCloudModel {
                userDefaults.set(model, forKey: preferredCloudModelKey)
            } else {
                userDefaults.removeObject(forKey: preferredCloudModelKey)
            }
        }
    }
    
    var latencyThreshold: TimeInterval {
        didSet {
            userDefaults.set(latencyThreshold, forKey: latencyThresholdKey)
        }
    }
    
    @ObservationIgnored
    var googleAPIKey: String? {
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
    
    private init() {
        // Initialize stored properties from UserDefaults
        self.isAIEnabled = userDefaults.bool(forKey: aiEnabledKey)
        
        self.airplaneMode = userDefaults.bool(forKey: airplaneModeKey)
        
        // Default to true if key doesn't exist (new feature, default ON)
        if userDefaults.object(forKey: useHybridBridgeKey) == nil {
            self.useHybridBridge = true
        } else {
            self.useHybridBridge = userDefaults.bool(forKey: useHybridBridgeKey)
        }
        
        self.preferredCloudModel = userDefaults.string(forKey: preferredCloudModelKey)
        
        let threshold = userDefaults.double(forKey: latencyThresholdKey)
        self.latencyThreshold = threshold > 0 ? threshold : 6.0 // Default 6 seconds
    }
    
    func toggleAI() {
        isAIEnabled.toggle()
    }
}
