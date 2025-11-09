//
//  StoryTokenExportService.swift
//  Cloutmate
//
//  Export service for Story Tokens (PDF, Markdown, Visual Cards)
//

import Foundation
import SwiftUI
import PDFKit
import os.log
import UniformTypeIdentifiers
import AppKit
import WebKit

@MainActor
final class StoryTokenExportService {
    static let shared = StoryTokenExportService()
    
    private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "StoryTokenExport")
    
    private init() {}
    
    func export(
        token: StoryToken,
        format: StoryTokenExportSheet.ExportFormat,
        completion: @escaping (Bool) -> Void
    ) async {
        switch format {
        case .markdown:
            await exportMarkdown(token: token, completion: completion)
        case .pdf:
            await exportPDF(token: token, completion: completion)
        case .visualCard:
            await exportVisualCard(token: token, completion: completion)
        }
    }
    
    private func exportMarkdown(
        token: StoryToken,
        completion: @escaping (Bool) -> Void
    ) async {
        let markdown = buildMarkdown(token: token)
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "\(token.title.replacingOccurrences(of: " ", with: "_"))_\(formatDate(token.startDate)).md"
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                do {
                    try markdown.write(to: url, atomically: true, encoding: .utf8)
                    logger.info("Exported StoryToken to Markdown: \(url.path)")
                    completion(true)
                } catch {
                    logger.error("Failed to export Markdown: \(error.localizedDescription)")
                    completion(false)
                }
            } else {
                completion(false)
            }
        } else {
            completion(false)
        }
    }
    
    private func exportPDF(
        token: StoryToken,
        completion: @escaping (Bool) -> Void
    ) async {
        let markdown = buildMarkdown(token: token)
        let html = markdownToHTML(markdown)
        let pdfData = htmlToPDF(html)
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "\(token.title.replacingOccurrences(of: " ", with: "_"))_\(formatDate(token.startDate)).pdf"
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                do {
                    try pdfData.write(to: url)
                    logger.info("Exported StoryToken to PDF: \(url.path)")
                    completion(true)
                } catch {
                    logger.error("Failed to export PDF: \(error.localizedDescription)")
                    completion(false)
                }
            } else {
                completion(false)
            }
        } else {
            completion(false)
        }
    }
    
    private func exportVisualCard(
        token: StoryToken,
        completion: @escaping (Bool) -> Void
    ) async {
        // Generate visual card image
        let cardView = StoryTokenCardView(token: token)
        let image = renderViewToImage(cardView)
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "\(token.title.replacingOccurrences(of: " ", with: "_"))_card.png"
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url, let imageData = image.tiffRepresentation {
                do {
                    let bitmapRep = NSBitmapImageRep(data: imageData)
                    let pngData = bitmapRep?.representation(using: .png, properties: [:])
                    try pngData?.write(to: url)
                    logger.info("Exported StoryToken visual card: \(url.path)")
                    completion(true)
                } catch {
                    logger.error("Failed to export visual card: \(error.localizedDescription)")
                    completion(false)
                }
            } else {
                completion(false)
            }
        } else {
            completion(false)
        }
    }
    
    private func buildMarkdown(token: StoryToken) -> String {
        var markdown = "# \(token.title)\n\n"
        markdown += "**Period:** \(formatDate(token.startDate)) - \(formatDate(token.endDate))\n\n"
        markdown += "## Summary\n\n\(token.summary)\n\n"
        markdown += "## Full Story\n\n\(token.markdown)\n\n"
        
        if !token.themes.isEmpty {
            markdown += "## Themes\n\n"
            for theme in token.themes {
                markdown += "- \(theme)\n"
            }
            markdown += "\n"
        }
        
        if !token.metrics.isEmpty {
            markdown += "## Metrics\n\n"
            for (key, value) in token.metrics {
                markdown += "- **\(key.replacingOccurrences(of: "_", with: " ").capitalized):** \(String(format: "%.2f", value))\n"
            }
            markdown += "\n"
        }
        
        return markdown
    }
    
    private func markdownToHTML(_ markdown: String) -> String {
        // Simple markdown to HTML conversion
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 40px; max-width: 800px; margin: 0 auto; }
                h1 { font-size: 32px; margin-bottom: 16px; }
                h2 { font-size: 24px; margin-top: 32px; margin-bottom: 16px; }
                p { line-height: 1.6; margin-bottom: 16px; }
                ul { margin-bottom: 16px; }
                li { margin-bottom: 8px; }
            </style>
        </head>
        <body>
        """
        
        // Basic markdown parsing
        let lines = markdown.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("# ") {
                html += "<h1>\(line.dropFirst(2))</h1>\n"
            } else if line.hasPrefix("## ") {
                html += "<h2>\(line.dropFirst(3))</h2>\n"
            } else if line.hasPrefix("- ") {
                html += "<li>\(line.dropFirst(2))</li>\n"
            } else if !line.isEmpty {
                html += "<p>\(line)</p>\n"
            }
        }
        
        html += """
        </body>
        </html>
        """
        
        return html
    }
    
    private func htmlToPDF(_ html: String) -> Data {
        let webView = WebView()
        webView.loadHTMLString(html, baseURL: nil)
        
        // Wait for rendering (simplified - in production would use proper async handling)
        Thread.sleep(forTimeInterval: 1.0)
        
        let pdfRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
        var pdfRectVar = pdfRect
        let pdfData = NSMutableData()
        let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!, mediaBox: &pdfRectVar, nil)
        
        webView.layer?.render(in: pdfContext!)
        
        return pdfData as Data
    }
    
    private func renderViewToImage(_ view: some View) -> NSImage {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(x: 0, y: 0, width: 400, height: 600)
        hostingView.layout()
        
        let image = NSImage(size: hostingView.frame.size)
        image.lockFocus()
        hostingView.layer?.render(in: NSGraphicsContext.current!.cgContext)
        image.unlockFocus()
        
        return image
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// Helper view for visual card rendering
struct StoryTokenCardView: View {
    let token: StoryToken
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(token.title)
                .font(.system(size: 24, weight: .bold))
            
            Text(token.summary)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            if !token.themes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Themes")
                        .font(.system(size: 12, weight: .semibold))
                    ForEach(token.themes.prefix(3), id: \.self) { theme in
                        Text(theme)
                            .font(.system(size: 11))
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 400, height: 600)
        .background(Color(.windowBackgroundColor))
    }
}

// Simple WebView wrapper for PDF generation
class WebView: WKWebView {
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

