//
//  QuickCaptureSheet.swift
//  Cloutmate
//
//  Inbox V2 - Quick Capture Sheet with Multiple Entry Modes
//

import SwiftUI
import SwiftData
import CloutmateShared

enum CaptureMode: String, CaseIterable {
    case text = "Text"
    case voice = "Voice"
    case link = "Link"
    case aiSnippet = "AI Snippet"
    
    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .voice: return "mic.fill"
        case .link: return "link"
        case .aiSnippet: return "sparkles"
        }
    }
}

struct QuickCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var selectedMode: CaptureMode = .text
    @State private var textContent: String = ""
    @State private var linkURL: String = ""
    @State private var linkPreview: LinkPreview?
    @State private var isLoadingLink = false
    
    // Voice capture
    @State private var isRecording = false
    @State private var voiceTranscript = ""
    @State private var voiceLevel: Float = 0
    @State private var showToast = false
    
    struct LinkPreview {
        let title: String
        let description: String?
        let imageURL: String?
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode Tabs
                HStack(spacing: 0) {
                    ForEach(CaptureMode.allCases, id: \.self) { mode in
                        ModeTab(
                            mode: mode,
                            isSelected: selectedMode == mode,
                            action: {
                                withAnimation(GlassMotion.Easing.spring) {
                                    selectedMode = mode
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Content Area
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedMode {
                        case .text:
                            textCaptureView
                        case .voice:
                            voiceCaptureView
                        case .link:
                            linkCaptureView
                        case .aiSnippet:
                            aiSnippetView
                        }
                    }
                    .padding(20)
                }
                
                // Save Button
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: saveCapture) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Capture")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                }
                .padding(20)
            }
            .background(glassColorSystem.backgroundColor())
            .navigationTitle("Quick Capture")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
        .overlay(
            // Shimmer Toast
            Group {
                if showToast {
                    ShimmerToast(message: "Captured to Inbox!")
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(GlassMotion.Easing.spring, value: showToast)
        )
    }
    
    // MARK: - Text Capture
    
    private var textCaptureView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter your note")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.primary)
            
            TextEditor(text: $textContent)
                .font(.system(.body, design: .rounded))
                .frame(minHeight: 200)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(glassColorSystem.cardColor())
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
                        )
                )
        }
    }
    
    // MARK: - Voice Capture
    
    private var voiceCaptureView: some View {
        VStack(spacing: 20) {
            // Waveform Indicator
            VoiceWaveformView(level: voiceLevel, isActive: isRecording)
                .frame(height: 80)
            
            // Transcript Preview
            if !voiceTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcript")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.primary)
                    
                    ScrollView {
                        Text(voiceTranscript)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(glassColorSystem.cardColor())
                            )
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            // Recording Controls
            HStack(spacing: 16) {
                Button(action: toggleRecording) {
                    HStack {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 32))
                        Text(isRecording ? "Stop Recording" : "Start Recording")
                            .font(.system(.headline, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(isRecording ? Color.red : Color.kosmicBlue)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            setupVoiceService()
        }
    }
    
    private func setupVoiceService() {
        let service = VoiceTranscriptionService.shared
        service.onPartial = { text in
            voiceTranscript = text
        }
        service.onFinal = { text in
            voiceTranscript = text
        }
        service.onLevelUpdate = { level in
            voiceLevel = level
        }
        service.onError = { error in
            print("Voice transcription error: \(error)")
        }
    }
    
    private func toggleRecording() {
        let service = VoiceTranscriptionService.shared
        
        if isRecording {
            service.stopTranscribing()
            isRecording = false
        } else {
            _Concurrency.Task {
                do {
                    try await service.requestPermissions()
                    try service.startTranscribing()
                    isRecording = true
                } catch {
                    print("Failed to start recording: \(error)")
                }
            }
        }
    }
    
    // MARK: - Link Capture
    
    private var linkCaptureView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Paste URL")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.primary)
            
            TextField("https://...", text: $linkURL)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(glassColorSystem.cardColor())
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(glassColorSystem.borderColor(), lineWidth: 1)
                        )
                )
                .onSubmit {
                    fetchLinkPreview()
                }
            
            if isLoadingLink {
                HStack {
                    ProgressView()
                    Text("Fetching preview...")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            if let preview = linkPreview {
                LinkPreviewCard(preview: preview)
            }
        }
    }
    
    private func fetchLinkPreview() {
        guard let url = URL(string: linkURL), !linkURL.isEmpty else { return }
        
        isLoadingLink = true
        
        _Concurrency.Task {
            // Simple URL metadata fetch (can be enhanced with actual metadata extraction)
            // For now, use URL as title
            await MainActor.run {
                linkPreview = LinkPreview(
                    title: url.host ?? linkURL,
                    description: nil,
                    imageURL: nil
                )
                isLoadingLink = false
            }
        }
    }
    
    // MARK: - AI Snippet
    
    private var aiSnippetView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.kosmicPurple)
            
            Text("Save AI Response")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.semibold)
            
            Text("This feature saves the last AI Assistant response to your Inbox. Open the AI Assistant and have a conversation, then return here to save.")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Note: In a full implementation, this would fetch the last AI message
            // For now, provide a text field as fallback
            TextEditor(text: $textContent)
                .font(.system(.body, design: .rounded))
                .frame(minHeight: 150)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(glassColorSystem.cardColor())
                )
        }
    }
    
    // MARK: - Save Logic
    
    private var canSave: Bool {
        switch selectedMode {
        case .text: return !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .voice: return !voiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .link: return !linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .aiSnippet: return !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func saveCapture() {
        let content: String
        let itemType: String
        let fileURL: String?
        let aiImported: Bool
        
        switch selectedMode {
        case .text:
            content = textContent
            itemType = "text"
            fileURL = nil
            aiImported = false
        case .voice:
            content = voiceTranscript
            itemType = "voice"
            fileURL = nil
            aiImported = false
        case .link:
            content = linkPreview?.title ?? linkURL
            itemType = "url"
            fileURL = linkURL
            aiImported = false
        case .aiSnippet:
            content = textContent
            itemType = "text"
            fileURL = nil
            aiImported = true
        }
        
        let inboxItem = InboxItem(
            content: content,
            itemType: itemType,
            fileURL: fileURL
        )
        inboxItem.aiImported = aiImported
        
        modelContext.insert(inboxItem)
        
        // Haptic feedback
        let generator = NSHapticFeedbackManager.defaultPerformer
        generator.perform(.generic, performanceTime: .default)
        
        // Show toast
        withAnimation {
            showToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
            dismiss()
        }
        
        try? modelContext.save()
    }
}

// MARK: - Supporting Views

struct ModeTab: View {
    let mode: CaptureMode
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 16, weight: .medium))
                
                Text(mode.rawValue)
                    .font(.system(.caption, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(isSelected ? glassColorSystem.buttonColor(for: .primary) : glassColorSystem.cardColor())
            )
        }
        .buttonStyle(.plain)
    }
}

struct VoiceWaveformView: View {
    let level: Float
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? Color.kosmicBlue : Color.gray.opacity(0.3))
                    .frame(width: 4)
                    .frame(height: CGFloat(20 + (isActive ? level * 60 : 0)) * CGFloat.random(in: 0.5...1.0))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct LinkPreviewCard: View {
    let preview: QuickCaptureSheet.LinkPreview
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preview.title)
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.primary)
            
            if let description = preview.description {
                Text(description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(glassColorSystem.cardColor())
        )
    }
}

struct ShimmerToast: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(.subheadline, design: .rounded))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.kosmicBlue, Color.kosmicPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shimmer()
            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
            .padding(.top, 20)
    }
}

#Preview {
    QuickCaptureSheet()
        .environmentObject(GlassColorSystem())
}

