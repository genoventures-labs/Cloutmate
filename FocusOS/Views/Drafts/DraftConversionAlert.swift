//
//  DraftConversionAlert.swift
//  FocusOS
//
//  Draft Conversion Confirmation Alert
//

import SwiftUI

struct DraftConversionResult {
    let postID: UUID
    let status: PostStatus
    let date: Date
}

struct DraftConversionAlert: View {
    let isScheduled: Bool
    let onKeepDraft: () -> Void
    let onRemoveDraft: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isScheduled ? "calendar.badge.clock" : "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(isScheduled ? .kosmicBlue : .kosmicGreen)
            
            Text(isScheduled ? "Post Scheduled" : "Post Published")
                .font(.headline)
            
            Text(isScheduled 
                ? "Your post has been scheduled. Would you like to remove this draft?"
                : "Your post has been published. Would you like to remove this draft?")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button("Keep Draft") {
                    onKeepDraft()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Remove") {
                    onRemoveDraft()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(width: 350)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.kosmicBlue.opacity(0.3), Color.kosmicPurple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .blur(radius: 1)
        )
    }
}

#Preview {
    DraftConversionAlert(
        isScheduled: true,
        onKeepDraft: {},
        onRemoveDraft: {}
    )
}
