//
//  AuroraJournalChatOverlay.swift
//  Cloutmate
//
//  Mini chat overlay for contextual journal reflection with Aurora
//

import SwiftUI
import SwiftData
import CloutmateShared

struct AuroraJournalChatOverlay: View {
    let journal: Journal
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isProcessing = false
    
    struct ChatMessage: Identifiable {
        let id = UUID()
        let text: String
        let isUser: Bool
        let timestamp: Date = Date()
    }
    
    private var suggestedPrompts: [String] {
        [
            "What pattern do you notice here?",
            "How does this relate to last week?",
            "What should I reflect on?",
            "What insights can you share?"
        ]
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            // Initial greeting
                            if messages.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.kosmicPurple)
                                        Text("Aurora")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Text("I'm here to help you reflect on this journal entry. What would you like to explore?")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    
                                    // Suggested prompts
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(suggestedPrompts, id: \.self) { prompt in
                                            Button(action: {
                                                sendMessage(prompt)
                                            }) {
                                                HStack {
                                                    Text(prompt)
                                                        .font(.caption)
                                                    Spacer()
                                                    Image(systemName: "arrow.right.circle.fill")
                                                        .font(.caption)
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(.ultraThinMaterial)
                                                .foregroundColor(.primary)
                                                .cornerRadius(8)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                                .padding()
                            } else {
                                ForEach(messages) { message in
                                    AuroraMessageBubble(message: message)
                                        .id(message.id)
                                }
                                .padding()
                            }
                        }
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input area
                HStack(spacing: 12) {
                    TextField("Ask Aurora...", text: $inputText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            if !inputText.isEmpty {
                                sendMessage(inputText)
                            }
                        }
                    
                    Button(action: {
                        if !inputText.isEmpty {
                            sendMessage(inputText)
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(inputText.isEmpty ? .secondary : .kosmicPurple)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty || isProcessing)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .frame(width: 300, height: 400)
            .background(glassColorSystem.backgroundColor())
            .navigationTitle("Ask Aurora")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func sendMessage(_ text: String) {
        let userMessage = ChatMessage(text: text, isUser: true)
        messages.append(userMessage)
        
        inputText = ""
        isProcessing = true
        
        _Concurrency.Task {
            // Generate response using CoreResponseService
            do {
                let response = try await generateResponse(for: text)
                await MainActor.run {
                    let auroraMessage = ChatMessage(text: response, isUser: false)
                    messages.append(auroraMessage)
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(text: "I'm having trouble processing that right now. Please try again.", isUser: false)
                    messages.append(errorMessage)
                }
            }
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func generateResponse(for prompt: String) async throws -> String {
        // Build context from journal entry
        var context = "Journal Entry Context:\n"
        context += "Title: \(journal.title)\n"
        context += "Content: \(journal.content)\n"
        context += "Mood: \(journal.journalMood.rawValue)\n"
        context += "Type: \(journal.journalEntryType.rawValue)\n"
        context += "Date: \(journal.entryDate.formatted(date: .abbreviated, time: .omitted))\n\n"
        context += "User Question: \(prompt)\n\n"
        context += "Please provide a thoughtful, reflective response that helps the user gain insights from their journal entry."
        
        // Use CoreResponseService to generate response
        let coreService = CoreResponseService.shared
        let response = try await coreService.generateResponse(for: prompt, context: context)
        
        return response
    }
}

struct AuroraMessageBubble: View {
    let message: AuroraJournalChatOverlay.ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.isUser
                            ? LinearGradient(colors: [.kosmicBlue, .kosmicPurple], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.secondary.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(12)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    
    AuroraJournalChatOverlay(
        journal: Journal(title: "Test Entry", content: "This is a test journal entry."),
        isPresented: $isPresented
    )
    .environmentObject(GlassColorSystem())
}

