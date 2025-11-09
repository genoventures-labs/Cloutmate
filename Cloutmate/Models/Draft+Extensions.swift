//
//  Draft+Extensions.swift
//  Cloutmate
//
//  Draft metadata helpers and AI-aware behaviors
//

import Foundation

// MARK: - Version History Model

struct DraftVersion: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let title: String
    let caption: String
    let notes: String?
    let tags: [String]
    let metadataTags: [String]
    let wordCount: Int
    let summary: String?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        title: String,
        caption: String,
        notes: String?,
        tags: [String],
        metadataTags: [String],
        wordCount: Int,
        summary: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.caption = caption
        self.notes = notes
        self.tags = tags
        self.metadataTags = metadataTags
        self.wordCount = wordCount
        self.summary = summary
    }
    
    var combinedText: String {
        [caption, notes].compactMap { $0 }.joined(separator: "\n\n")
    }
}

// MARK: - Draft Metadata Helpers

extension Draft {
    private var metadataEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    private var metadataDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    var metadataTags: [String] {
        get {
            guard let tagsData,
                  let decoded = try? metadataDecoder.decode([String].self, from: tagsData) else {
                return []
            }
            return decoded
        }
        set {
            let unique = Array(NSOrderedSet(array: newValue)) as? [String] ?? newValue
            if unique.isEmpty {
                tagsData = nil
            } else {
                tagsData = try? metadataEncoder.encode(unique)
            }
        }
    }
    
    var versionHistory: [DraftVersion] {
        get {
            guard let versionHistoryData,
                  let decoded = try? metadataDecoder.decode([DraftVersion].self, from: versionHistoryData) else {
                return []
            }
            return decoded.sorted { $0.timestamp < $1.timestamp }
        }
        set {
            if newValue.isEmpty {
                versionHistoryData = nil
            } else {
                versionHistoryData = try? metadataEncoder.encode(newValue.sorted { $0.timestamp < $1.timestamp })
            }
        }
    }
    
    @discardableResult
    func appendVersionHistory(summary: String? = nil) -> DraftVersion {
        var history = versionHistory
        let version = DraftVersion(
            title: title.isEmpty ? displayTitle : title,
            caption: caption,
            notes: notes,
            tags: tags,
            metadataTags: metadataTags,
            wordCount: wordCount,
            summary: summary
        )
        history.append(version)
        versionHistory = history
        return version
    }
    
    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return String(trimmedTitle.prefix(120))
        }
        
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCaption.isEmpty {
            let firstLine = trimmedCaption.components(separatedBy: .newlines).first ?? trimmedCaption
            return String(firstLine.prefix(120))
        }
        
        if let notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let firstLine = notes.components(separatedBy: .newlines).first ?? notes
            return String(firstLine.prefix(120))
        }
        
        return "Untitled Draft"
    }
    
    // MARK: - Metrics & Signals
    
    func refreshWordMetrics() {
        wordCount = Draft.calculateWordCount(for: caption, notes: notes, title: title)
        lastEditedAt = Date()
        updatedAt = Date()
    }
    
    func refreshContentSignals() {
        let combinedText = ((title + " " + caption) + " " + (notes ?? "")).lowercased()
        
        let containsHashtag = combinedText.range(of: #"#[a-z0-9_\-]+"#, options: [.regularExpression]) != nil
        let containsLink = combinedText.range(of: #"https?:\/\/\S+"#, options: [.regularExpression]) != nil
        
        var tags = metadataTags.filter { $0 != "Post-type Draft" }
        if containsHashtag || containsLink {
            tags.append("Post-type Draft")
        }
        metadataTags = Array(Set(tags))
    }
    
    func applyAutoTaggingForAIExport(conversationTitle: String?) {
        var tags = metadataTags
        if !tags.contains("AI") {
            tags.append("AI")
        }
        
        if let title = conversationTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            let sanitized = title
                .replacingOccurrences(of: "[^A-Za-z0-9\\s_-]", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
                .lowercased()
            if !sanitized.isEmpty, !tags.contains(sanitized) {
                tags.append(sanitized)
            }
        }
        metadataTags = Array(Set(tags))
    }
    
    func applyEmotionalToneTag(_ tone: String?) {
        var tags = metadataTags.filter { !$0.hasPrefix("Tone:") }
        if let tone, !tone.isEmpty {
            tags.append("Tone: \(tone)")
        }
        metadataTags = Array(Set(tags))
    }
}

