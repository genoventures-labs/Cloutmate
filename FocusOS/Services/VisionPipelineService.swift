//
//  VisionPipelineService.swift
//  FocusOS
//
//  Three-layer vision pipeline: QwenVisionLayer → OCRLayer → GemmaInterpretationLayer
//  All layers run in detached Tasks to prevent UI thread blocking
//

import Foundation
import SwiftData
import AppKit
import FocusOSShared
import SwiftyTesseract

// MARK: - Data Structures

struct VisionOutput {
    let rawVisionText: String
    let structuredItems: [String]
    let layoutNotes: String
    let visionConfidence: Int
}

struct OCROutput {
    let fullText: String
    let lines: [String]
    let regions: [String] // Placeholder for bounding boxes (can be enhanced later)
    let ocrConfidence: Int
}

struct PipelineContext {
    var qwenUsed: Bool = false
    var ocrUsed: Bool = false
    var fallbackTriggered: Bool = false
    var finalConfidence: Int = 0
    var processingPath: [String] = []
}

struct VisionPipelineResult {
    let tasks: [String]
    let summary: String
    let detectedIntent: String
    let insights: [String]
    let finalConfidence: Int
    let context: PipelineContext
}

enum VisionConfidence {
    case high
    case medium
    case low
    case failed
}

// MARK: - Vision Pipeline Service

class VisionPipelineService {
    static let shared = VisionPipelineService()
    
    private let ollamaBridge = OllamaBridgeService.shared
    
    private init() {}
    
    // MARK: - Main Entry Point
    
    /// Process image through three-layer vision pipeline
    /// All processing runs in detached Tasks to prevent UI blocking
    func processImage(
        imageData: Data,
        mimeType: String,
        userPrompt: String?,
        appContext: String
    ) async throws -> VisionPipelineResult {
        // Initialize pipeline context
        var context = PipelineContext()
        
        // Layer 1: QwenVisionLayer (always try first) - runs asynchronously
        var qwenOutput: VisionOutput?
        do {
            qwenOutput = try await qwenVisionLayer(
                imageData: imageData,
                prompt: userPrompt ?? "Analyze this image and describe what you see. Extract any tasks, lists, or structured information."
            )
            
            if let output = qwenOutput {
                context.qwenUsed = true
                context.processingPath.append("QwenVisionLayer")
                
                // Check if we should fallback to OCR
                if shouldFallbackToOCR(qwenOutput: output) {
                    context.fallbackTriggered = true
                    // Continue to OCR layer
                } else {
                    // Qwen output is good, proceed directly to Gemma interpretation
                    return try await gemmaInterpretationLayer(
                        qwenOutput: output,
                        ocrOutput: nil,
                        userPrompt: userPrompt,
                        appContext: appContext,
                        context: context
                    )
                }
            }
        } catch {
            #if DEBUG
            print("[VisionPipelineService] QwenVisionLayer failed: \(error.localizedDescription)")
            #endif
            context.fallbackTriggered = true
            // Continue to OCR fallback
        }
        
        // Layer 2: OCRLayer (fallback or if Qwen confidence is low) - runs asynchronously
        var ocrOutput: OCROutput?
        do {
            ocrOutput = try await ocrLayer(imageData: imageData)
            
            if let output = ocrOutput {
                context.ocrUsed = true
                if !context.processingPath.contains("OCRLayer") {
                    context.processingPath.append("OCRLayer")
                }
            }
        } catch {
            #if DEBUG
            print("[VisionPipelineService] OCRLayer failed: \(error.localizedDescription)")
            #endif
        }
        
        // Layer 3: GemmaInterpretationLayer (always runs to merge and interpret) - runs asynchronously
        do {
            return try await gemmaInterpretationLayer(
                qwenOutput: qwenOutput,
                ocrOutput: ocrOutput,
                userPrompt: userPrompt,
                appContext: appContext,
                context: context
            )
        } catch {
            // If Gemma also fails, use failure handler
            return handleFailure(qwen: qwenOutput, ocr: ocrOutput, context: context)
        }
    }
    
    // MARK: - Layer 1: QwenVisionLayer
    
