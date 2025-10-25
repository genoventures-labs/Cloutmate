//
//  ComposerWindow.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ComposerWindow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var caption = ""
    @State private var selectedPlatforms: Set<Platform> = []
    @State private var scheduledDate: Date?
    @State private var tags: [String] = []
    @State private var isScheduled = false
    @State private var isPublishing = false
    @State private var mediaURLs: [URL] = []
    @State private var showingMediaPicker = false
    @State private var validationError: String?
    
    var body: some View {
        Form {
            // Caption
            Section("Caption") {
                TextEditor(text: $caption)
                    .frame(minHeight: 150)
                
                Text("\(caption.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Platform selection
            Section("Platforms") {
                ForEach(Platform.allCases, id: \.self) { platform in
                    Toggle(platform.displayName, isOn: Binding(
                        get: { selectedPlatforms.contains(platform) },
                        set: { isOn in
                            if isOn {
                                selectedPlatforms.insert(platform)
                            } else {
                                selectedPlatforms.remove(platform)
                            }
                        }
                    ))
                }
            }
            
            // Schedule
            Section("Schedule") {
                Toggle("Schedule for later", isOn: $isScheduled)
                
                if isScheduled {
                    DatePicker("Date & Time", selection: Binding(
                        get: { scheduledDate ?? Date() },
                        set: { scheduledDate = $0 }
                    ))
                }
            }
            
            // Media Attachments
            Section("Media Attachments") {
                if !mediaURLs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(mediaURLs, id: \.self) { url in
                                MediaPreviewView(url: url, onRemove: {
                                    mediaURLs.removeAll { $0 == url }
                                })
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Button(action: {
                    showingMediaPicker = true
                }) {
                    Label("Add Media", systemImage: "photo.badge.plus")
                }
                .fileImporter(
                    isPresented: $showingMediaPicker,
                    allowedContentTypes: [.image, .movie],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        mediaURLs.append(contentsOf: urls)
                    case .failure(let error):
                        validationError = "Failed to add media: \(error.localizedDescription)"
                    }
                }
            }
            
            // Tags
            Section("Tags") {
                TagsView(tags: $tags)
            }
            
            // Error display
            if let error = validationError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            // Actions
            Section {
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(isScheduled ? "Schedule" : "Publish Now") {
                        if validateInput() {
                            savePost()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPublishing)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 600, height: 700)
        .padding()
    }
    
    private func validateInput() -> Bool {
        validationError = nil
        
        if caption.isEmpty {
            validationError = "Caption cannot be empty"
            return false
        }
        
        if selectedPlatforms.isEmpty {
            validationError = "Please select at least one platform"
            return false
        }
        
        if isScheduled && scheduledDate == nil {
            validationError = "Please select a scheduled date"
            return false
        }
        
        if isScheduled, let scheduledDate = scheduledDate, scheduledDate < Date() {
            validationError = "Scheduled date must be in the future"
            return false
        }
        
        return true
    }
    
    private func savePost() {
        isPublishing = true
        validationError = nil
        
        Task {
            let post = Post(
                caption: caption,
                mediaURLs: mediaURLs.map { $0.path },
                scheduledDate: isScheduled ? scheduledDate : nil,
                platforms: Array(selectedPlatforms).map { $0.rawValue },
                status: isScheduled ? PostStatus.scheduled.rawValue : PostStatus.publishing.rawValue,
                tags: tags
            )
            
            modelContext.insert(post)
            
            if isScheduled {
                // Schedule via XPC
                if let scheduledDate = scheduledDate {
                    XPCService.shared.schedulePost(
                        postID: post.id.uuidString,
                        scheduledDate: scheduledDate,
                        caption: caption,
                        mediaURLs: mediaURLs.map { $0.path },
                        platforms: Array(selectedPlatforms).map { $0.rawValue }
                    )
                }
            } else {
                // Publish immediately
                await PublishingService.shared.publishPost(post)
            }
            
            isPublishing = false
            dismiss()
        }
    }
}

struct MediaPreviewView: View {
    let url: URL
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
    }
}

#Preview {
    ComposerWindow()
        .modelContainer(for: [Post.self])
}

