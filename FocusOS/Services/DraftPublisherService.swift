//
//  DraftPublisherService.swift
//  FocusOS
//
//  Handles publishing and exporting Drafts into other FocusOS surfaces.
//

import Foundation
import SwiftData
import PDFKit
import AppKit
import CoreGraphics
import FocusOSShared

@MainActor
final class DraftPublisherService {
    static let shared = DraftPublisherService()
    
    private init() {}
    
    func publish(
        draft: Draft,
        destination: PublishingDestination,
        options: DraftPublishingOptions,
        modelContext: ModelContext
    ) async throws -> DraftPublishingResult {
        switch destination {
        case .notes:
            let note = createNote(from: draft, title: options.notesTitle, tags: options.tags, author: .aurora)
            modelContext.insert(note)
            draft.isPublished = true
            draft.applyEmotionalToneTag("Published")
            try modelContext.save()
            notifyPublished(draft: draft, destination: destination)
            return DraftPublishingResult(successMessage: "Published to Notes")
            
        case .resources:
            let resource = createNote(
                from: draft,
                title: options.notesTitle,
                tags: options.tags,
                author: .aurora,
                resourceType: .reference
            )
            modelContext.insert(resource)
            draft.isPublished = true
            draft.applyEmotionalToneTag("Referenced")
            try modelContext.save()
            notifyPublished(draft: draft, destination: destination)
            return DraftPublishingResult(successMessage: "Saved to Resources")
            
        case .aiAssistant:
            draft.applyAutoTaggingForAIExport(conversationTitle: options.titleOverride ?? draft.title)
            var metadata = draft.metadataTags
            metadata.append("SharedWithAurora")
            draft.metadataTags = metadata
            draft.refreshWordMetrics()
            try modelContext.save()
            NotificationCenter.default.post(name: .openDraftEditor, object: draft.id)
            notifyPublished(draft: draft, destination: destination)
            return DraftPublishingResult(successMessage: "Shared with Aurora")
            
        case .external:
            let url = try exportExternally(draft: draft, options: options)
            var metadata = draft.metadataTags
            metadata.append("Exported::\(url.lastPathComponent)")
            draft.metadataTags = metadata
            if !options.exportOnly {
                draft.isPublished = true
            }
            try modelContext.save()
            if !options.exportOnly {
                notifyPublished(draft: draft, destination: destination)
            }
            return DraftPublishingResult(successMessage: "Exported to \(url.lastPathComponent)")
            
        case .resourcesArchive:
            draft.isArchived = true
            draft.isPublished = true
            draft.refreshWordMetrics()
            try modelContext.save()
            notifyPublished(draft: draft, destination: destination)
            return DraftPublishingResult(successMessage: "Draft archived")
        }
    }
    
    // MARK: - Helpers
    
    private func createNote(
        from draft: Draft,
        title: String,
        tags: [String],
        author: NoteAuthor,
        resourceType: ResourceType = .note
    ) -> Note {
        let markdown = buildMarkdownBody(from: draft)
        let note = Note(
            title: title.isEmpty ? draft.displayTitle : title,
            markdown: markdown,
            tags: tags,
            source: draft.source,
            type: resourceType
        )
        note.author = author
        return note
    }
    
    private func buildMarkdownBody(from draft: Draft) -> String {
        var components: [String] = []
        if let title = draft.title.nonEmpty {
            components.append("# \(title)")
        }
        
        if !draft.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            components.append(draft.caption)
        }
        
        if let notes = draft.notes, !notes.isEmpty {
            components.append("> \(notes)")
        }
        
        let tagLine = draft.tags.isEmpty ? "" : "_Tags: \(draft.tags.map { "#\($0)" }.joined(separator: " "))_"
        if !tagLine.isEmpty {
            components.append(tagLine)
        }
        
        return components.joined(separator: "\n\n")
    }
    
    private func exportExternally(
        draft: Draft,
        options: DraftPublishingOptions
    ) throws -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let trimmedFileName = options.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedFileName.isEmpty ? draft.displayTitle.replacingOccurrences(of: " ", with: "-") : trimmedFileName
        let sanitizedName = baseName.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let exportURL: URL
        
        switch options.externalFormat {
        case .markdown:
            exportURL = downloads.appendingPathComponent(sanitizedName).appendingPathExtension("md")
            let content = buildMarkdownBody(from: draft)
            try content.write(to: exportURL, atomically: true, encoding: .utf8)
            
        case .pdf:
            exportURL = downloads.appendingPathComponent(sanitizedName).appendingPathExtension("pdf")
            let content = buildPDFAttributedString(for: draft, caption: options.generatedCaption)
            let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
            
            let pdfData = NSMutableData()
            let consumer = CGDataConsumer(data: pdfData)!
            var mediaBox = pageRect
            guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                throw DraftPublisherError.pdfCreationFailed
            }
            
            context.beginPDFPage(nil)
            context.translateBy(x: 0, y: pageRect.height)
            context.scaleBy(x: 1.0, y: -1.0)
            
            let textRect = CGRect(x: 72, y: 72, width: pageRect.width - 144, height: pageRect.height - 144)
            let textStorage = NSTextStorage(attributedString: content)
            let layoutManager = NSLayoutManager()
            textStorage.addLayoutManager(layoutManager)
            
            let textContainer = NSTextContainer(size: textRect.size)
            layoutManager.addTextContainer(textContainer)
            
            let glyphRange = layoutManager.glyphRange(for: textContainer)
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: CGPoint(x: textRect.origin.x, y: pageRect.height - textRect.origin.y - textRect.height))
            
            context.endPDFPage()
            context.closePDF()
            
            try pdfData.write(to: exportURL)
        }
        return exportURL
    }
    
    private func buildPDFAttributedString(for draft: Draft, caption: String?) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
            .paragraphStyle: paragraphStyle
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .paragraphStyle: paragraphStyle
        ]
        
        let result = NSMutableAttributedString()
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmedTitle.isEmpty ? draft.displayTitle : trimmedTitle
        result.append(NSAttributedString(string: "\(title)\n\n", attributes: titleAttributes))
        
        if !draft.caption.isEmpty {
            result.append(NSAttributedString(string: "\(draft.caption)\n\n", attributes: bodyAttributes))
        }
        
        if let notes = draft.notes, !notes.isEmpty {
            result.append(NSAttributedString(string: "Notes:\n\(notes)\n\n", attributes: bodyAttributes))
        }
        
        if let caption = caption {
            result.append(NSAttributedString(string: "Suggested caption:\n\(caption)\n\n", attributes: bodyAttributes))
        }
        
        if !draft.tags.isEmpty {
            result.append(NSAttributedString(string: "Tags: \(draft.tags.joined(separator: ", "))", attributes: bodyAttributes))
        }
        
        return result
    }
    
    private func notifyPublished(draft: Draft, destination: PublishingDestination) {
        NotificationCenter.default.post(
            name: .draftPublished,
            object: draft.id,
            userInfo: ["destination": destination.rawValue]
        )
    }
}

// MARK: - Errors

enum DraftPublisherError: LocalizedError {
    case pdfCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .pdfCreationFailed:
            return "Unable to create PDF export."
        }
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

