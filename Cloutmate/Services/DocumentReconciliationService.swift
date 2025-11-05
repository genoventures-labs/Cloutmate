//
//  DocumentReconciliationService.swift
//  Cloutmate
//
//  Model Reconciliation: When Gemini comes back online, re-run summaries it missed
//  in the background, then merge or overwrite the local ones
//

import Foundation
import SwiftData
import CloutmateShared

actor DocumentReconciliationService {
    static let shared = DocumentReconciliationService()
    
    private struct PendingReconciliation: Codable {
        let documentId: UUID
        let fileName: String
        let sourceModel: String // Store as String (rawValue)
        let summary: String
        let timestamp: Date
        let descriptorText: String
        let descriptorPreview: String
        let descriptorFileName: String
        let descriptorMimeType: String
        let descriptorSizeInBytes: Int
        let descriptorPageCount: Int?
        let descriptorSourceURL: String?
    }
    
    private var pendingReconciliations: [PendingReconciliation] = []
    private var reconciliationTask: _Concurrency.Task<Void, Never>?
    
    private init() {
        // Start background reconciliation task
        startReconciliationTask()
    }
    
    /// Records a fallback summary for potential reconciliation later
    func recordFallbackSummary(
        documentId: UUID,
        fileName: String,
        sourceModel: GeminiService.SummarySource,
        summary: String,
        descriptor: GeminiService.DocumentDescriptor,
        modelContext: ModelContext
    ) async {
        let pending = PendingReconciliation(
            documentId: documentId,
            fileName: fileName,
            sourceModel: sourceModel.rawValue,
            summary: summary,
            timestamp: Date(),
            descriptorText: descriptor.text,
            descriptorPreview: descriptor.preview,
            descriptorFileName: descriptor.fileName,
            descriptorMimeType: descriptor.mimeType,
            descriptorSizeInBytes: descriptor.sizeInBytes,
            descriptorPageCount: descriptor.pageCount,
            descriptorSourceURL: descriptor.sourceURL
        )
        pendingReconciliations.append(pending)
        
        print("📝 Recorded fallback summary for reconciliation: \(fileName) (source: \(sourceModel.rawValue))")
        
        // Try immediate reconciliation if Gemini is available
        await attemptReconciliation(modelContext: modelContext)
    }
    
    /// Attempts to reconcile pending summaries when Gemini is available
    private func attemptReconciliation(modelContext: ModelContext) async {
        guard !pendingReconciliations.isEmpty else { return }
        
        // Check if Gemini is available by attempting a simple test
        do {
            // Use a simple test prompt through analyzeDocument with minimal content
            let testDescriptor = GeminiService.DocumentDescriptor(
                text: "test",
                preview: "test",
                fileName: "test.txt",
                mimeType: "text/plain",
                sizeInBytes: 4,
                pageCount: nil,
                sourceURL: nil
            )
            let testResult = try await GeminiService.shared.analyzeDocument(
                descriptor: testDescriptor,
                userPrompt: nil,
                appContext: "",
                payloadContext: nil,
                conversationMessages: nil,
                currentMessageStyle: nil,
                userStyleProfile: nil,
                confidence: nil
            )
            guard testResult.sourceModel == .gemini else { return }
            
            // Gemini is available, process pending reconciliations
            print("🔄 Gemini is back online. Starting reconciliation of \(pendingReconciliations.count) summaries...")
            
            let reconciliationsToProcess = pendingReconciliations
            pendingReconciliations.removeAll()
            
            for pending in reconciliationsToProcess {
                await reconcileSummary(pending: pending, modelContext: modelContext)
            }
        } catch {
            // Gemini still unavailable, keep pending reconciliations
            print("⏳ Gemini still unavailable. \(pendingReconciliations.count) summaries pending reconciliation.")
        }
    }
    
    /// Reconciles a single summary by re-running with Gemini
    private func reconcileSummary(pending: PendingReconciliation, modelContext: ModelContext) async {
        do {
            // Reconstruct descriptor
            let descriptor = GeminiService.DocumentDescriptor(
                text: pending.descriptorText,
                preview: pending.descriptorPreview,
                fileName: pending.descriptorFileName,
                mimeType: pending.descriptorMimeType,
                sizeInBytes: pending.descriptorSizeInBytes,
                pageCount: pending.descriptorPageCount,
                sourceURL: pending.descriptorSourceURL
            )
            
            // Re-run analysis with Gemini
            let geminiResult = try await GeminiService.shared.analyzeDocument(
                descriptor: descriptor,
                userPrompt: nil,
                appContext: "", // Minimal context for reconciliation
                payloadContext: nil,
                conversationMessages: nil,
                currentMessageStyle: nil,
                userStyleProfile: nil,
                confidence: nil
            )
            
            guard geminiResult.sourceModel == .gemini else {
                // Reconciliation failed, re-add to pending
                pendingReconciliations.append(pending)
                return
            }
            
            // Find the original message and update it
            await MainActor.run {
                let fetchDescriptor = FetchDescriptor<AIMessage>(
                    predicate: #Predicate { $0.id == pending.documentId }
                )
                
                if let messages = try? modelContext.fetch(fetchDescriptor),
                   let message = messages.first {
                    // Update summary with Gemini's version
                    let upgradedSummary = geminiResult.summary + "\n\n✨ _Summary upgraded with full Gemini analysis._"
                    message.documentSummary = upgradedSummary
                    
                    // Find and update the assistant message that contains the summary
                    let conversationFetch = FetchDescriptor<AIConversation>()
                    if let conversations = try? modelContext.fetch(conversationFetch),
                       let conversation = conversations.first(where: { $0.messages?.contains(where: { $0.id == pending.documentId }) == true }) {
                        if let assistantMessage = conversation.messages?.first(where: { $0.role == "assistant" && $0.content == pending.summary }) {
                            assistantMessage.content = upgradedSummary
                            assistantMessage.documentSourceModel = "Gemini" // Update source model after reconciliation
                        }
                    }
                    
                    do {
                        try modelContext.save()
                        print("✅ Reconciled summary for \(pending.fileName)")
                    } catch {
                        print("❌ Failed to save reconciled summary: \(error)")
                    }
                }
            }
        } catch {
            // Reconciliation failed, re-add to pending
            pendingReconciliations.append(pending)
            print("⚠️ Failed to reconcile \(pending.fileName): \(error.localizedDescription)")
        }
    }
    
    /// Starts background task to periodically check for reconciliation opportunities
    private func startReconciliationTask() {
        reconciliationTask = _Concurrency.Task {
            while !_Concurrency.Task.isCancelled {
                // Wait 5 minutes before checking again
                try? await _Concurrency.Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                
                // Attempt reconciliation if we have pending items
                if !pendingReconciliations.isEmpty {
                    // Note: This requires modelContext, which we'll need to pass or fetch
                    // For now, we'll handle reconciliation on-demand when recordFallbackSummary is called
                }
            }
        }
    }
    
    /// Manually trigger reconciliation (useful for testing or user-initiated refresh)
    func triggerReconciliation(modelContext: ModelContext) async {
        await attemptReconciliation(modelContext: modelContext)
    }
    
    /// Get count of pending reconciliations
    func pendingCount() async -> Int {
        return pendingReconciliations.count
    }
}

