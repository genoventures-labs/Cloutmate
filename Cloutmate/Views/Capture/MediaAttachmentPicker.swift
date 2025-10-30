//
//  MediaAttachmentPicker.swift
//  Cloutmate
//
//  Media attachment component for Quick Capture
//

import SwiftUI
import UniformTypeIdentifiers

struct MediaAttachmentPicker: View {
    @State private var isPresented = false
    @State private var selectedURL: URL?
    let onURLSelected: (URL) -> Void
    
    var body: some View {
        Button(action: { isPresented = true }) {
            HStack {
                Image(systemName: "paperclip")
                Text("Attach")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: [.image, .movie, .audio, .text, .pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedURL = url
                    onURLSelected(url)
                }
            case .failure:
                break
            }
        }
    }
}

