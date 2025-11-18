//
//  OllamaManagementService.swift
//  FocusOS
//
//  Service to manage Ollama server lifecycle (start/stop)
//

import Foundation
import AppKit

@MainActor
@Observable
final class OllamaManagementService {
    static let shared = OllamaManagementService()
    
    private var ollamaProcess: Process?
    private var isOllamaRunningCache: Bool = false {
        didSet {
            // This will trigger view updates when the cache changes
        }
    }
    private var lastStatusCheck: Date?
    private let statusCacheTimeout: TimeInterval = 2.0
    
    // Published property for UI binding
    var isOllamaRunningSync: Bool = false
    
    var isOllamaRunning: Bool {
        get async {
            // Check cache first
            if let lastCheck = lastStatusCheck,
               Date().timeIntervalSince(lastCheck) < statusCacheTimeout {
                return isOllamaRunningCache
            }
            
            // Check if Ollama is actually running
            let running = await checkOllamaStatus()
            lastStatusCheck = Date()
            isOllamaRunningCache = running
            
            // Update sync property for UI (on MainActor since class is @MainActor)
            isOllamaRunningSync = running
            
            return running
        }
    }
    
    private init() {
        // Check initial status
        Task {
            _ = await isOllamaRunning
        }
    }
    
    /// Check if Ollama is running by checking the API endpoint
    private func checkOllamaStatus() async -> Bool {
        guard let url = URL(string: "http://localhost:11434/api/tags") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            return false
        }
        
        return false
    }
    
    /// Start Ollama server
    func startOllama() async throws {
        // Check if already running
        if await isOllamaRunning {
            throw OllamaManagementError.alreadyRunning
        }
        
        // Try to find Ollama executable
        let ollamaPath: String?
        
        // Check common locations and macOS app bundle
        var possiblePaths: [String] = [
            "/usr/local/bin/ollama",
            "/opt/homebrew/bin/ollama",
            "/usr/bin/ollama",
        ]
        
        // Check macOS app bundle location
        if let ollamaAppPath = try? FileManager.default.contentsOfDirectory(atPath: "/Applications")
            .first(where: { $0.contains("Ollama") && $0.hasSuffix(".app") }) {
            let resourcesPath = "/Applications/\(ollamaAppPath)/Contents/Resources/ollama"
            if FileManager.default.fileExists(atPath: resourcesPath) {
                possiblePaths.insert(resourcesPath, at: 0)
            }
        }
        
        // Also check if it's in PATH
        if let pathInPath = try? await findOllamaInPath() {
            possiblePaths.insert(pathInPath, at: 0)
        }
        
        ollamaPath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) })
        
        guard let path = ollamaPath else {
            throw OllamaManagementError.ollamaNotFound
        }
        
        // Start Ollama process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["serve"]
        
        // Redirect output to avoid blocking
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        // Set up environment
        process.environment = ProcessInfo.processInfo.environment
        
        do {
            try process.run()
            ollamaProcess = process
            
            // Wait and check if it started successfully
            // Give it more time for initial startup
            var attempts = 0
            let maxAttempts = 12 // 12 attempts * 2 seconds = 24 seconds max
            
            while attempts < maxAttempts {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                if await checkOllamaStatus() {
                    // Success - invalidate cache
                    lastStatusCheck = nil
                    isOllamaRunningCache = true
                    isOllamaRunningSync = true
                    return
                }
                
                attempts += 1
            }
            
            // If we get here, process started but API not responding
            // Check if process is still running
            if process.isRunning {
                throw OllamaManagementError.startTimeout
            } else {
                throw OllamaManagementError.startFailed("Ollama process exited unexpectedly")
            }
        } catch {
            if let processError = error as? OllamaManagementError {
                throw processError
            }
            throw OllamaManagementError.startFailed(error.localizedDescription)
        }
    }
    
    /// Stop Ollama server
    func stopOllama() async throws {
        // First, try to stop our managed process
        if let process = ollamaProcess {
            process.terminate()
            
            // Wait for termination
            let timeout = 5.0
            let startTime = Date()
            while process.isRunning && Date().timeIntervalSince(startTime) < timeout {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            // If still running after timeout, send SIGKILL via kill command
            if process.isRunning {
                let killProcess = Process()
                killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/kill")
                killProcess.arguments = ["-9", "\(process.processIdentifier)"]
                try? killProcess.run()
                killProcess.waitUntilExit()
            }
            
            ollamaProcess = nil
        }
        
        // Also try to kill any existing Ollama processes via pkill
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killProcess.arguments = ["-f", "ollama serve"]
        
        do {
            try killProcess.run()
            killProcess.waitUntilExit()
        } catch {
            // pkill might fail if no process found - that's okay
        }
        
        // Wait a moment and verify it stopped
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Verify it stopped
        if await checkOllamaStatus() {
            throw OllamaManagementError.stopFailed("Ollama is still running")
        }
        
        // Invalidate cache
        lastStatusCheck = nil
        isOllamaRunningCache = false
        isOllamaRunningSync = false
    }
    
    /// Find Ollama executable in PATH
    private func findOllamaInPath() async throws -> String? {
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["ollama"]
        
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        
        try whichProcess.run()
        whichProcess.waitUntilExit()
        
        guard whichProcess.terminationStatus == 0 else {
            return nil
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        
        return path
    }
    
    /// Refresh status cache
    func refreshStatus() async {
        lastStatusCheck = nil
        let status = await isOllamaRunning
        // isOllamaRunning already updates isOllamaRunningSync
    }
}

enum OllamaManagementError: LocalizedError {
    case alreadyRunning
    case ollamaNotFound
    case startFailed(String)
    case startTimeout
    case stopFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Ollama is already running."
        case .ollamaNotFound:
            return """
            Could not find Ollama executable.
            
            Please install Ollama from: https://ollama.ai
            
            After installation, restart FocusOS and try again.
            """
        case .startFailed(let details):
            return "Failed to start Ollama: \(details)"
        case .startTimeout:
            return """
            Ollama started but didn't respond in time.
            
            This might mean:
            - Ollama is already running from another location
            - Ollama needs more time to start
            - There's a port conflict
            
            Try checking manually: Run `ollama serve` in Terminal
            """
        case .stopFailed(let details):
            return "Failed to stop Ollama: \(details)"
        }
    }
}

