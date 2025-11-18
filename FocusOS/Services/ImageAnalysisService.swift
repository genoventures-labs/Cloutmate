//
//  ImageAnalysisService.swift
//  FocusOS
//
//  Dedicated vision pipeline: SwiftyTesseract OCR (primary) + qwen3-vl:235b-instruct (fallback)
//

import Foundation
import SwiftData
import AppKit
import FocusOSShared
import SwiftyTesseract

// MARK: - Image Analysis Errors

enum ImageAnalysisError: LocalizedError {
    case tesseractNotAvailable
    case invalidImageData
    case ocrFailed
    case cloudVisionFailed
    case noTextExtracted
    
    var errorDescription: String? {
        switch self {
        case .tesseractNotAvailable:
            return "Tesseract OCR is not available. Please ensure tessdata files are bundled with the app."
        case .invalidImageData:
            return "Invalid image data provided."
        case .ocrFailed:
            return "OCR processing failed. The image may be too low quality or contain no text."
        case .cloudVisionFailed:
            return "Cloud vision analysis failed. Please check your Ollama Cloud API key."
        case .noTextExtracted:
            return "No text could be extracted from the image."
        }
    }
}

// MARK: - Image Analysis Intent

enum ImageAnalysisIntent {
    case textExtraction  // "extract text", "read this", "OCR this"
    case visualAnalysis   // "describe", "interpret", "what do you see"
    case unclear          // Default: try OCR first, then cloud if needed
}

// MARK: - Image Analysis Service

