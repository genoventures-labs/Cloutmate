//
//  ConversationCompressionService.swift
//  Cloutmate
//
//  Summarizes long conversations so Aurora can operate within context limits.
//

import Foundation

struct ConversationCompressionResult {
    let summary: String?
    let retainedMessages: [AIMessage]
}

@MainActor
final class ConversationCompressionService {
    static let shared = ConversationCompressionService()

    private struct CacheEntry {
        let compressedCount: Int
        let lastMessageID: UUID?
        let summary: String
        let generatedAt: Date
    }

    private var cache: [UUID: CacheEntry] = [:]
    private let threshold = 40
    private let minimumCompressCount = 16
    private let retainCount = 12

    private init() {}

    func compress(
        conversationId: UUID?,
        messages: [AIMessage]
    ) async -> ConversationCompressionResult {
        guard let conversationId = conversationId else {
            return ConversationCompressionResult(summary: nil, retainedMessages: messages)
        }

        guard messages.count > threshold else {
            return ConversationCompressionResult(summary: nil, retainedMessages: messages)
        }

        let compressCount = max(0, messages.count - retainCount)
        guard compressCount >= minimumCompressCount else {
            return ConversationCompressionResult(summary: nil, retainedMessages: messages)
        }

        let headMessages = Array(messages.prefix(compressCount))
        let tailMessages = Array(messages.suffix(retainCount))

        if let cached = cache[conversationId],
           cached.compressedCount == compressCount,
           cached.lastMessageID == headMessages.last?.id {
            return ConversationCompressionResult(summary: cached.summary, retainedMessages: tailMessages)
        }

        let transcript = buildTranscript(from: headMessages)
        guard !transcript.isEmpty else {
            return ConversationCompressionResult(summary: nil, retainedMessages: messages)
        }

        let summary = try? await GeminiService.shared.summarizeConversation(transcript: transcript)
        if let summary = summary {
            cache[conversationId] = CacheEntry(
                compressedCount: compressCount,
                lastMessageID: headMessages.last?.id,
                summary: summary,
                generatedAt: Date()
            )
            return ConversationCompressionResult(summary: summary, retainedMessages: tailMessages)
        }

        return ConversationCompressionResult(summary: nil, retainedMessages: messages)
    }

    private func buildTranscript(from messages: [AIMessage]) -> String {
        let trimmed = messages.enumerated().map { index, message -> String in
            let role = (message.role ?? "user") == "assistant" ? "Aurora" : "User"
            let content = message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !content.isEmpty else { return "" }
            return "\(index + 1). \(role): \(content)"
        }
        .filter { !$0.isEmpty }
        let transcript = trimmed.joined(separator: "\n")
        let limit = 4000
        if transcript.count > limit {
            let endIndex = transcript.index(transcript.startIndex, offsetBy: limit)
            return String(transcript[..<endIndex])
        }
        return transcript
    }
}

