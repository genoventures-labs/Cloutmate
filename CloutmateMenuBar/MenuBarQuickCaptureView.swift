//
//  MenuBarQuickCaptureView.swift
//  CloutmateMenuBar
//
//  Quick Capture View for Menu Bar
//

import SwiftUI
import SwiftData
import CloutmateShared

enum CaptureType: String, CaseIterable {
    case draft = "Draft"
    case artifact = "Artifact"
    
    var icon: String {
        switch self {
        case .draft: return "doc.text"
        case .artifact: return "sparkles"
        }
    }
}

struct MenuBarQuickCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @FocusState private var isFocused: Bool
    
    @State private var content = ""
    @State private var selectedType: CaptureType = .draft
    @State private var showSuccessMessage = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Type Selector with FilterChips
                VStack(alignment: .leading, spacing: 10) {
                    Text("Type")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(glassColorSystem.textSecondary())
                    
                    HStack(spacing: 8) {
                        ForEach(CaptureType.allCases, id: \.self) { type in
                            FilterChip(
                                title: type.rawValue,
                                isSelected: selectedType == type,
                                action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedType = type
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Content Input
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
                        
                        if content.isEmpty {
                            Text("What's on your mind?")
                                .font(.system(size: 14))
                                .foregroundColor(glassColorSystem.textSecondary().opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                        
                        TextEditor(text: $content)
                            .font(.system(size: 14))
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .focused($isFocused)
                            .frame(minHeight: 150)
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
                
                // Action Button
                GlassButton(
                    "Capture to \(selectedType.rawValue)",
                    icon: selectedType.icon,
                    style: .pill,
                    role: .primary
                ) {
                    captureContent()
                }
                .disabled(content.isEmpty)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                if showSuccessMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(glassColorSystem.buttonColor(for: .success))
                        Text("Captured successfully!")
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
        .onSubmit {
            if !content.isEmpty {
                captureContent()
            }
        }
    }
    
    private func captureContent() {
        guard !content.isEmpty else { return }
        
        withAnimation(.linear(duration: 0.15)) {
            switch selectedType {
            case .draft:
                // Create a Post with draft status instead
                let post = CloutmateShared.Post(
                    caption: content,
                    mediaURLs: [],
                    scheduledDate: nil,
                    platforms: [],
                    status: CloutmateShared.PostStatus.draft.rawValue
                )
                modelContext.insert(post)
            case .artifact:
                let artifact = CloutmateShared.Artifact(
                    title: content.prefix(50).description,
                    content: content,
                    outputFormat: .brief
                )
                modelContext.insert(artifact)
            }
            
            do {
                try modelContext.save()
                content = ""
                showSuccessMessage = true
                
                // Reset message after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(Animation.spring(response: 0.3, dampingFraction: 0.7)) {
                        showSuccessMessage = false
                    }
                }
            } catch {
                print("Failed to save: \(error)")
            }
        }
    }
}

#Preview {
    MenuBarQuickCaptureView()
        .modelContainer(for: [CloutmateShared.Post.self, CloutmateShared.Artifact.self])
}

