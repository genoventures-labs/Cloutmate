//
//  DocumentAttachmentService.swift
//  Cloutmate
//
//  Handles document loading, validation, and text extraction for Ollama document analysis.
//

import AppKit
import Foundation
import UniformTypeIdentifiers
import PDFKit

actor DocumentAttachmentService {
    static let shared = DocumentAttachmentService()

    struct DocumentAttachment: @unchecked Sendable {
        let originalData: Data?
        let mimeType: String
        let fileName: String
        let extractedText: String
        let textPreview: String
        let characterCount: Int
        let pageCount: Int?
        let sizeInBytes: Int
        let sourceURL: URL?
        let persistOriginalData: Bool
    }

    enum DocumentError: LocalizedError {
        case noDocumentSelected
        case multipleDocumentsNotAllowed
        case unsupportedFormat
        case unableToReadFile
        case conversionFailed
        case textExtractionFailed
        case downloadFailed(String)
        case invalidURL
        case exceedsMaximumSize

        var errorDescription: String? {
            switch self {
            case .noDocumentSelected:
                return "No document was selected."
            case .multipleDocumentsNotAllowed:
                return "Due to Aurora's sanity, we only allow her to process a single file at a time."
            case .unsupportedFormat:
                return "This file type is not supported. Please choose PDF, Markdown, or plain text files."
            case .unableToReadFile:
                return "The selected document could not be read."
            case .conversionFailed:
                return "We could not convert that document into a usable format."
            case .textExtractionFailed:
                return "We could not extract text from that document."
            case .downloadFailed(let reason):
                return "Downloading that document failed: \(reason)"
            case .invalidURL:
                return "That URL does not look valid."
            case .exceedsMaximumSize:
                return "That document is larger than the maximum size we support right now (80 MB)."
            }
        }
    }

    private struct ExtractionResult {
        let text: String
        let pageCount: Int?
    }

    private let supportedContentTypes: [UTType] = {
        var types: Set<UTType> = [.pdf, .plainText]
        if let markdown = UTType(filenameExtension: "md") {
            types.insert(markdown)
        }
        if let markdownText = UTType(filenameExtension: "markdown") {
            types.insert(markdownText)
        }
        if let textBundle = UTType(filenameExtension: "txt") {
            types.insert(textBundle)
        }
        types.insert(.rtf)
        if let utf8Text = UTType(filenameExtension: "utf8") {
            types.insert(utf8Text)
        }
        return Array(types)
    }()

    private let maxPersistSize: Int = 25 * 1024 * 1024 // 25 MB
    private let maxDownloadSize: Int = 80 * 1024 * 1024 // 80 MB hard limit

    // MARK: - Public API

    func loadFromFilePicker() async throws -> DocumentAttachment {
        try await presentOpenPanel()
    }

    func loadFromURL(_ url: URL) async throws -> DocumentAttachment {
        guard url.scheme?.lowercased().hasPrefix("http") == true else {
            throw DocumentError.invalidURL
        }

        let (data, response) = try await fetchRemoteData(from: url)
        if data.count > maxDownloadSize {
            throw DocumentError.exceedsMaximumSize
        }

        let mimeType = response.mimeType ?? mimeTypeForURL(url) ?? "application/octet-stream"
        return try makeAttachment(from: data, mimeType: mimeType, fileName: suggestedFileName(from: url, mimeType: mimeType), sourceURL: url)
    }

    // MARK: - Private helpers

    private func presentOpenPanel() async throws -> DocumentAttachment {
        let result = try await MainActor.run { () throws -> (Data, String, String) in
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = supportedContentTypes
            panel.prompt = "Choose Document"
            panel.title = "Choose Document"
            panel.canDownloadUbiquitousContents = true
            panel.canResolveUbiquitousConflicts = true

            let response = panel.runModal()
            guard response == .OK else {
                throw DocumentError.noDocumentSelected
            }

            if panel.urls.count > 1 {
                showSingleDocumentAlert()
                throw DocumentError.multipleDocumentsNotAllowed
            }

            guard let url = panel.urls.first else {
                throw DocumentError.noDocumentSelected
            }

            guard let data = try? Data(contentsOf: url) else {
                throw DocumentError.unableToReadFile
            }

            let mimeType = mimeTypeForURL(url) ?? "application/octet-stream"

            return (data, mimeType, url.lastPathComponent)
        }

        if result.0.count > maxDownloadSize {
            throw DocumentError.exceedsMaximumSize
        }

        return try makeAttachment(from: result.0, mimeType: result.1, fileName: result.2, sourceURL: nil)
    }

    @MainActor
    private func showSingleDocumentAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "One file at a time"
        alert.informativeText = "Due to Aurora's sanity, we only allow her to process a single file at a time."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func makeAttachment(from data: Data, mimeType: String, fileName: String, sourceURL: URL?) throws -> DocumentAttachment {
        guard let inferredType = inferredUTType(for: fileName, fallbackMimeType: mimeType),
              supportedContentTypes.contains(where: { inferredType.conforms(to: $0) }) else {
            throw DocumentError.unsupportedFormat
        }

        let extraction = try extractText(from: data, mimeType: mimeType, fileName: fileName)
        let cleanedText = extraction.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else {
            throw DocumentError.textExtractionFailed
        }

        let previewLimit = 480
        let preview: String
        if cleanedText.count > previewLimit {
            let index = cleanedText.index(cleanedText.startIndex, offsetBy: previewLimit)
            preview = String(cleanedText[..<index]) + "…"
        } else {
            preview = cleanedText
        }

        let persistOriginal = data.count <= maxPersistSize

        return DocumentAttachment(
            originalData: persistOriginal ? data : nil,
            mimeType: normalizedMimeType(for: mimeType, fileName: fileName, inferredType: inferredType),
            fileName: fileName,
            extractedText: cleanedText,
            textPreview: preview,
            characterCount: cleanedText.count,
            pageCount: extraction.pageCount,
            sizeInBytes: data.count,
            sourceURL: sourceURL,
            persistOriginalData: persistOriginal
        )
    }

    private func extractText(from data: Data, mimeType: String, fileName: String) throws -> ExtractionResult {
        if mimeType.contains("pdf") || fileName.lowercased().hasSuffix(".pdf") {
            guard let pdf = PDFDocument(data: data) else {
                throw DocumentError.conversionFailed
            }
            guard let text = pdf.string else {
                throw DocumentError.textExtractionFailed
            }
            return ExtractionResult(text: sanitize(text), pageCount: pdf.pageCount)
        }

        if mimeType == "text/markdown" || fileName.lowercased().hasSuffix(".md") || fileName.lowercased().hasSuffix(".markdown") {
            guard let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
                throw DocumentError.conversionFailed
            }
            return ExtractionResult(text: sanitize(string), pageCount: nil)
        }

        if mimeType == "text/plain" || mimeType == "text/rtf" || fileName.lowercased().hasSuffix(".txt") {
            if mimeType == "text/rtf" {
                guard let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) else {
                    throw DocumentError.conversionFailed
                }
                return ExtractionResult(text: sanitize(attributed.string), pageCount: nil)
            }

            guard let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) ?? String(data: data, encoding: .ascii) else {
                throw DocumentError.conversionFailed
            }
            return ExtractionResult(text: sanitize(string), pageCount: nil)
        }

        throw DocumentError.unsupportedFormat
    }

    private func sanitize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }

    private func fetchRemoteData(from url: URL) async throws -> (Data, URLResponse) {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 60)
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw DocumentError.downloadFailed(error.localizedDescription)
        }
    }

    nonisolated private func mimeTypeForURL(_ url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else { return nil }
        return type.preferredMIMEType
    }

    private func normalizedMimeType(for mimeType: String, fileName: String, inferredType: UTType) -> String {
        if mimeType == "application/octet-stream" {
            return inferredType.preferredMIMEType ?? mimeType
        }
        if mimeType == "text/x-markdown" {
            return "text/markdown"
        }
        return mimeType
    }

    private func suggestedFileName(from url: URL, mimeType: String) -> String {
        if !url.lastPathComponent.isEmpty {
            return url.lastPathComponent
        }
        if let ext = UTType(mimeType: mimeType)?.preferredFilenameExtension {
            return "document.\(ext)"
        }
        return "document"
    }

    private func inferredUTType(for fileName: String, fallbackMimeType: String) -> UTType? {
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        if !ext.isEmpty, let type = UTType(filenameExtension: ext) {
            return type
        }
        if let type = UTType(mimeType: fallbackMimeType) {
            return type
        }
        return nil
    }
}

