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
    private var consecutiveFailures = 0
    private let failureThreshold = 2 // Auto-promote after 2 consecutive failures
    
    enum FallbackTier {
        case gemini // Tier 1: Heavy summarization, reasoning, multimodal
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
    
    /// Determines network status based on recent failures
    func getNetworkStatus() -> NetworkStatus {
        if !isNetworkAvailable {
            return .unavailable
        }
        if consecutiveFailures >= failureThreshold {
            return .degraded
        }
        return .available
    }
    
    /// Records a Gemini failure (for auto-promotion logic)
    func recordGeminiFailure() {
        consecutiveFailures += 1
    }
    
    /// Records a Gemini success (reset failure counter)
    func recordGeminiSuccess() {
        consecutiveFailures = 0
    }
    
    /// Determines which tier to use based on document characteristics and network status
    func selectTier(
        documentLength: Int,
        isComplexDocument: Bool,
        userPrompt: String?
    ) -> FallbackTier {
        let networkStatus = getNetworkStatus()
        
        // Auto-promote Apple LLM to Gemini replacement mode when network is down/degraded
        if networkStatus == .unavailable || networkStatus == .degraded {
            if #available(macOS 14.0, *) {
                return .appleLLM // Auto-promote to Tier 2
            }
            return .offline // Fall back to Tier 3 if Apple LLM unavailable
        }
        
        // Normal routing: Prefer Apple LLM for short docs, Gemini for complex
        if !isComplexDocument && documentLength < 5000, #available(macOS 14.0, *) {
            return .appleLLM // Prefer Tier 2 for short docs (faster, private)
        }
        
        return .gemini // Default to Tier 1 for complex docs or when network is good
    }
    
    /// Checks if we should attempt Gemini or skip directly to fallback
    func shouldAttemptGemini() -> Bool {
        let networkStatus = getNetworkStatus()
        // Skip Gemini if network is unavailable or severely degraded
        return networkStatus == .available
    }
}

