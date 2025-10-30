//
//  QuickComposerView.swift
//  CloutmateMenuBar
//

import SwiftUI
import SwiftData
import CloutmateShared

struct QuickComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var caption = ""
    @State private var selectedPlatforms: Set<Platform> = []
    @State private var scheduledDate: Date?
    @State private var isScheduled = false
    @State private var isPublishing = false
    @State private var validationError: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Caption input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Caption")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        
                        if caption.isEmpty {
                            Text("What's on your mind?")
                                .foregroundColor(.secondary)
                                .padding(8)
                        }
                        
                        TextEditor(text: $caption)
                            .scrollContentBackground(.hidden)
                            .padding(4)
                    }
                    .frame(height: 120)
                }
                
                // Platform selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Platforms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        PlatformToggle(platform: .threads, isSelected: selectedPlatforms.contains(.threads), toggleAction: {
                            if selectedPlatforms.contains(.threads) {
                                selectedPlatforms.remove(.threads)
                            } else {
                                selectedPlatforms.insert(.threads)
                            }
                        })
                        
                        PlatformToggle(platform: .facebook, isSelected: selectedPlatforms.contains(.facebook), toggleAction: {
                            if selectedPlatforms.contains(.facebook) {
                                selectedPlatforms.remove(.facebook)
                            } else {
                                selectedPlatforms.insert(.facebook)
                            }
                        })
                    }
                }
                
                // Schedule toggle
                Toggle("Schedule for later", isOn: $isScheduled)
                
                if isScheduled {
                    DatePicker("Scheduled Time", selection: Binding(
                        get: { scheduledDate ?? Date() },
                        set: { scheduledDate = $0 }
                    ))
                    .datePickerStyle(.compact)
                }
                
                // Error display
                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Post button
                Button(action: {
                    if validateInput() {
                        savePost()
                    }
                }) {
                    HStack {
                        if isPublishing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        }
                        Text(isScheduled ? "Schedule" : "Post Now")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedPlatforms.isEmpty || caption.isEmpty ? Color.gray : Color.blue)
                    )
                    .foregroundColor(.white)
                }
                .disabled(selectedPlatforms.isEmpty || caption.isEmpty || isPublishing)
                .padding(.horizontal)
            }
            .padding()
        }
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
        
        // Notify menu bar app of status change
        NotificationCenter.default.post(
            name: NSNotification.Name("PostStatusChanged"),
            object: nil,
            userInfo: ["status": "publishing"]
        )
        
        Task {
            let post = CloutmateShared.Post(
                caption: caption,
                mediaURLs: [],
                scheduledDate: isScheduled ? scheduledDate : nil,
                platforms: Array(selectedPlatforms).map { $0.rawValue },
                status: isScheduled ? CloutmateShared.PostStatus.scheduled.rawValue : CloutmateShared.PostStatus.publishing.rawValue
            )
            
            // Get pageIDs for Facebook accounts and store in post
                    var pageIDs: [String: String] = [:]
                    if selectedPlatforms.contains(.facebook) {
                        let descriptor = FetchDescriptor<CloutmateShared.PlatformAccount>(
                            predicate: #Predicate<CloutmateShared.PlatformAccount> { account in
                                account.platform == "facebook"
                            }
                        )
                        if let facebookAccount = try? modelContext.fetch(descriptor).first {
                            pageIDs["facebook"] = facebookAccount.accountID
                        }
                    }
            post.pageIDs = pageIDs
            
            modelContext.insert(post)
            try? modelContext.save()
            
            if isScheduled {
                // Post is in SwiftData, helper will pick it up
                // Trigger immediate check to ensure helper sees it
                XPCService.shared.checkScheduledPosts()
            } else {
                // Publish immediately using PublishingService
                await PublishingService.shared.publishPost(post, context: modelContext)
                
                // Notify of result
                NotificationCenter.default.post(
                    name: NSNotification.Name("PostStatusChanged"),
                    object: nil,
                    userInfo: ["status": post.postStatus.rawValue]
                )
            }
            
            // Try to save the context
            try? modelContext.save()
            
            // Broadcast distributed notification for real-time sync with main app
            DistributedNotificationCenter.default.post(
                name: NSNotification.Name("CloutmatePostCreated"),
                object: post.id.uuidString,
                userInfo: [
                    "postID": post.id.uuidString,
                    "caption": post.caption,
                    "status": post.status,
                    "isScheduled": isScheduled
                ]
            )
            
            await MainActor.run {
                // Show notifications based on result
                if isScheduled {
                    NotificationService.shared.showScheduledNotification(
                        caption: post.caption,
                        scheduledDate: scheduledDate!
                    )
                } else {
                    if post.postStatus == .published {
                        NotificationService.shared.showSuccessNotification(caption: post.caption)
                        // Also send distributed notification for published status
                        DistributedNotificationCenter.default.post(
                            name: NSNotification.Name("CloutmatePostPublished"),
                            object: post.id.uuidString,
                            userInfo: ["postID": post.id.uuidString]
                        )
                    } else if post.postStatus == .failed {
                        NotificationService.shared.showFailureNotification(
                            error: post.lastError ?? "Unknown error"
                        )
                        // Send failure notification
                        DistributedNotificationCenter.default.post(
                            name: NSNotification.Name("CloutmatePostFailed"),
                            object: post.id.uuidString,
                            userInfo: [
                                "postID": post.id.uuidString,
                                "error": post.lastError ?? "Unknown error"
                            ]
                        )
                    }
                }
                
                isPublishing = false
                caption = ""
                selectedPlatforms = []
                isScheduled = false
                scheduledDate = nil
            }
        }
    }
}

struct PlatformToggle: View {
    let platform: Platform
    let isSelected: Bool
    let toggleAction: () -> Void
    
    var body: some View {
        Button(action: toggleAction) {
            HStack(spacing: 6) {
                Circle()
                    .fill(platform == .threads ? Color.purple : Color.blue)
                    .frame(width: 8, height: 8)
                Text(platform.displayName)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AnyShapeStyle(platform == .threads ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2)) : AnyShapeStyle(.ultraThinMaterial))
                    .stroke(isSelected ? (platform == .threads ? Color.purple : Color.blue) : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    QuickComposerView()
}

