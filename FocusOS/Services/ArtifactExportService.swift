//
//  ArtifactExportService.swift
//  FocusOS
//
//  Artifacts V2 - Export functionality for artifacts
//

import Foundation
import AppKit
import SwiftData
import os.log
import FocusOSShared
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ArtifactExportService {
    static let shared = ArtifactExportService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.FocusOS", category: "ArtifactExport")
    
    private init() {}
    
    // MARK: - PDF Export
    
    /// Export artifact to PDF
    func exportToPDF(_ artifact: Artifact, url: URL) throws {
        let pdfData = try generatePDFData(for: artifact)
        try pdfData.write(to: url)
        logger.info("Exported artifact \(artifact.id.uuidString) to PDF: \(url.path)")
    }
    
    private func generatePDFData(for artifact: Artifact) throws -> Data {
        // Create PDF using PDFKit
        let pdfMetaData: [String: Any] = [
            kCGPDFContextCreator as String: "FocusOS",
            kCGPDFContextAuthor as String: "Aurora",
            kCGPDFContextTitle as String: artifact.title
        ]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
        let pdfData = NSMutableData()
        
        var mediaBox = pageRect
        guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!, mediaBox: &mediaBox, pdfMetaData as CFDictionary) else {
            throw NSError(domain: "ArtifactExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"])
        }
        
        pdfContext.beginPDFPage(nil)
        pdfContext.translateBy(x: 0, y: pageRect.height)
        pdfContext.scaleBy(x: 1.0, y: -1.0)
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.labelColor
        ]
        let titleString = NSAttributedString(string: artifact.title, attributes: titleAttributes)
        let titleRect = CGRect(x: 72, y: 720, width: 468, height: 30)
        titleString.draw(in: titleRect)
        
        // Metadata
        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let metaText = "\(artifact.format.displayName) • \(artifact.artifactState.displayName) • \(formatDate(artifact.createdAt))"
        let metaString = NSAttributedString(string: metaText, attributes: metaAttributes)
        let metaRect = CGRect(x: 72, y: 690, width: 468, height: 20)
        metaString.draw(in: metaRect)
        
        // Content
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        let contentString = NSAttributedString(string: artifact.content, attributes: contentAttributes)
        let contentRect = CGRect(x: 72, y: 50, width: 468, height: 630)
        contentString.draw(in: contentRect)
        
        // Linked entities as footnotes
        if !artifact.linkedEntityIds.isEmpty {
            let footnoteText = "Linked: \(artifact.linkedEntityIds.count) entities"
            let footnoteString = NSAttributedString(string: footnoteText, attributes: metaAttributes)
            let footnoteRect = CGRect(x: 72, y: 30, width: 468, height: 20)
            footnoteString.draw(in: footnoteRect)
        }
        
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        return pdfData as Data
    }
    
    // MARK: - Markdown Export
    
    /// Export artifact to Markdown
    func exportToMarkdown(_ artifact: Artifact) -> String {
        var markdown = ""
        
        // Title
        markdown += "# \(artifact.title)\n\n"
        
        // Metadata
        markdown += "**Format:** \(artifact.format.displayName)  \n"
        markdown += "**Status:** \(artifact.artifactState.displayName)  \n"
        markdown += "**Created:** \(formatDate(artifact.createdAt))  \n"
        if artifact.updatedAt != artifact.createdAt {
            markdown += "**Updated:** \(formatDate(artifact.updatedAt))  \n"
        }
        markdown += "\n"
        
        // Tags
        if !artifact.tags.isEmpty {
            markdown += "**Tags:** \(artifact.tags.joined(separator: ", "))\n\n"
        }
        
        // Content
        markdown += "\(artifact.content)\n\n"
        
        // Linked entities
        if !artifact.linkedEntityIds.isEmpty {
            markdown += "## Linked Entities\n\n"
            for (index, entityId) in artifact.linkedEntityIds.enumerated() {
                if index < artifact.linkedEntityTypes.count {
                    let type = artifact.linkedEntityTypes[index]
                    markdown += "- @\(type): \(entityId.uuidString)\n"
                }
            }
            markdown += "\n"
        }
        
        // ARTE tone snapshot
        if let arteTone = artifact.arteToneSnapshot {
            markdown += "**ARTE Tone:** \(arteTone)\n\n"
        }
        
        // Sentiment summary
        if let sentiment = artifact.sentimentSummary {
            markdown += "**Sentiment:** \(sentiment)\n\n"
        }
        
        // Aurora notes
        if let notes = artifact.auroraNotes {
            markdown += "## Aurora Notes\n\n\(notes)\n\n"
        }
        
        return markdown
    }
    
    // MARK: - Plaintext Export
    
    /// Export artifact to plain text
    func exportToPlaintext(_ artifact: Artifact) -> String {
        var text = ""
        
        text += "\(artifact.title)\n"
        text += String(repeating: "=", count: artifact.title.count) + "\n\n"
        
        text += "Format: \(artifact.format.displayName)\n"
        text += "Status: \(artifact.artifactState.displayName)\n"
        text += "Created: \(formatDate(artifact.createdAt))\n"
        if artifact.updatedAt != artifact.createdAt {
            text += "Updated: \(formatDate(artifact.updatedAt))\n"
        }
        text += "\n"
        
        if !artifact.tags.isEmpty {
            text += "Tags: \(artifact.tags.joined(separator: ", "))\n\n"
        }
        
        text += "\(artifact.content)\n\n"
        
        if !artifact.linkedEntityIds.isEmpty {
            text += "Linked Entities:\n"
            for (index, entityId) in artifact.linkedEntityIds.enumerated() {
                if index < artifact.linkedEntityTypes.count {
                    let type = artifact.linkedEntityTypes[index]
                    text += "  - @\(type): \(entityId.uuidString)\n"
                }
            }
            text += "\n"
        }
        
        if let arteTone = artifact.arteToneSnapshot {
            text += "ARTE Tone: \(arteTone)\n\n"
        }
        
        if let sentiment = artifact.sentimentSummary {
            text += "Sentiment: \(sentiment)\n\n"
        }
        
        if let notes = artifact.auroraNotes {
            text += "Aurora Notes:\n\(notes)\n\n"
        }
        
        return text
    }
    
    // MARK: - Export to Drafts
    
    /// Copy artifact to Drafts tab
    func exportToDrafts(_ artifact: Artifact, modelContext: ModelContext) throws {
        // Create a Draft from artifact
        let draft = Draft(
            title: artifact.title,
            caption: artifact.content,
            mediaURLs: artifact.mediaURLs,
            tags: artifact.tags,
            notes: artifact.sentimentSummary
        )
        
        modelContext.insert(draft)
        try modelContext.save()
        
        logger.info("Exported artifact \(artifact.id.uuidString) to Drafts")
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

