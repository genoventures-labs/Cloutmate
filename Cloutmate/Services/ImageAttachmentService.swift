//
//  ImageAttachmentService.swift
//  Cloutmate
//
//  Handles image attachment loading, validation, and preparation for Gemini.
//

import AppKit
import Foundation
import UniformTypeIdentifiers
import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif

actor ImageAttachmentService {
    static let shared = ImageAttachmentService()

    struct ImageAttachment: @unchecked Sendable {
        let data: Data
        let mimeType: String
        let fileName: String?
        let preview: NSImage
    }

    enum AttachmentError: LocalizedError {
        case noImageSelected
        case unsupportedFormat
        case unableToReadFile
        case imageTooLarge
        case imageConversionFailed
        case photosPickerUnavailable
        case presentationContextMissing

        var errorDescription: String? {
            switch self {
            case .noImageSelected:
                return "No image was selected."
            case .unsupportedFormat:
                return "This image format isn't supported. Please choose PNG, JPEG, WEBP, HEIC, or HEIF."
            case .unableToReadFile:
                return "The selected file couldn't be read."
            case .imageTooLarge:
                return "The image is still too large after compression (over 20 MB)."
            case .imageConversionFailed:
                return "We couldn't convert the image data."
            case .photosPickerUnavailable:
                return "Photos integration requires macOS 13 or later."
            case .presentationContextMissing:
                return "No active window is available to present the Photos picker."
            }
        }
    }

    private let supportedContentTypes: [UTType] = {
        var types: [UTType] = [.png, .jpeg, .heic, .heif]
        if let webp = UTType(filenameExtension: "webp") {
            types.append(webp)
        }
        return types
    }()

    private let maxInlineSize: Int = 20 * 1024 * 1024 // 20 MB

    func loadFromFilePicker() async throws -> ImageAttachment {
        return try await presentOpenPanel(startingAt: nil, prompt: "Choose Image")
    }

    func loadFromPhotosLibrary() async throws -> ImageAttachment {
        #if canImport(PhotosUI)
        guard #available(macOS 13.0, *) else {
            throw AttachmentError.photosPickerUnavailable
        }
        return try await presentPhotosPicker()
        #else
        throw AttachmentError.photosPickerUnavailable
        #endif
    }

    func loadFromClipboard() async -> ImageAttachment? {
        let clipboardImage = await MainActor.run { NSImage(pasteboard: .general) }
        guard let image = clipboardImage else { return nil }
        return try? validateAndPrepare(image, preferredFileName: nil)
    }

    func validateAndPrepare(_ image: NSImage, preferredFileName: String?) throws -> ImageAttachment {
        guard let normalized = normalize(image) else {
            throw AttachmentError.imageConversionFailed
        }

        var (data, mimeType) = try encodeImage(normalized, compressionQuality: 0.85)

        if data.count > maxInlineSize {
            guard let resized = resizeImage(normalized, maxDimension: 2048) else {
                throw AttachmentError.imageTooLarge
            }

            guard let encoded = try? encodeImage(resized, compressionQuality: 0.75) else {
                throw AttachmentError.imageTooLarge
            }
            data = encoded.0
            mimeType = encoded.1
        }

        guard data.count <= maxInlineSize else {
            throw AttachmentError.imageTooLarge
        }

        return ImageAttachment(
            data: data,
            mimeType: mimeType,
            fileName: preferredFileName,
            preview: normalized
        )
    }

    private func presentOpenPanel(startingAt url: URL?, prompt: String) async throws -> ImageAttachment {
        let selection = try await MainActor.run { () throws -> (NSImage, String?) in
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = supportedContentTypes
            panel.prompt = prompt
            panel.title = prompt
            panel.canDownloadUbiquitousContents = true
            panel.canResolveUbiquitousConflicts = true
            if let url {
                panel.directoryURL = url
            }

            let response = panel.runModal()
            guard response == .OK, let resultURL = panel.url else {
                throw AttachmentError.noImageSelected
            }

            guard let nsImage = NSImage(contentsOf: resultURL) else {
                throw AttachmentError.unableToReadFile
            }

            return (nsImage, resultURL.lastPathComponent)
        }

        return try validateAndPrepare(selection.0, preferredFileName: selection.1)
    }

    private func normalize(_ image: NSImage) -> NSImage? {
        guard image.isValid else { return nil }
        let size = image.size
        let targetRect = NSRect(origin: .zero, size: size)
        guard let representation = image.bestRepresentation(for: targetRect, context: nil, hints: nil) else {
            return image
        }

        let normalized = NSImage(size: size)
        normalized.lockFocus()
        defer { normalized.unlockFocus() }
        representation.draw(in: targetRect)
        return normalized
    }

    private func encodeImage(_ image: NSImage, compressionQuality: CGFloat) throws -> (Data, String) {
        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData) else {
            throw AttachmentError.imageConversionFailed
        }

        // Prefer JPEG unless there's alpha channel; fallback to PNG
        let hasAlpha = rep.hasAlpha

        if hasAlpha,
           let pngData = rep.representation(using: .png, properties: [:]) {
            return (pngData, "image/png")
        }

        let jpegProps: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: compressionQuality
        ]

        if let jpegData = rep.representation(using: .jpeg, properties: jpegProps) {
            return (jpegData, "image/jpeg")
        }

        if let pngData = rep.representation(using: .png, properties: [:]) {
            return (pngData, "image/png")
        }

        throw AttachmentError.imageConversionFailed
    }

    private func resizeImage(_ image: NSImage, maxDimension: CGFloat) -> NSImage? {
        let currentSize = image.size
        guard currentSize.width > 0, currentSize.height > 0 else { return nil }

        let maxCurrent = max(currentSize.width, currentSize.height)
        guard maxCurrent > maxDimension else {
            return image
        }

        let scale = maxDimension / maxCurrent
        let newSize = NSSize(width: currentSize.width * scale, height: currentSize.height * scale)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        defer { newImage.unlockFocus() }
        image.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: currentSize), operation: .copy, fraction: 1.0)
        return newImage
    }

    #if canImport(PhotosUI)
    @available(macOS 13.0, *)
    @MainActor
    private func presentPhotosPicker() async throws -> ImageAttachment {
        guard let presenter = NSApp.keyWindow?.contentViewController ?? NSApp.mainWindow?.contentViewController ?? NSApp.windows.first?.contentViewController else {
            throw AttachmentError.presentationContextMissing
        }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            var hostingController: NSHostingController<PhotosPickerSheet>?

            let sheet = PhotosPickerSheet { result in
                guard !didResume else { return }
                didResume = true

                if let host = hostingController {
                    presenter.dismiss(host)
                }

                switch result {
                case .success(let payload):
                    Task {
                        do {
                            let attachment = try await self.makeAttachment(from: payload)
                            continuation.resume(returning: attachment)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            hostingController = NSHostingController(rootView: sheet)
            presenter.presentAsSheet(hostingController!)
        }
    }

    @available(macOS 13.0, *)
    private func makeAttachment(from payload: PhotosSelectionPayload) throws -> ImageAttachment {
        guard let image = NSImage(data: payload.data) else {
            throw AttachmentError.imageConversionFailed
        }
        let fileExtension = payload.contentType.preferredFilenameExtension ?? "jpg"
        let fileName = "photo.\(fileExtension)"
        return try validateAndPrepare(image, preferredFileName: fileName)
    }
    #endif
}

#if canImport(PhotosUI)
@available(macOS 13.0, *)
private struct PhotosSelectionPayload {
    let data: Data
    let contentType: UTType
}

@available(macOS 13.0, *)
private struct PhotosPickerSheet: View {
    @State private var selection: [PhotosPickerItem] = []
    @State private var isProcessing = false
    @State private var hasCompleted = false
    let onCompletion: (Result<PhotosSelectionPayload, Error>) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Select a photo from your iCloud Photos library.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            PhotosPicker(selection: $selection, maxSelectionCount: 1, matching: .images, photoLibrary: .shared()) {
                Label("Browse Photos", systemImage: "photo.on.rectangle")
                    .font(.title3)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)

            Button("Cancel") {
                hasCompleted = true
                onCompletion(.failure(ImageAttachmentService.AttachmentError.noImageSelected))
            }
            .disabled(isProcessing)
        }
        .padding(24)
        .frame(width: 360)
        .onChange(of: selection) { _, newValue in
            guard let item = newValue.first, !isProcessing else { return }
            isProcessing = true
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        let contentType = item.supportedContentTypes.first ?? .image
                        hasCompleted = true
                        onCompletion(.success(PhotosSelectionPayload(data: data, contentType: contentType)))
                    } else {
                        hasCompleted = true
                        onCompletion(.failure(ImageAttachmentService.AttachmentError.unableToReadFile))
                    }
                } catch {
                    hasCompleted = true
                    onCompletion(.failure(error))
                }
            }
        }
        .onDisappear {
            if !hasCompleted {
                onCompletion(.failure(ImageAttachmentService.AttachmentError.noImageSelected))
            }
        }
    }
}
#endif