actor ImageAnalysisService {
    static let shared = ImageAnalysisService()
    
    private let tesseract: Tesseract?
    private let cloudModel = "qwen3-vl:235b-instruct"
    private let hybridBridge = HybridBridgeService.shared
    
    private init() {
        // Initialize Tesseract with English language and LSTM engine mode (fastest)
        // SwiftyTesseract 4.0 API: Tesseract(language:dataSource:engineMode:)
        // tessdata folder must be in Bundle.main as folder reference
        
        // Try to find tessdata in bundle
        // Check both main resource path and Resources folder
        guard let resourcePath = Bundle.main.resourcePath else {
            print("[ImageAnalysisService] Could not find resource path in bundle")
            self.tesseract = nil
            return
        }
        
        let fileManager = FileManager.default
        var tessdataPath: String?
        var isDirectory: ObjCBool = false
        
        // Try main resource path first
        let mainTessdataPath = resourcePath.appending("/tessdata")
        if fileManager.fileExists(atPath: mainTessdataPath, isDirectory: &isDirectory) && isDirectory.boolValue {
            tessdataPath = mainTessdataPath
        } else {
            // Try Resources folder
            let resourcesTessdataPath = resourcePath.appending("/Resources/tessdata")
            isDirectory = false
            if fileManager.fileExists(atPath: resourcesTessdataPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                tessdataPath = resourcesTessdataPath
            } else {
                // Try direct Resources path (if Resources is the resource path)
                let directResourcesPath = resourcePath.appending("/Resources")
                isDirectory = false
                if fileManager.fileExists(atPath: directResourcesPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                    let directTessdataPath = directResourcesPath.appending("/tessdata")
                    isDirectory = false
                    if fileManager.fileExists(atPath: directTessdataPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                        tessdataPath = directTessdataPath
                    }
                }
            }
        }
        
        guard let finalTessdataPath = tessdataPath else {
            print("[ImageAnalysisService] tessdata folder not found in bundle")
            print("[ImageAnalysisService] Checked paths:")
            print("  - \(resourcePath)/tessdata")
            print("  - \(resourcePath)/Resources/tessdata")
            print("[ImageAnalysisService] Make sure tessdata folder is added to project as folder reference (blue folder)")
            print("[ImageAnalysisService] The app will use cloud vision as fallback for image analysis")
            self.tesseract = nil
            return
        }
        
        let tessdataPathToUse = finalTessdataPath
        
        // Check if eng.traineddata exists
        let engDataPath = tessdataPathToUse.appending("/eng.traineddata")
        if !fileManager.fileExists(atPath: engDataPath) {
            print("[ImageAnalysisService] eng.traineddata not found at: \(engDataPath)")
            print("[ImageAnalysisService] Make sure eng.traineddata is in the tessdata folder")
            print("[ImageAnalysisService] The app will use cloud vision as fallback for image analysis")
            self.tesseract = nil
            return
        }
        
        // Set TESSDATA_PREFIX environment variable to help Tesseract find the data
        // This is a workaround for SwiftyTesseract path issues
        setenv("TESSDATA_PREFIX", tessdataPathToUse, 1)
        print("[ImageAnalysisService] Found tessdata at: \(tessdataPathToUse)")
        
        // Try to initialize Tesseract
        do {
            self.tesseract = try Tesseract(
                language: .english,
                dataSource: Bundle.main,
                engineMode: .lstmOnly
            )
            print("[ImageAnalysisService] Tesseract initialized successfully")
        } catch {
            print("[ImageAnalysisService] Failed to initialize Tesseract: \(error.localizedDescription)")
            print("[ImageAnalysisService] Error details: \(error)")
            print("[ImageAnalysisService] Make sure:")
            print("  1. tessdata folder is added to Xcode project as folder reference (blue folder, not yellow group)")
            print("  2. tessdata folder is added to target's 'Copy Bundle Resources' build phase")
            print("  3. eng.traineddata file is inside the tessdata folder")
            print("[ImageAnalysisService] The app will use cloud vision as fallback for image analysis")
            self.tesseract = nil
        }
    }
    
    /// Main entry point for image analysis
    func analyzeImage(
        imageData: Data,
        mimeType: String,
        userPrompt: String?,
        appContext: String,
        payloadContext: AIPayloadContext? = nil,
        conversationMessages: [ConversationMessage]? = nil,
        currentMessageStyle: TypingStyle? = nil,
        userStyleProfile: UserPreferences? = nil,
        confidence: ConfidenceSnapshot? = nil
    ) async throws -> DocumentAnalysisResult {
        // Detect user intent
        let intent = detectIntent(userPrompt: userPrompt)
        
        #if DEBUG
        print("[ImageAnalysisService] Intent detected: \(intent)")
        #endif
        
        switch intent {
        case .textExtraction:
            // Text extraction: Try OCR first, fallback to cloud if needed
            return try await handleTextExtraction(
                imageData: imageData,
                userPrompt: userPrompt,
                appContext: appContext,
                payloadContext: payloadContext,
                conversationMessages: conversationMessages,
                currentMessageStyle: currentMessageStyle,
                userStyleProfile: userStyleProfile,
                confidence: confidence
            )
            
        case .visualAnalysis:
            // Visual analysis: Skip OCR, go directly to cloud vision
            return try await performCloudVisionAnalysis(
                imageData: imageData,
                mimeType: mimeType,
                userPrompt: userPrompt,
                appContext: appContext,
                payloadContext: payloadContext,
                conversationMessages: conversationMessages,
                currentMessageStyle: currentMessageStyle,
                userStyleProfile: userStyleProfile,
                confidence: confidence
            )
            
        case .unclear:
            // Unclear intent: Try OCR first, then cloud if OCR fails or extracts garbage
            return try await handleUnclearIntent(
                imageData: imageData,
                mimeType: mimeType,
                userPrompt: userPrompt,
                appContext: appContext,
                payloadContext: payloadContext,
                conversationMessages: conversationMessages,
                currentMessageStyle: currentMessageStyle,
                userStyleProfile: userStyleProfile,
                confidence: confidence
            )
        }
    }
    
    // MARK: - Intent Detection
    
    private func detectIntent(userPrompt: String?) -> ImageAnalysisIntent {
        guard let prompt = userPrompt?.lowercased() else {
            return .unclear
        }
        
        // Text extraction keywords
        let textKeywords = [
            "extract text", "read this", "ocr this", "read the text",
            "get the text", "text from", "copy text", "what text",
            "read text", "extract the text", "get text from"
        ]
        if textKeywords.contains(where: { prompt.contains($0) }) {
            return .textExtraction
        }
        
        // Visual analysis keywords
        let visualKeywords = [
            "describe", "interpret", "what do you see", "identify",
            "what's in", "analyze this image", "explain this image",
            "what does this show", "tell me about this", "what is this",
            "what are", "describe this", "what can you see"
        ]
        if visualKeywords.contains(where: { prompt.contains($0) }) {
            return .visualAnalysis
        }
        
        return .unclear
    }
    
    // MARK: - OCR Implementation
    
    private func performOCR(imageData: Data) async throws -> String {
        guard let tesseract = tesseract else {
            throw ImageAnalysisError.tesseractNotAvailable
        }
        
        guard let nsImage = NSImage(data: imageData) else {
            throw ImageAnalysisError.invalidImageData
        }
        
        do {
            // SwiftyTesseract API: performOCR returns a Result
            let result = tesseract.performOCR(on: nsImage)
            let recognizedString: String
            switch result {
            case .success(let text):
                recognizedString = text
            case .failure(let error):
                throw ImageAnalysisError.ocrFailed
            }
            
            let trimmed = recognizedString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.isEmpty {
                throw ImageAnalysisError.noTextExtracted
            }
            
            #if DEBUG
            print("[ImageAnalysisService] OCR extracted \(trimmed.count) characters")
            #endif
            
            return trimmed
        } catch {
            #if DEBUG
            print("[ImageAnalysisService] OCR failed: \(error.localizedDescription)")
            #endif
            throw ImageAnalysisError.ocrFailed
        }
    }
    
    // MARK: - Intent Handlers
    
    private func handleTextExtraction(
        imageData: Data,
        userPrompt: String?,
        appContext: String,
        payloadContext: AIPayloadContext?,
        conversationMessages: [ConversationMessage]?,
        currentMessageStyle: TypingStyle?,
        userStyleProfile: UserPreferences?,
        confidence: ConfidenceSnapshot?
    ) async throws -> DocumentAnalysisResult {
        // Try OCR first
        do {
            let extractedText = try await performOCR(imageData: imageData)
            
            // If user provided a prompt, optionally analyze the extracted text with a text model
            if let prompt = userPrompt, !prompt.isEmpty {
                // For text extraction with a prompt, we could send to a text model for analysis
                // For now, just return the extracted text
                return DocumentAnalysisResult(
                    summary: extractedText,
                    truncatedContext: false,
                    sourceModel: .ollama
                )
            }
            
            return DocumentAnalysisResult(
                summary: extractedText,
                truncatedContext: false,
                sourceModel: .ollama
            )
        } catch {
            // OCR failed, fallback to cloud vision
            #if DEBUG
            print("[ImageAnalysisService] OCR failed, falling back to cloud vision")
            #endif
            
            return try await performCloudVisionAnalysis(
                imageData: imageData,
                mimeType: "image/png", // Default mime type
                userPrompt: userPrompt,
                appContext: appContext,
                payloadContext: payloadContext,
                conversationMessages: conversationMessages,
                currentMessageStyle: currentMessageStyle,
                userStyleProfile: userStyleProfile,
                confidence: confidence
            )
        }
    }
    
    private func handleUnclearIntent(
        imageData: Data,
        mimeType: String,
        userPrompt: String?,
        appContext: String,
        payloadContext: AIPayloadContext?,
        conversationMessages: [ConversationMessage]?,
        currentMessageStyle: TypingStyle?,
        userStyleProfile: UserPreferences?,
        confidence: ConfidenceSnapshot?
    ) async throws -> DocumentAnalysisResult {
        // Try OCR first
        do {
            let extractedText = try await performOCR(imageData: imageData)
            
            // Check if extracted text is meaningful (not just garbage)
            // Simple heuristic: if text is very short or mostly special characters, it's probably garbage
            let meaningfulText = extractedText.filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
            let meaningfulRatio = Double(meaningfulText.count) / Double(extractedText.count)
            
            if meaningfulRatio > 0.5 && extractedText.count > 10 {
                // OCR extracted meaningful text
                return DocumentAnalysisResult(
                    summary: extractedText,
                    truncatedContext: false,
                    sourceModel: .ollama
                )
            } else {
                // OCR extracted garbage, fallback to cloud vision
                #if DEBUG
                print("[ImageAnalysisService] OCR extracted low-quality text, falling back to cloud vision")
                #endif
                throw ImageAnalysisError.ocrFailed
            }
        } catch {
            // OCR failed or extracted garbage, fallback to cloud vision
            return try await performCloudVisionAnalysis(
                imageData: imageData,
                mimeType: mimeType,
                userPrompt: userPrompt,
                appContext: appContext,
                payloadContext: payloadContext,
                conversationMessages: conversationMessages,
                currentMessageStyle: currentMessageStyle,
                userStyleProfile: userStyleProfile,
                confidence: confidence
            )
        }
    }
    
    // MARK: - Cloud Vision Analysis
    
    private func performCloudVisionAnalysis(
        imageData: Data,
        mimeType: String,
        userPrompt: String?,
        appContext: String,
        payloadContext: AIPayloadContext?,
        conversationMessages: [ConversationMessage]?,
        currentMessageStyle: TypingStyle?,
        userStyleProfile: UserPreferences?,
        confidence: ConfidenceSnapshot?
    ) async throws -> DocumentAnalysisResult {
        // Get API key
        let apiKey = await MainActor.run {
            AISettings.shared.ollamaCloudAPIKey
        }
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw ImageAnalysisError.cloudVisionFailed
        }
        
        // Build prompt
        let promptText = userPrompt ?? "Analyze this image and describe what you see. Be detailed and conversational."
        
        // Build full prompt with app context
        var fullPrompt = promptText
        if !appContext.isEmpty {
            fullPrompt = "\(appContext)\n\n\(promptText)"
        }
        
        // Encode image to base64
        let base64Image = imageData.base64EncodedString()
        
        // Call HybridBridgeService for cloud vision
        do {
            let response = try await hybridBridge.generateCloudVisionResponse(
                imageData: imageData,
                mimeType: mimeType,
                prompt: fullPrompt,
                appContext: appContext,
                model: cloudModel,
                apiKey: apiKey
            )
            
            return DocumentAnalysisResult(
                summary: response.trimmingCharacters(in: .whitespacesAndNewlines),
                truncatedContext: false,
                sourceModel: .ollama // Using .ollama for consistency
            )
        } catch {
            #if DEBUG
            print("[ImageAnalysisService] Cloud vision failed: \(error.localizedDescription)")
            #endif
            throw ImageAnalysisError.cloudVisionFailed
        }
    }
}

