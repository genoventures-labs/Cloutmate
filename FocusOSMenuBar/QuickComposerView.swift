//
//  QuickComposerView.swift
//  FocusOSMenuBar
//
//  Quick Draft Composer - Create drafts and artifacts
//

import SwiftUI
import SwiftData
import FocusOSShared

struct QuickComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @FocusState private var isFocused: Bool
    
    @State private var caption = ""
    @State private var isSaving = false
    @State private var validationError: String?
    @State private var showSuccessMessage = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Caption input
                VStack(alignment: .leading, spacing: 10) {
                    Text("Content")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(glassColorSystem.textSecondary())
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(glassColorSystem.cardColor())
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                        
                        if caption.isEmpty {
                            Text("What's on your mind?")
                                .font(.system(size: 14))
                                .foregroundColor(glassColorSystem.textSecondary().opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                        
                        TextEditor(text: $caption)
                            .font(.system(size: 14))
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .focused($isFocused)
                            .frame(minHeight: 120)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isFocused ? glassColorSystem.buttonColor(for: .primary) : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .animation(Animation.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Error display
                if let error = validationError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(glassColorSystem.buttonColor(for: .danger))
                        Text(error)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(glassColorSystem.buttonColor(for: .danger))
                    }
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Save button
                GlassButton(
                    "Create Draft",
                    icon: "doc.text",
                    style: .pill,
                    role: caption.isEmpty ? .surface : .primary
                ) {
                    if validateInput() {
                        saveDraft()
                    }
                }
                .disabled(caption.isEmpty || isSaving)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }
                
                if showSuccessMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(glassColorSystem.buttonColor(for: .success))
                        Text("Draft created successfully!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(glassColorSystem.buttonColor(for: .success))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    private func validateInput() -> Bool {
        validationError = nil
        
        if caption.isEmpty {
            validationError = "Content cannot be empty"
            return false
        }
        
        return true
    }
    
    private func saveDraft() {
        isSaving = true
        validationError = nil
        
        _Concurrency.Task {
            // Create a Post with draft status
            let post = FocusOSShared.Post(
                caption: caption,
                mediaURLs: [],
                scheduledDate: nil,
                platforms: [],
                status: FocusOSShared.PostStatus.draft.rawValue
            )
            
            modelContext.insert(post)
            try? modelContext.save()
            
            // Broadcast distributed notification for real-time sync with main app
            DistributedNotificationCenter.default.post(
                name: NSNotification.Name("FocusOSPostCreated"),
                object: post.id.uuidString,
                userInfo: [
                    "postID": post.id.uuidString,
                    "caption": post.caption,
                    "status": post.status
                ]
            )
            
            await MainActor.run {
                isSaving = false
                caption = ""
                showSuccessMessage = true
                
                // Reset message after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(Animation.spring(response: 0.3, dampingFraction: 0.7)) {
                        showSuccessMessage = false
                    }
                }
            }
        }
    }
}

#Preview {
    QuickComposerView()
}
