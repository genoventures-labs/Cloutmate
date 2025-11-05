//
//  AuroraSpotlightViewModel.swift
//  Cloutmate
//
//  View model for Aurora Spotlight quick access
//

import Foundation
import SwiftData
import SwiftUI

@Observable
final class AuroraSpotlightViewModel {
    var inputText = ""
    var messages: [AIMessage] = []
    var isLoading = false
    var errorMessage: String?
    var currentConversation: AIConversation?
    var isExecutionRequest = false
    var executionConfirmation: String?
    
    private let geminiService = GeminiService.shared
    private let aiSettings = AISettings.shared
    private var aiAssistantViewModel: AIAssistantViewModel?
    
    func sendMessage(_ text: String, modelContext: ModelContext) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Check if AI is enabled
        guard aiSettings.isAIEnabled else {
            await MainActor.run {
                errorMessage = "AI features are currently disabled. Please enable them in Settings."
            }
            return
        }
        
        // Initialize AIAssistantViewModel if needed and ensure conversation is set up
        if aiAssistantViewModel == nil {
            await MainActor.run {
                aiAssistantViewModel = AIAssistantViewModel()
                aiAssistantViewModel?.initializeConversation(modelContext: modelContext)
            }
        }
        
        guard let assistantVM = aiAssistantViewModel else { return }
        
        // Ensure conversation is initialized
        if assistantVM.currentConversation == nil {
            await MainActor.run {
                assistantVM.initializeConversation(modelContext: modelContext)
            }
        }
        
        // Store conversation ID before sending
        let conversationId = assistantVM.currentConversation?.id
        
        // Check if this is an execution request by detecting intent first
        var detectedExecution = false
        do {
            // Parse @ mentions and resolve them
            let mentions = MentionParser.parseMentions(from: trimmedText)
            var resolvedLinkedContext = LinkedContext()
            
            for mention in mentions {
                let results = WorkspaceObjectSearchService.shared.search(
                    query: mention.mentionText,
                    modelContext: modelContext,
                    limit: 1
                )
                
                if let firstResult = results.first {
                    resolvedLinkedContext.addLinkedObject(
                        type: firstResult.type,
                        id: firstResult.id,
                        mentionText: mention.fullText,
                        displayName: firstResult.title
                    )
                }
            }
            
            if let intent = try await geminiService.detectExecutionIntent(input: trimmedText, linkedContext: resolvedLinkedContext.isEmpty ? nil : resolvedLinkedContext) {
                detectedExecution = true
                await MainActor.run {
                    isExecutionRequest = true
                }
            }
        } catch {
            // Ignore detection errors
        }
        
        // Use AIAssistantViewModel's sendMessage which handles everything (including user message creation)
        // Note: sendMessage is not async, it starts a Task internally
        await MainActor.run {
            isLoading = true // Set loading state immediately
        }
        
        assistantVM.sendMessage(trimmedText, modelContext: modelContext)
        
        // Poll for updates (since sendMessage starts internal tasks)
        await pollForUpdates(assistantVM: assistantVM, modelContext: modelContext, conversationId: conversationId, isExecution: detectedExecution)
        
