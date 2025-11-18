//
//  ModelWarmupService.swift
//  FocusOS
//
//  Service to warm up all AI models before Aurora becomes available
//

import Foundation
import SwiftData
import FocusOSShared

@MainActor
@Observable
final class ModelWarmupService {
    static let shared = ModelWarmupService()
    
    private let ollamaBridge = OllamaBridgeService.shared
    private let hybridBridge = HybridBridgeService.shared
    
    // Warmup state
    var isWarmingUp: Bool = false
    var isReady: Bool = false
    var warmupProgress: String = ""
    var readyModels: Set<String> = []
    var failedModels: Set<String> = []
    var totalModels: Int = 0
    var completedModels: Int = 0
    
    // Warmup message from Aurora
    var warmupMessage: String = "Hi! I'm just getting my systems ready. This will only take a moment..."
    
    // UserDefaults keys for caching
    private let readyModelsCacheKey = "com.kosmicapps.focusos.modelWarmup.readyModels"
    private let lastWarmupTimestampKey = "com.kosmicapps.focusos.modelWarmup.lastTimestamp"
    private let warmupCacheTimeout: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private init() {}
    
    // MARK: - Warmup Protocol
    
    /// Starts the warmup protocol for all models
    func startWarmup(modelContext: ModelContext) async {
        guard !isWarmingUp, !isReady else { return }
        
        // Check cache first - skip warmup if recent (< 24 hours)
        if let cachedReadyModels = loadCachedReadyModels(),
           let lastWarmup = UserDefaults.standard.object(forKey: lastWarmupTimestampKey) as? Date,
           Date().timeIntervalSince(lastWarmup) < warmupCacheTimeout {
            print("[ModelWarmupService] Using cached warmup state from \(lastWarmup)")
            readyModels = cachedReadyModels
            isReady = true
            isWarmingUp = false
            warmupMessage = ""
            warmupProgress = ""
            return
        }
        
        isWarmingUp = true
        isReady = false
        readyModels.removeAll()
        failedModels.removeAll()
        completedModels = 0
        warmupMessage = "Hi! I'm just getting my systems ready. This will only take a moment..."
        
        // Get models to warm up in prioritized order based on usage frequency
        let prioritizedModels = [
            "gemma3:1b",           // 1. Casual primary
            "qwen3:1.7b",          // 2. Casual fallback, tasks
            "qwen3-vl:2b",         // 3. Vision primary (QwenVisionLayer)
            "granite3.2:2b",       // 4. Background layer
            "gemma3:4b",           // 5. Documents, GemmaInterpretationLayer
            "gwen2.5-coder:1.5b", // 6. Coding, reasoning
            "granite3.2-vision",   // 7. Image secondary (deprecated, kept for compatibility)
            "deepseek-r1:1.5b"     // 8. Research mode, document fallback
        ]
        
        // Filter to only models that are actually available, preserving priority order
        var modelsToWarmup: [(name: String, isLocal: Bool)] = []
        
        // Check which local models are actually available, in priority order
        // Properly check availability - allow reasonable timeout for Ollama connection check
        let availableLocalModels = await checkAvailableLocalModels(prioritizedModels)
        // Preserve priority order by filtering prioritizedModels in order
        for prioritizedModel in prioritizedModels {
            if availableLocalModels.contains(prioritizedModel) {
                modelsToWarmup.append((name: prioritizedModel, isLocal: true))
            }
        }
        
        // Add cloud model if API key is available and cloud is accessible
        let apiKey = AISettings.shared.ollamaCloudAPIKey
        if let apiKey = apiKey, !apiKey.isEmpty {
            // Check if cloud is accessible and the model exists
            let cloudModels = await checkAvailableCloudModels(apiKey: apiKey)
            if cloudModels.contains("gpt-oss:20b") {
                modelsToWarmup.append((name: "gpt-oss:20b", isLocal: false))
            } else if !cloudModels.isEmpty {
                // If cloud is accessible but the specific model isn't available, log it
                print("[ModelWarmupService] Cloud Ollama accessible but gpt-oss:20b not found in available models")
            } else {
                print("[ModelWarmupService] Cloud Ollama not accessible, skipping cloud model warmup")
            }
        }
        
        totalModels = modelsToWarmup.count
        
        // If no models are available, we still need to attempt warmup on all prioritized models
        // as they may become available or Ollama may be starting up
        if modelsToWarmup.isEmpty {
            print("[ModelWarmupService] No models detected as available, attempting warmup on all prioritized models")
            // Attempt to warmup all prioritized models anyway - they may load on-demand
            for modelName in prioritizedModels {
                modelsToWarmup.append((name: modelName, isLocal: true))
            }
            totalModels = modelsToWarmup.count
        }
        
        // First pass: try to warm up all models with stagger
        var pendingModels: [(name: String, isLocal: Bool)] = []
        
        for (index, model) in modelsToWarmup.enumerated() {
            // Stagger: random 1-3 second delay between warmups (except first)
            if index > 0 {
                let staggerDelay = Double.random(in: 1.0...3.0)
                try? await _Concurrency.Task.sleep(nanoseconds: UInt64(staggerDelay * 1_000_000_000))
            }
            
            completedModels = index
            let displayName = ModelTierMap.displayName(for: model.name)
            warmupProgress = "Waking up \(displayName)..."
            
            do {
                if model.isLocal {
                    // Warm up local model - ensure it's properly warmed
                    try await warmupLocalModel(model.name)
                    readyModels.insert(model.name)
                } else {
                    // Warm up cloud model
                    try await warmupCloudModel(model.name, apiKey: apiKey!)
                    readyModels.insert(model.name)
                }
                completedModels = index + 1
            } catch {
                // Timeout or error - mark as pending for retry
                failedModels.insert(model.name)
                pendingModels.append(model)
                print("[ModelWarmupService] Model \(model.name) timed out or failed: \(error.localizedDescription)")
            }
        }
        
        // Second pass: retry failed models with dynamic 5s interval per model
        // Ensure ALL models are attempted - retry all failed models
        if !pendingModels.isEmpty {
            warmupMessage = "Almost there! Just checking on a couple more things..."
            
            for (index, model) in pendingModels.enumerated() {
                // Dynamic retry interval: wait 5 seconds per failed model before retry
                // This keeps pressure light on Ollama by spacing out retries
                try? await _Concurrency.Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
                let displayName = ModelTierMap.displayName(for: model.name)
                warmupProgress = "Rechecking \(displayName)..."
                
                do {
                    if model.isLocal {
                        try await warmupLocalModel(model.name)
                        readyModels.insert(model.name)
                        failedModels.remove(model.name)
                    } else {
                        try await warmupCloudModel(model.name, apiKey: apiKey!)
                        readyModels.insert(model.name)
                        failedModels.remove(model.name)
                    }
                } catch {
                    // Still failed after retry - log but continue
                    print("[ModelWarmupService] Model \(model.name) still unavailable after retry: \(error.localizedDescription)")
                }
            }
        }
        
        // Warmup complete
        completedModels = totalModels
        isWarmingUp = false
        
        // Mark as ready if we have at least one model ready
        // Even if warmup failed for all models, mark as ready - Aurora can still function
        // and models will be loaded on-demand via OllamaBridge
        isReady = true
        
        if readyModels.isEmpty {
            warmupProgress = ""
            warmupMessage = "Some models aren't available, but I'm ready to help with what I can!"
        } else if readyModels.count == totalModels {
            warmupProgress = "All systems ready!"
            warmupMessage = "Perfect! I'm all set and ready to help you. What would you like to work on?"
        } else {
            let readyCount = readyModels.count
            warmupProgress = "\(readyCount) of \(totalModels) models ready"
            warmupMessage = "I'm ready! Some models aren't available right now, but I can still help you with what I have."
        }
        
        // Cache ready models for next launch
        cacheReadyModels(readyModels)
        
        // Small delay before clearing message
        try? await _Concurrency.Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        if isReady {
            warmupMessage = ""
            warmupProgress = ""
        }
    }
    
