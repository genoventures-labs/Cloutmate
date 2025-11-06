//
//  FallbackRoutingService.swift
//  Cloutmate
//
//  Smart routing strategy for document analysis fallback stack
//

import Foundation
import Network

actor FallbackRoutingService {
    static let shared = FallbackRoutingService()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable = true
    private var airplaneModeEnabled = false // User-controlled airplane mode
    private var consecutiveFailures = 0
    private let failureThreshold = 2 // Auto-promote after 2 consecutive failures
    
    enum FallbackTier {
        case ollama // Tier 1: Primary local LLM (Ollama with llama3.1)
        case appleLLM // Tier 2: On-device, private, fast, less capable for deep reasoning
        case offline // Tier 3: Template-based, no LLM dependency
    }
    
    enum NetworkStatus {
        case available
        case unavailable
        case degraded // Rate-limited or slow
    }
    
    private init() {
        startNetworkMonitoring()
        // Initialize airplane mode from UserDefaults
        Task {
            let airplaneMode = UserDefaults.standard.bool(forKey: "com.kosmicapps.cloutmate.airplaneMode")
            await setAirplaneMode(airplaneMode)
        }
    }
    
    /// Starts monitoring network connectivity
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            Task {
                await self.updateNetworkStatus(path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }
    
    /// Updates network availability status (actor-isolated)
    private func updateNetworkStatus(_ available: Bool) {
        isNetworkAvailable = available
    }
    
    /// Sets airplane mode (forces local-only operation)
    func setAirplaneMode(_ enabled: Bool) {
        airplaneModeEnabled = enabled
    }
    
    /// Checks if airplane mode is enabled
    func isAirplaneModeEnabled() -> Bool {
        airplaneModeEnabled
    }
    
    /// Determines network status based on recent failures and airplane mode
    func getNetworkStatus() -> NetworkStatus {
        // Airplane mode forces local-only operation
        if airplaneModeEnabled {
            return .unavailable
        }
        if !isNetworkAvailable {
            return .unavailable
        }
        if consecutiveFailures >= failureThreshold {
            return .degraded
        }
        return .available
    }
    
    /// Records an Ollama failure (for auto-promotion logic)
    func recordOllamaFailure() {
        consecutiveFailures += 1
    }
    
    /// Records an Ollama success (reset failure counter)
    func recordOllamaSuccess() {
        consecutiveFailures = 0
    }
    
    /// Determines which tier to use based on document characteristics and network status
    func selectTier(
        documentLength: Int,
        isComplexDocument: Bool,
        userPrompt: String?
    ) -> FallbackTier {
        let networkStatus = getNetworkStatus()
        
        // Airplane mode: Force local-only (Ollama or Apple LLM)
        if airplaneModeEnabled {
            // Ollama is local, so use it as primary in airplane mode
            return .ollama
        }
        
        // Auto-promote Apple LLM when network is down/degraded
        if networkStatus == .unavailable || networkStatus == .degraded {
            if #available(macOS 14.0, *) {
                return .appleLLM // Auto-promote to Tier 2
            }
            return .offline // Fall back to Tier 3 if Apple LLM unavailable
        }
        
        // Normal routing: Prefer Apple LLM for short docs, Ollama for complex
        if !isComplexDocument && documentLength < 5000, #available(macOS 14.0, *) {
            return .appleLLM // Prefer Tier 2 for short docs (faster, private)
        }
        
        return .ollama // Default to Tier 1 (Ollama) for complex docs
    }
    
    /// Checks if we should attempt Ollama or skip directly to fallback
    func shouldAttemptOllama() -> Bool {
        // Ollama is local, so always attempt unless explicitly disabled
        return true
    }
}