        // Input text is already cleared in onSubmit handler for immediate UX feedback
    }
    
    private func pollForUpdates(assistantVM: AIAssistantViewModel, modelContext: ModelContext, conversationId: UUID?, isExecution: Bool) async {
        // Poll until loading is complete AND we have the response
        var attempts = 0
        var lastMessageCount = 0
        var lastUserMessageId: UUID? = nil
        
        // Initial message count - read from ViewModel's messages (MainActor)
        await MainActor.run {
            lastMessageCount = assistantVM.messages.count
            if let lastUserMsg = assistantVM.messages.last(where: { $0.role == "user" }) {
                lastUserMessageId = lastUserMsg.id
            }
        }
        
        while attempts < 200 { // Max 20 seconds (200 * 0.1s)
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Read messages directly from ViewModel (updated immediately on MainActor)
            let currentMessages = await MainActor.run { assistantVM.messages }
            let vmIsLoading = await MainActor.run { assistantVM.isLoading }
            let errorMsg = await MainActor.run { assistantVM.errorMessage }
            
            // Also try reading from persisted conversation as backup
            var persistedMessages: [AIMessage] = []
            if let convId = conversationId {
                let descriptor = FetchDescriptor<AIConversation>(
                    predicate: #Predicate { $0.id == convId }
                )
                if let conversation = try? modelContext.fetch(descriptor).first,
                   let convMessages = conversation.messages {
                    persistedMessages = convMessages
                }
            }
            
            // Use persisted messages if they're more recent, otherwise use ViewModel messages
            let messagesToUse = persistedMessages.count >= currentMessages.count ? persistedMessages : currentMessages
            
            await MainActor.run {
                // Always update messages array to trigger view updates
                self.messages = Array(messagesToUse)
                self.isLoading = vmIsLoading
                self.errorMessage = errorMsg
                
                // Update current conversation reference
                if currentConversation == nil {
                    currentConversation = assistantVM.currentConversation
                }
                
                // If execution request, extract brief confirmation from last assistant message
                if isExecution, let lastMessage = messages.last, 
                   lastMessage.role == "assistant" {
                    // Extract brief confirmation (first line or first sentence)
                    let content = lastMessage.content ?? ""
                    let briefConfirmation = extractBriefConfirmation(from: content)
                    executionConfirmation = briefConfirmation
                }
            }
            
            // Check if we got a new message
            let currentMessageCount = messagesToUse.count
            let gotNewMessage = currentMessageCount > lastMessageCount
            
            // Check if we have an assistant response after the user message
            let hasAssistantResponse = messagesToUse.contains { message in
                if let userMsgId = lastUserMessageId {
                    // Find if there's an assistant message after the user message
                    if let userMsgIndex = messagesToUse.firstIndex(where: { $0.id == userMsgId }),
                       let assistantMsgIndex = messagesToUse.lastIndex(where: { $0.role == "assistant" }),
                       assistantMsgIndex > userMsgIndex {
                        return true
                    }
                }
                // Fallback: check if last message is from assistant
                return messagesToUse.last?.role == "assistant"
            }
            
            // Stop polling when loading completes AND we've received a response
            if !vmIsLoading && hasAssistantResponse {
                // Wait one more cycle to ensure it's fully rendered
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                
                // Final read - try both sources
                let finalViewModelMessages = await MainActor.run { assistantVM.messages }
                var finalPersistedMessages: [AIMessage] = []
                if let convId = conversationId {
                    let descriptor = FetchDescriptor<AIConversation>(
                        predicate: #Predicate { $0.id == convId }
                    )
                    if let conversation = try? modelContext.fetch(descriptor).first,
                       let convMessages = conversation.messages {
                        finalPersistedMessages = convMessages
                    }
                }
                let finalMessages = finalPersistedMessages.count >= finalViewModelMessages.count ? finalPersistedMessages : finalViewModelMessages
                
                await MainActor.run {
                    // Always update messages array
                    self.messages = Array(finalMessages)
                    self.isLoading = false // Explicitly set to false
                    self.errorMessage = assistantVM.errorMessage
                    
                    // Update execution confirmation if needed
                    if isExecution, let lastMessage = messages.last, 
                       lastMessage.role == "assistant" {
                        let content = lastMessage.content ?? ""
                        let briefConfirmation = extractBriefConfirmation(from: content)
                        executionConfirmation = briefConfirmation
                    }
                }
                break
            }
            
            // If loading stopped but no assistant response yet, wait a bit more
            if !vmIsLoading && !hasAssistantResponse && attempts > 5 {
                // Wait a bit more for the response
                if attempts < 50 { // Wait up to 5 more seconds
                    attempts += 1
                    continue
                } else {
                    // Timeout - force stop
                    await MainActor.run {
                        isLoading = false
                    }
                    break
                }
            }
            
            if gotNewMessage {
                lastMessageCount = currentMessageCount
            }
            
            attempts += 1
        }
        
        // Final update - ensure loading is reset and we have latest messages
        let finalViewModelMessages = await MainActor.run { assistantVM.messages }
        var finalPersistedMessages: [AIMessage] = []
        if let convId = conversationId {
            let descriptor = FetchDescriptor<AIConversation>(
                predicate: #Predicate { $0.id == convId }
            )
            if let conversation = try? modelContext.fetch(descriptor).first,
               let convMessages = conversation.messages {
                finalPersistedMessages = convMessages
            }
        }
        let finalMessages = finalPersistedMessages.count >= finalViewModelMessages.count ? finalPersistedMessages : finalViewModelMessages
        
        await MainActor.run {
            // Always update messages array
            self.messages = Array(finalMessages)
            self.isLoading = false // Always reset to false
            self.errorMessage = assistantVM.errorMessage
            
            if currentConversation == nil {
                currentConversation = assistantVM.currentConversation
            }
            
            // Auto-dismiss execution confirmation after 3 seconds
            if isExecution, executionConfirmation != nil {
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        executionConfirmation = nil
                    }
                }
            }
        }
    }
    
    private func extractBriefConfirmation(from markdown: String) -> String {
        // Remove markdown formatting
        var text = markdown
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "✅", with: "✓")
            .replacingOccurrences(of: "❌", with: "✗")
        
        // Extract first sentence or first line
        if let firstSentence = text.components(separatedBy: "\n").first,
           !firstSentence.isEmpty {
            let sentences = firstSentence.components(separatedBy: ". ")
            if let first = sentences.first, !first.isEmpty {
                return first + (sentences.count > 1 ? "." : "")
            }
        }
        
        // Fallback: truncate to 80 chars
        if text.count > 80 {
            return String(text.prefix(77)) + "..."
        }
        return text
    }
    
    func clearMessages() {
        messages = []
        currentConversation = nil
        executionConfirmation = nil
        isExecutionRequest = false
        aiAssistantViewModel?.clearMessages()
    }
}