    // MARK: - Model Warmup
    
    private func warmupLocalModel(_ model: String) async throws {
        // Model readiness ping: lightweight pre-check using "show" command
        try await pingModelReadiness(model: model)
        
        // Use a simple test prompt with timeout
        let timeout: TimeInterval = 45.0 // 45 seconds timeout per model
        
        try await withThrowingTimeout(seconds: timeout) { [weak self] in
            guard let self = self else { throw WarmupError.unknown }
            try await self.ollamaBridge.ensureModelReady(
                model: model,
                progressHandler: { [weak self] message in
                    await MainActor.run {
                        self?.warmupProgress = message
                    }
                }
            )
        }
    }
    
    /// Lightweight pre-check using "show" command to ensure Ollama's aware of the model
    private func pingModelReadiness(model: String) async throws {
        guard let url = URL(string: "http://localhost:11434/api/show") else {
            throw WarmupError.unknown
        }
        
        struct ShowRequest: Codable {
            let name: String
        }
        
        let requestPayload = ShowRequest(name: model)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0 // Short timeout for ping
        
        do {
            request.httpBody = try JSONEncoder().encode(requestPayload)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                // If show fails, model might not exist, but continue anyway
                print("[ModelWarmupService] Model readiness ping failed for \(model), continuing anyway")
                return
            }
        } catch {
            // Ping failed, but continue - model might still work
            print("[ModelWarmupService] Model readiness ping error for \(model): \(error.localizedDescription), continuing anyway")
        }
    }
    
    private func warmupCloudModel(_ model: String, apiKey: String) async throws {
        // Preload cloud model using empty request to /api/generate (as per Ollama API docs)
        let timeout: TimeInterval = 45.0 // 45 seconds for cloud model preload
        
        try await withThrowingTimeout(seconds: timeout) {
            // Use the same method as local models - preload with empty prompt
            // This loads the model into memory on the cloud server
            guard let url = URL(string: "https://ollama.com/api/generate") else {
                throw WarmupError.unknown
            }
            
            struct GenerateRequest: Codable {
                let model: String
                let prompt: String
                let stream: Bool
            }
            
            let requestPayload = GenerateRequest(model: model, prompt: "", stream: false)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = timeout
            request.httpBody = try JSONEncoder().encode(requestPayload)
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WarmupError.unknown
                }
                
                if httpResponse.statusCode == 401 {
                    throw WarmupError.unknown
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw WarmupError.unknown
                }
            } catch {
                throw WarmupError.unknown
            }
        }
    }
    
    // MARK: - Model Availability Checks
    
    /// Check which local models are actually available in Ollama
    private func checkAvailableLocalModels(_ models: [String]) async -> [String] {
        // Quick check if Ollama is running
        guard await checkOllamaRunning() else {
            print("[ModelWarmupService] Ollama not running, skipping local model checks")
            return []
        }
        
        // Fetch available models from Ollama
        guard let url = URL(string: "http://localhost:11434/api/tags") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            struct TagsResponse: Codable {
                let models: [ModelInfo]?
            }
            
            struct ModelInfo: Codable {
                let name: String
            }
            
            let decoder = JSONDecoder()
            let tagsResponse = try decoder.decode(TagsResponse.self, from: data)
            let availableModelNames = Set(tagsResponse.models?.map { $0.name } ?? [])
            
            // Filter to only models that are actually available
            return models.filter { model in
                // Check if exact match or if model name appears in any available model
                availableModelNames.contains(model) || 
                availableModelNames.contains { $0.contains(model) } ||
                availableModelNames.contains { model.contains($0) }
            }
        } catch {
            print("[ModelWarmupService] Error checking local models: \(error.localizedDescription)")
            // If we can't check, assume all models are available and let warmup try them
            return models
        }
    }
    
    /// Check if Ollama is running
    private func checkOllamaRunning() async -> Bool {
        guard let url = URL(string: "http://localhost:11434/api/tags") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    /// Check available cloud models using Ollama Cloud API
    /// Uses https://ollama.com/api/tags as per API documentation
    private func checkAvailableCloudModels(apiKey: String) async -> [String] {
        guard let url = URL(string: "https://ollama.com/api/tags") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            struct TagsResponse: Codable {
                let models: [ModelInfo]?
            }
            
            struct ModelInfo: Codable {
                let name: String
            }
            
            let decoder = JSONDecoder()
            let tagsResponse = try decoder.decode(TagsResponse.self, from: data)
            return tagsResponse.models?.map { $0.name } ?? []
        } catch {
            print("[ModelWarmupService] Error checking cloud models: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Helper
    
    /// Helper to add timeout to async operations
    private func withThrowingTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout
            group.addTask {
                try await _Concurrency.Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw WarmupError.timeout
            }
            
            // Return first result (either operation or timeout)
            guard let result = try await group.next() else {
                throw WarmupError.unknown
            }
            
            // Cancel other task
            group.cancelAll()
            
            return result
        }
    }
    
    
    // MARK: - Cache Management
    
    /// Load cached ready models from UserDefaults
    private func loadCachedReadyModels() -> Set<String>? {
        guard let data = UserDefaults.standard.data(forKey: readyModelsCacheKey),
              let models = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }
        return Set(models)
    }
    
    /// Cache ready models to UserDefaults with timestamp
    private func cacheReadyModels(_ models: Set<String>) {
        if let data = try? JSONEncoder().encode(Array(models)) {
            UserDefaults.standard.set(data, forKey: readyModelsCacheKey)
            UserDefaults.standard.set(Date(), forKey: lastWarmupTimestampKey)
            print("[ModelWarmupService] Cached \(models.count) ready models")
        }
    }
    
    /// Clear cached warmup state
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: readyModelsCacheKey)
        UserDefaults.standard.removeObject(forKey: lastWarmupTimestampKey)
    }
    
    // MARK: - Status
    
    func checkModelReady(_ model: String) -> Bool {
        return readyModels.contains(model)
    }
    
    /// Ensures specific models are ready before processing
    /// Shows "Getting things ready" message via progress handler if warmup is needed
    /// Non-blocking: proceeds even if some models aren't ready
    func ensureModelsReady(
        models: [String],
        progressHandler: ((String) -> Void)? = nil
    ) async {
        var modelsToWarmup: [(name: String, isLocal: Bool)] = []
        
        // Determine which models need warmup
        for model in models {
            // Check if already ready (from startup warmup or previous check)
            if readyModels.contains(model) {
                continue // Already ready
            }
            
            // Determine if local or cloud
            let isLocal = !model.contains("gpt-oss") && !model.contains("cloud")
            
            // Check if model is actually available
            if isLocal {
                // Check if local model exists
                let available = await checkAvailableLocalModels([model])
                if available.contains(model) {
                    modelsToWarmup.append((name: model, isLocal: true))
                }
            } else {
                // Check if cloud model exists (if API key available)
                let apiKey = AISettings.shared.ollamaCloudAPIKey
                if let apiKey = apiKey, !apiKey.isEmpty {
                    let available = await checkAvailableCloudModels(apiKey: apiKey)
                    if available.contains(model) {
                        modelsToWarmup.append((name: model, isLocal: false))
                    }
                }
            }
        }
        
        // If no models need warmup, we're done
        guard !modelsToWarmup.isEmpty else {
            return
        }
        
        // Show "Getting things ready" message
        await MainActor.run {
            progressHandler?("Getting things ready...")
        }
        
        // Warm up models that need it
        let apiKey = AISettings.shared.ollamaCloudAPIKey
        
        for (index, model) in modelsToWarmup.enumerated() {
            let displayName = ModelTierMap.displayName(for: model.name)
            await MainActor.run {
                progressHandler?("Checking \(displayName)...")
            }
            
            do {
                if model.isLocal {
                    try await warmupLocalModel(model.name)
                    await MainActor.run {
                        readyModels.insert(model.name)
                    }
                } else if let apiKey = apiKey {
                    try await warmupCloudModel(model.name, apiKey: apiKey)
                    await MainActor.run {
                        readyModels.insert(model.name)
                    }
                }
            } catch {
                // Model failed to warmup, but continue - it will be loaded on-demand
                print("[ModelWarmupService] Model \(model.name) warmup failed: \(error.localizedDescription), will try on-demand")
            }
            
            // Small stagger between models
            if index < modelsToWarmup.count - 1 {
                try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        await MainActor.run {
            progressHandler?("Ready!")
        }
        
        // Small delay before clearing message
        try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    func reset() {
        isWarmingUp = false
        isReady = false
        warmupProgress = ""
        warmupMessage = ""
        readyModels.removeAll()
        failedModels.removeAll()
        completedModels = 0
        totalModels = 0
        clearCache()
    }
}

enum WarmupError: LocalizedError {
    case timeout
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Model warmup timed out"
        case .unknown:
            return "Unknown warmup error"
        }
    }
}