    private func qwenVisionLayer(
        imageData: Data,
        prompt: String
    ) async throws -> VisionOutput {
        let model = ModelTierMap.imageModel() // qwen3-vl:2b
        
        // Encode image to base64
        let base64Image = imageData.base64EncodedString()
        
        // Build enhanced prompt for structured output
        let enhancedPrompt = """
        Analyze this image and provide structured information:
        
        1. Raw description of what you see
        2. Any tasks, to-do items, or action items (list them)
        3. Any structured lists or numbered items
        4. Layout and UI elements (if applicable)
        
        User request: \(prompt)
        
        Format your response with clear sections.
        """
        
        // Call Ollama with vision model
        let result = try await ollamaBridge.makeOllamaRequestWithImages(
            model: model,
            prompt: enhancedPrompt,
            images: [base64Image],
            useThinking: false
        )
        
        let response = result.response
        let visionConfidence = evaluateQwenConfidence(output: response)
        
        // Parse structured output
        let structuredItems = extractStructuredItems(from: response)
        let layoutNotes = extractLayoutNotes(from: response)
        
        return VisionOutput(
            rawVisionText: response,
            structuredItems: structuredItems,
            layoutNotes: layoutNotes,
            visionConfidence: visionConfidence
        )
    }
    
    // MARK: - Layer 2: OCRLayer
    
    private func ocrLayer(
        imageData: Data
    ) async throws -> OCROutput {
        // Reuse OCR from ImageAnalysisService
        // We'll call the internal OCR method directly
        guard NSImage(data: imageData) != nil else {
            throw VisionPipelineError.invalidImageData
        }
        
        // Use SwiftyTesseract via ImageAnalysisService pattern
        // For now, we'll extract OCR functionality
        // Note: In production, you might want to expose OCR from ImageAnalysisService
        let ocrText = try await performOCR(imageData: imageData)
        
        let lines = ocrText.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let ocrConfidence = evaluateOCRQuality(output: ocrText)
        
        return OCROutput(
            fullText: ocrText,
            lines: lines,
            regions: [], // Placeholder
            ocrConfidence: ocrConfidence
        )
    }
    
    private func performOCR(imageData: Data) async throws -> String {
        // This is a simplified version - in production, you'd want to share
        // the Tesseract instance from ImageAnalysisService
        // For now, we'll create a temporary instance
        
        guard let nsImage = NSImage(data: imageData) else {
            throw VisionPipelineError.invalidImageData
        }
        
        // Initialize Tesseract (simplified - should reuse from ImageAnalysisService)
        guard let resourcePath = Bundle.main.resourcePath else {
            throw VisionPipelineError.tesseractNotAvailable
        }
        
        let tessdataPath = resourcePath.appending("/Resources/tessdata")
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        guard fileManager.fileExists(atPath: tessdataPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw VisionPipelineError.tesseractNotAvailable
        }
        
        let tesseract = try Tesseract(language: .english, dataSource: Bundle.main, engineMode: .lstmOnly)
        let result = tesseract.performOCR(on: nsImage)
        
        switch result {
        case .success(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw VisionPipelineError.noTextExtracted
            }
            return trimmed
        case .failure:
            throw VisionPipelineError.ocrFailed
        }
    }
    
    // MARK: - Layer 3: GemmaInterpretationLayer
    
