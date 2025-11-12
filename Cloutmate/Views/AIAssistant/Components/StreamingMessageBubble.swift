//
//  StreamingMessageBubble.swift
//  Cloutmate
//
//  Message bubble component with word-by-word or chunk-by-chunk streaming
//

import SwiftUI
import AppKit

struct StreamingMessageBubble: View {
    let message: AIMessage
    let onEdit: ((AIMessage, String) -> Void)?
    let onCopy: ((String) -> Void)?
    let shouldStream: Bool
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @State private var displayedText: String = ""
    @State private var isStreaming: Bool = false
    @State private var streamingTask: Task<Void, Never>?
    
    private let typingService = TypingSimulationService.shared
    
    var isUser: Bool {
        message.role ?? "user" == "user"
    }
    
    var isSystemMessage: Bool {
        message.isSystemMessage
    }
    
    init(
        message: AIMessage,
        onEdit: ((AIMessage, String) -> Void)? = nil,
        onCopy: ((String) -> Void)? = nil,
        shouldStream: Bool = true
    ) {
        self.message = message
        self.onEdit = onEdit
        self.onCopy = onCopy
        self.shouldStream = shouldStream
    }
    
    var body: some View {
        let streamingContent = displayedText.isEmpty ? (message.content ?? "") : displayedText
        let streamingMessage = AIMessage(
            role: message.role ?? "assistant",
            content: streamingContent,
            toolUsed: message.toolUsed,
            isSystemMessage: message.isSystemMessage,
            emotion: message.emotion,
            emotionScore: message.emotionScore,
            emotionIntensity: message.emotionIntensity,
            chartData: message.chartData,
            imageData: message.imageData,
            imageMimeType: message.imageMimeType,
            imageAnalysis: message.imageAnalysis,
            imageFileName: message.imageFileName,
            confidenceScore: message.confidenceScore,
            documentData: message.documentData,
            documentMimeType: message.documentMimeType,
            documentSummary: message.documentSummary,
            documentFileName: message.documentFileName,
            documentTextPreview: message.documentTextPreview,
            documentSourceURL: message.documentSourceURL,
            documentSourceModel: message.documentSourceModel
        )
        
        return MessageBubble(
            message: streamingMessage,
            onEdit: onEdit,
            onCopy: onCopy,
            onResend: { _ in },
            canResend: false
        )
        .onAppear {
            if shouldStream && !isUser && !isStreaming {
                startStreaming()
            } else {
                displayedText = message.content ?? ""
            }
        }
        .onDisappear {
            streamingTask?.cancel()
        }
    }
    
    private func startStreaming() {
        guard let content = message.content, !content.isEmpty else {
            displayedText = message.content ?? ""
            return
        }
        
        isStreaming = true
        
        // Determine if we should stream word-by-word or chunk-by-chunk
        let wordCount = content.split(separator: " ").count
        let shouldChunk = wordCount > 50
        
        streamingTask = Task {
            if shouldChunk {
                await typingService.streamMessageChunked(
                    content,
                    chunkSize: 5,
                    onChunk: { chunk in
                        Task { @MainActor in
                            displayedText = chunk
                        }
                    },
                    onComplete: {
                        Task { @MainActor in
                            displayedText = content
                            isStreaming = false
                        }
                    }
                )
            } else {
                await typingService.streamMessage(
                    content,
                    onWord: { word in
                        Task { @MainActor in
                            displayedText = word
                        }
                    },
                    onComplete: {
                        Task { @MainActor in
                            displayedText = content
                            isStreaming = false
                        }
                    }
                )
            }
        }
    }
}

