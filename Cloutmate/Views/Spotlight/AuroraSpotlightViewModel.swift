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
    
    private let coreResponseService = CoreResponseService.shared
    private let aiSettings = AISettings.shared
    private var aiAssistantViewModel: AIAssistantViewModel?
    private var pollingTask: _Concurrency.Task<Void, Never>?
    
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
            
            if let intent = try await coreResponseService.detectExecutionIntent(input: trimmedText, linkedContext: resolvedLinkedContext.isEmpty ? nil : resolvedLinkedContext) {
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
        
        // Ensure we're using the same conversation that was loaded
        let currentConvId = await MainActor.run { assistantVM.currentConversation?.id }
        
        // Send the message (this will create user message and trigger AI response)
        await MainActor.run {
            assistantVM.sendMessage(trimmedText, modelContext: modelContext)
            
            // Immediately update Spotlight's messages array with the latest from assistantVM
            // This ensures the user message appears instantly
            self.messages = assistantVM.messages
            self.currentConversation = assistantVM.currentConversation
        }
        
        // Poll for updates (since sendMessage starts internal tasks)
        await pollForUpdates(assistantVM: assistantVM, modelContext: modelContext, conversationId: currentConvId ?? conversationId, isExecution: detectedExecution)
        
        // Input text is already cleared in onSubmit handler for immediate UX feedback
    }
    
    private func pollForUpdates(assistantVM: AIAssistantViewModel, modelContext: ModelContext, conversationId: UUID?, isExecution: Bool) async {
        // Poll until loading is complete AND we have the response
        var attempts = 0
        var lastMessageCount = 0
        var lastUserMessageId: UUID? = nil
        
        // No delay needed - user message is already added synchronously
        // Small delay to allow sendMessage's internal Task to start
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Initial message count - read from ViewModel's messages (MainActor)
        await MainActor.run {
            lastMessageCount = assistantVM.messages.count
            if let lastUserMsg = assistantVM.messages.last(where: { $0.role == "user" }) {
                lastUserMessageId = lastUserMsg.id
            }
        }
        
        print("[AuroraSpotlight] Starting poll - initial count: \(lastMessageCount), user message ID: \(lastUserMessageId?.uuidString ?? "none")")
        
        while attempts < 200 { // Max 20 seconds (200 * 0.1s)
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds (faster polling)
            
            // Read messages directly from ViewModel (updated immediately on MainActor)
            let currentMessages = await MainActor.run(body: { assistantVM.messages })
            let vmIsLoading = await MainActor.run(body: { assistantVM.isLoading })
            let errorMsg = await MainActor.run(body: { assistantVM.errorMessage })
            
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
            let hasAssistantResponse: Bool
            if let userMsgId = lastUserMessageId {
                // Find if there's an assistant message after the user message
                if let userMsgIndex = messagesToUse.firstIndex(where: { $0.id == userMsgId }),
                   let assistantMsgIndex = messagesToUse.lastIndex(where: { $0.role == "assistant" }),
                   assistantMsgIndex > userMsgIndex {
                    hasAssistantResponse = true
                } else {
                    hasAssistantResponse = false
                }
            } else {
                // Fallback: check if last message is from assistant
                hasAssistantResponse = messagesToUse.last?.role == "assistant"
            }
            
            // Debug logging
            if attempts % 10 == 0 { // Log every second
                print("[AuroraSpotlight] Poll attempt \(attempts): messages=\(currentMessageCount), loading=\(vmIsLoading), hasResponse=\(hasAssistantResponse), error=\(errorMsg ?? "none")")
            }
            
            // Stop polling when loading completes AND we've received a response
            if !vmIsLoading && hasAssistantResponse {
                print("[AuroraSpotlight] Response received, stopping poll")
                // Wait one more cycle to ensure it's fully rendered
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                
                // Final read - try both sources
                let finalViewModelMessages = await MainActor.run(body: { assistantVM.messages })
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
                    print("[AuroraSpotlight] Poll timeout - no response received")
                    await MainActor.run {
                        isLoading = false
                        if errorMsg == nil {
                            errorMessage = "No response received. Please try again."
                        }
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
        let finalViewModelMessages = await MainActor.run(body: { assistantVM.messages })
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
    
    func loadCurrentConversation(modelContext: ModelContext) async {
        // Initialize AIAssistantViewModel if needed
        if aiAssistantViewModel == nil {
            await MainActor.run {
                aiAssistantViewModel = AIAssistantViewModel()
            }
        }
        
        guard let assistantVM = aiAssistantViewModel else { return }
        
        // Try to load the most recent conversation first
        await MainActor.run {
            var descriptor = FetchDescriptor<AIConversation>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            
            if let mostRecentConversation = try? modelContext.fetch(descriptor).first {
                // Check if conversation is recent (within 5 minutes)
                let shouldUseExistingConversation: Bool
                
                if let messages = mostRecentConversation.messages, !messages.isEmpty {
                    // Check the timestamp of the last message
                    let lastMessage = messages.max(by: { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) })
                    if let lastTimestamp = lastMessage?.timestamp {
                        let timeSinceLastMessage = Date().timeIntervalSince(lastTimestamp)
                        // Use existing conversation if last message was within 5 minutes
                        shouldUseExistingConversation = timeSinceLastMessage <= 300 // 5 minutes = 300 seconds
                    } else {
                        // No timestamp, check conversation creation time
                        let createdAt = mostRecentConversation.createdAt ?? Date.distantPast
                        let timeSinceCreation = Date().timeIntervalSince(createdAt)
                        shouldUseExistingConversation = timeSinceCreation <= 300
                    }
                } else {
                    // No messages, check conversation creation time
                    let createdAt = mostRecentConversation.createdAt ?? Date.distantPast
                    let timeSinceCreation = Date().timeIntervalSince(createdAt)
                    shouldUseExistingConversation = timeSinceCreation <= 300
                }
                
                if shouldUseExistingConversation {
                    // Use the most recent conversation
                    assistantVM.currentConversation = mostRecentConversation
                    assistantVM.selectedConversation = mostRecentConversation
                    
                    // Load messages from this conversation
                    if let convMessages = mostRecentConversation.messages {
                        assistantVM.messages = convMessages
                        self.messages = Array(convMessages)
                        self.currentConversation = mostRecentConversation
                    }
                } else {
                    // Last conversation is older than 5 minutes, create a new one
                    assistantVM.initializeConversation(modelContext: modelContext)
                    self.messages = assistantVM.messages
                    self.currentConversation = assistantVM.currentConversation
                }
            } else {
                // No existing conversation, create a new one
                assistantVM.initializeConversation(modelContext: modelContext)
                self.messages = assistantVM.messages
                self.currentConversation = assistantVM.currentConversation
            }
            
            // Restart polling with the new conversation
            self.startContinuousPolling(modelContext: modelContext)
        }
    }
    
    func startContinuousPolling(modelContext: ModelContext) {
        // Stop any existing polling
        pollingTask?.cancel()
        
        // Start continuous polling to check for new messages
        pollingTask = _Concurrency.Task {
            while !_Concurrency.Task.isCancelled {
                try? await _Concurrency.Task.sleep(nanoseconds: 200_000_000) // Poll every 0.2 seconds (faster updates)
                
                guard let assistantVM = await MainActor.run(body: { self.aiAssistantViewModel }) else { continue }
                
                let conversationId = await MainActor.run(body: { self.currentConversation?.id })
                
                // Check for new messages
                let currentViewModelMessages = await MainActor.run(body: { assistantVM.messages })
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
                
                // Use the most complete set of messages
                let messagesToUse = persistedMessages.count >= currentViewModelMessages.count ? persistedMessages : currentViewModelMessages
                
                await MainActor.run {
                    // Always update messages to ensure UI reflects latest state
                    // Compare by ID to avoid unnecessary updates
                    let currentIds = Set(self.messages.map { $0.id })
                    let newIds = Set(messagesToUse.map { $0.id })
                    
                    if currentIds != newIds {
                        self.messages = Array(messagesToUse)
                    }
                    
                    // Always update loading state and conversation
                    self.isLoading = assistantVM.isLoading
                    self.currentConversation = assistantVM.currentConversation ?? self.currentConversation
                }
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}