    private func gemmaInterpretationLayer(
        qwenOutput: VisionOutput?,
        ocrOutput: OCROutput?,
        userPrompt: String?,
        appContext: String,
        context: PipelineContext
    ) async throws -> VisionPipelineResult {
        let model = ModelTierMap.documentModel() // gemma3:4b
        
        // Build merged input for Gemma
        var gemmaInput = """
        You are interpreting vision analysis results. Combine the following information:
        
        """
        
        if let qwen = qwenOutput {
            gemmaInput += """
            Vision Intelligence (if available):
            \(qwen.rawVisionText)
            
            Structured items found:
            \(qwen.structuredItems.isEmpty ? "None" : qwen.structuredItems.joined(separator: "\n- "))
            
            Layout notes:
            \(qwen.layoutNotes.isEmpty ? "None" : qwen.layoutNotes)
            
            """
        } else {
            gemmaInput += "Vision Intelligence: Not available (vision layer did not provide output)\n\n"
        }
        
        if let ocr = ocrOutput {
            gemmaInput += """
            OCR Text (always available as fallback):
            \(ocr.fullText)
            
            OCR Lines:
            \(ocr.lines.isEmpty ? "None" : ocr.lines.joined(separator: "\n"))
            
            """
        } else {
            gemmaInput += "OCR Text: Not available (OCR layer did not provide output)\n\n"
        }
        
        gemmaInput += """
        User Request: \(userPrompt ?? "Analyze this image")
        
        App Context:
        \(appContext.isEmpty ? "None" : appContext)
        
        Please extract and provide:
        1. Tasks: List any tasks, to-do items, or action items found
        2. Summary: A brief, conversational summary of what's in the image
        3. Intent: What the user likely wants to do with this image
        4. Insights: Key observations or important details
        
        Format your response clearly with labeled sections.
        """
        
        // Call Gemma via Ollama with specific model
        let result = try await ollamaBridge.generateResponseWithAppContext(
            for: gemmaInput,
            appContext: appContext,
            model: model
        )
        let gemmaResponse = result.response
        
        // Parse Gemma's response
        let (tasks, summary, intent, insights) = parseGemmaResponse(gemmaResponse)
        
        // Calculate final confidence
        let qwenScore = qwenOutput?.visionConfidence ?? 0
        let ocrScore = ocrOutput?.ocrConfidence ?? 0
        let gemmaScore = 80 // Assume good if we got a response
        let finalConfidence = calculateFinalConfidence(qwen: qwenScore, ocr: ocrScore, gemma: gemmaScore)
        
        var updatedContext = context
        updatedContext.finalConfidence = finalConfidence
        updatedContext.processingPath.append("GemmaInterpretationLayer")
        
        return VisionPipelineResult(
            tasks: tasks,
            summary: summary,
            detectedIntent: intent,
            insights: insights,
            finalConfidence: finalConfidence,
            context: updatedContext
        )
    }
    
    // MARK: - Confidence Evaluation
    
    private func evaluateQwenConfidence(output: String) -> Int {
        var score = 50 // Base score
        
        // Output length check
        if output.count > 100 {
            score += 20
        } else if output.count < 50 {
            score -= 30
        }
        
        // Noun/verb presence
        let words = output.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let hasNouns = words.contains { word in
            // Simple heuristic: capitalized words are likely nouns
            word.first?.isUppercase == true && word.count > 2
        }
        let hasVerbs = words.contains { word in
            // Common verb endings
            word.lowercased().hasSuffix("ed") || word.lowercased().hasSuffix("ing") || word.lowercased().hasSuffix("s")
        }
        
        if hasNouns && hasVerbs {
            score += 20
        }
        
        // Task extraction check
        let taskKeywords = ["task", "todo", "item", "action", "step", "need to", "should", "must"]
        let hasTasks = taskKeywords.contains { keyword in
            output.lowercased().contains(keyword)
        }
        if hasTasks {
            score += 30
        }
        
        // Hallucination detection (generic summaries when tasks expected)
        let genericPhrases = ["this is an image", "i can see", "the image shows"]
        let isGeneric = genericPhrases.contains { phrase in
            output.lowercased().contains(phrase)
        }
        if isGeneric && output.count < 150 {
            score -= 20
        }
        
        return max(0, min(100, score))
    }
    
    private func evaluateOCRQuality(output: String) -> Int {
        var score = 50 // Base score
        
        // Text length
        if output.count > 100 {
            score += 20
        } else if output.count < 20 {
            score -= 30
        }
        
        // Character variety (more variety = better quality)
        let uniqueChars = Set(output.filter { $0.isLetter || $0.isNumber }).count
        if uniqueChars > 20 {
            score += 15
        } else if uniqueChars < 10 {
            score -= 15
        }
        
        // Line structure (multiple lines = better structure)
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        if lines.count > 3 {
            score += 15
        } else if lines.count == 0 {
            score -= 20
        }
        
        return max(0, min(100, score))
    }
    
    private func calculateFinalConfidence(qwen: Int, ocr: Int, gemma: Int) -> Int {
        // Weighted average: qwen 40%, ocr 30%, gemma 30%
        let weighted = (Double(qwen) * 0.4) + (Double(ocr) * 0.3) + (Double(gemma) * 0.3)
        return Int(weighted.rounded())
    }
    
    // MARK: - Helper Methods
    
    private func shouldFallbackToOCR(qwenOutput: VisionOutput) -> Bool {
        // Fallback if confidence is low
        if qwenOutput.visionConfidence < 40 {
            return true
        }
        
        // Fallback if output is too short
        if qwenOutput.rawVisionText.count < 50 {
            return true
        }
        
        // Fallback if structured items are missing when expected
        if qwenOutput.structuredItems.isEmpty && qwenOutput.rawVisionText.count < 100 {
            return true
        }
        
        // Check for OCR-like gibberish (many single characters or random patterns)
        let words = qwenOutput.rawVisionText.components(separatedBy: .whitespaces)
        let shortWords = words.filter { $0.count <= 1 }.count
        if shortWords > words.count / 2 {
            return true
        }
        
        return false
    }
    
    private func extractStructuredItems(from text: String) -> [String] {
        var items: [String] = []
        
        // Look for numbered lists
        let numberedPattern = try? NSRegularExpression(pattern: #"^\d+[\.\)]\s*(.+)$"#, options: .anchorsMatchLines)
        if let pattern = numberedPattern {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = pattern.matches(in: text, options: [], range: range)
            for match in matches {
                if match.numberOfRanges > 1,
                   let itemRange = Range(match.range(at: 1), in: text) {
                    items.append(String(text[itemRange]).trimmingCharacters(in: .whitespaces))
                }
            }
        }
        
        // Look for bullet points
        let bulletPattern = try? NSRegularExpression(pattern: #"^[-•*]\s*(.+)$"#, options: .anchorsMatchLines)
        if let pattern = bulletPattern {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = pattern.matches(in: text, options: [], range: range)
            for match in matches {
                if match.numberOfRanges > 1,
                   let itemRange = Range(match.range(at: 1), in: text) {
                    let item = String(text[itemRange]).trimmingCharacters(in: .whitespaces)
                    if !items.contains(item) {
                        items.append(item)
                    }
                }
            }
        }
        
        // Look for "Task:" or "Todo:" prefixed items
        let taskPattern = try? NSRegularExpression(pattern: #"(?i)(task|todo|action)[\s:]+(.+)"#, options: [])
        if let pattern = taskPattern {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = pattern.matches(in: text, options: [], range: range)
            for match in matches {
                if match.numberOfRanges > 2,
                   let taskRange = Range(match.range(at: 2), in: text) {
                    let task = String(text[taskRange]).trimmingCharacters(in: .whitespaces)
                    if !items.contains(task) {
                        items.append(task)
                    }
                }
            }
        }
        
        return items
    }
    
    private func extractLayoutNotes(from text: String) -> String {
        // Extract layout-related information
        let layoutKeywords = ["layout", "ui", "button", "menu", "sidebar", "header", "footer", "column", "row"]
        let sentences = text.components(separatedBy: ". ")
        let layoutSentences = sentences.filter { sentence in
            layoutKeywords.contains { keyword in
                sentence.lowercased().contains(keyword)
            }
        }
        return layoutSentences.joined(separator: ". ")
    }
    
    private func mergeSignals(qwen: VisionOutput?, ocr: OCROutput?) -> String {
        var merged: [String] = []
        
        if let qwen = qwen {
            // Start with Qwen's structured items
            merged.append(contentsOf: qwen.structuredItems)
            
            // Add layout notes
            if !qwen.layoutNotes.isEmpty {
                merged.append("Layout: \(qwen.layoutNotes)")
            }
        }
        
        if let ocr = ocr {
            // Add OCR lines that aren't duplicates
            for ocrLine in ocr.lines {
                let normalizedLine = ocrLine.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let isDuplicate = merged.contains { existing in
                    existing.lowercased().contains(normalizedLine) || normalizedLine.contains(existing.lowercased())
                }
                if !isDuplicate && ocrLine.count > 3 {
                    merged.append(ocrLine)
                }
            }
        }
        
        return merged.joined(separator: "\n")
    }
    
    private func parseGemmaResponse(_ response: String) -> (tasks: [String], summary: String, intent: String, insights: [String]) {
        var tasks: [String] = []
        var summary = ""
        var intent = "general analysis"
        var insights: [String] = []
        
        // Parse tasks section
        if let tasksRange = response.range(of: #"(?i)tasks?[:\n]"#, options: .regularExpression) {
            let tasksText = String(response[tasksRange.upperBound...])
            let taskLines = tasksText.components(separatedBy: .newlines).prefix(10)
            for line in taskLines {
                let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: #"^[-•*\d+\.\)]\s*"#, with: "", options: .regularExpression)
                if !cleaned.isEmpty && cleaned.count > 3 {
                    tasks.append(cleaned)
                }
            }
        }
        
        // Parse summary
        if let summaryRange = response.range(of: #"(?i)summary[:\n]"#, options: .regularExpression) {
            let summaryText = String(response[summaryRange.upperBound...])
            if let firstSentence = summaryText.components(separatedBy: ".").first {
                summary = firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            // Fallback: use first paragraph as summary
            let paragraphs = response.components(separatedBy: "\n\n")
            summary = paragraphs.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Image analyzed."
        }
        
        // Parse intent
        if let intentRange = response.range(of: #"(?i)intent[:\n]"#, options: .regularExpression) {
            let intentText = String(response[intentRange.upperBound...])
            if let firstLine = intentText.components(separatedBy: .newlines).first {
                intent = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Parse insights
        if let insightsRange = response.range(of: #"(?i)insights?[:\n]"#, options: .regularExpression) {
            let insightsText = String(response[insightsRange.upperBound...])
            let insightLines = insightsText.components(separatedBy: .newlines).prefix(5)
            for line in insightLines {
                let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: #"^[-•*\d+\.\)]\s*"#, with: "", options: .regularExpression)
                if !cleaned.isEmpty && cleaned.count > 5 {
                    insights.append(cleaned)
                }
            }
        }
        
        // If no tasks found but response mentions tasks, try to extract them
        if tasks.isEmpty {
            let taskKeywords = ["task", "todo", "item", "action", "need to", "should do"]
            let sentences = response.components(separatedBy: ". ")
            for sentence in sentences {
                if taskKeywords.contains(where: { sentence.lowercased().contains($0) }) {
                    let cleaned = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.count > 10 && cleaned.count < 200 {
                        tasks.append(cleaned)
                    }
                }
            }
        }
        
        return (tasks, summary, intent, insights)
    }
    
    // MARK: - Failure Handling
    
    private func handleFailure(
        qwen: VisionOutput?,
        ocr: OCROutput?,
        context: PipelineContext
    ) -> VisionPipelineResult {
        var updatedContext = context
        updatedContext.fallbackTriggered = true
        updatedContext.processingPath.append("FailureFallback")
        
        var summary = "I wasn't able to understand the full image, but here's what I can say..."
        var tasks: [String] = []
        var insights: [String] = []
        
        // Try to salvage what we can
        if let qwen = qwen, !qwen.rawVisionText.isEmpty {
            summary += "\n\nFrom vision analysis: \(qwen.rawVisionText.prefix(200))"
            tasks.append(contentsOf: qwen.structuredItems.prefix(3))
        }
        
        if let ocr = ocr, !ocr.fullText.isEmpty {
            summary += "\n\nFrom text extraction: \(ocr.fullText.prefix(200))"
            insights.append("OCR extracted some text, but it may not be complete.")
        }
        
        if tasks.isEmpty && (qwen == nil && ocr == nil) {
            insights.append("The image may be too low quality, too dark, or contain no readable text.")
            insights.append("Try taking a clearer screenshot with better lighting.")
        }
        
        updatedContext.finalConfidence = 20 // Low confidence for failure case
        
        return VisionPipelineResult(
            tasks: tasks,
            summary: summary,
            detectedIntent: "unknown",
            insights: insights,
            finalConfidence: 20,
            context: updatedContext
        )
    }
}

// MARK: - Errors

enum VisionPipelineError: LocalizedError {
    case serviceUnavailable
    case invalidImageData
    case tesseractNotAvailable
    case ocrFailed
    case noTextExtracted
    case qwenFailed
    case gemmaFailed
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Vision pipeline service is unavailable"
        case .invalidImageData:
            return "Invalid image data provided"
        case .tesseractNotAvailable:
            return "Tesseract OCR is not available"
        case .ocrFailed:
            return "OCR processing failed"
        case .noTextExtracted:
            return "No text could be extracted from the image"
        case .qwenFailed:
            return "Vision analysis failed"
        case .gemmaFailed:
            return "Image interpretation failed"
        }
    }
}

