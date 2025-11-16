//
//  AuroraChatInputBar.swift
//  Cloutmate
//
//  Unified toolbar + composer for Aurora chat.
//

import SwiftUI
import CloutmateShared

struct AuroraChatInputBar: View {
    @Binding var text: String
    @Binding var linkedContext: LinkedContext
    @FocusState.Binding var isFocused: Bool
    @Binding var isRecording: Bool
    @Binding var voiceInputText: String

    var isLoading: Bool
    var pendingImageAttachment: ImageAttachmentService.ImageAttachment?
    var pendingDocumentAttachment: DocumentAttachmentService.DocumentAttachment?
    var lastConfidenceScore: Double?
    var canRetry: Bool
    var canSendWhileEmpty: Bool = false
    var onResendLastAssistant: (() -> Void)?

    var onSend: () -> Void
    var onAttachDocument: () -> Void
    var onAttachImage: () -> Void
    var onClearDocument: () -> Void
    var onClearImage: () -> Void
    var onStop: () -> Void
    var onRetry: () -> Void
    var onToggleVoice: () -> Void
    var onWebSearch: () -> Void
    var onActionSelected: (AuroraChatQuickAction) -> Void
    var onAttachTab: ((TabIdentifier) -> Void)?
    var onSlashCommand: ((SlashCommand, NSRange) -> Void)?

    var isOfflineMode: Bool
    var accentColor: Color
    var glowColor: Color

    var contextChips: [String] = []
    var onDetachContext: (() -> Void)?
    var onDetachChip: ((String) -> Void)?
    var onHoverContext: (Bool) -> Void = { _ in }
    
    // Message flags
    var hasThinkFlag: Bool = false
    var hasWebFlag: Bool = false
    var isResearchMode: Bool = false // Research mode indicator
    
    // Autocomplete callback - passes state to parent container (showMention, showHashtag, showSlash, cursorPosition, mentionResults, hashtagResults, slashCommands, mentionSelectedIndex, hashtagSelectedIndex, slashSelectedIndex, activeTabFilter)
    var onAutocompleteVisibilityChanged: ((Bool, Bool, Bool, CGPoint, [WorkspaceObjectResult], [WorkspaceObjectResult], [SlashCommand], Int, Int, Int, ObjectType?) -> Void)? = nil
    
    var onClearResearchMode: (() -> Void)? = nil // Callback to clear research mode

    private var hasAttachment: Bool {
        pendingDocumentAttachment != nil || pendingImageAttachment != nil
    }

    private var canSend: Bool {
        if canSendWhileEmpty { return true }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasAttachment
    }

    private var confidenceLevel: Double {
        if let lastConfidenceScore {
            return lastConfidenceScore
        }
        return estimateInputQuality(from: text)
    }

    private let placeholderOptions = [
        "Ask Aurora anything…",
        "What should we plan next?",
        "Need help organizing your thoughts?"
    ]

    @State private var placeholderIndex = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isResearchMode || !contextChips.isEmpty {
                contextRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if isRecording {
                recordingBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let document = pendingDocumentAttachment {
                attachmentPreview(
                    icon: "doc.text.fill",
                    title: document.fileName,
                    subtitle: documentDetailText(for: document),
                    onClear: onClearDocument
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if let imageAttachment = pendingImageAttachment {
                attachmentPreview(
                    icon: "photo.fill",
                    title: imageAttachment.fileName ?? "Attached Image",
                    subtitle: imageAttachment.mimeType,
                    onClear: onClearImage
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            inputRow
            
            if hasThinkFlag || hasWebFlag {
                flagIndicators
                    .transition(.opacity)
            }

            if shouldShowConfidence {
                confidenceRow
                    .transition(.opacity)
            }
        }
        .onAppear(perform: startPlaceholderRotation)
        .onKeyPress(.escape) {
            // Dismiss autocomplete on Escape
            NotificationCenter.default.post(
                name: NSNotification.Name("DismissAutocomplete"),
                object: nil
            )
            return .handled
        }
    }

    private var inputRow: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(glowColor.opacity(0.06))
                        .blur(radius: 20)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(isFocused ? 0.4 : 0.18),
                                    glowColor.opacity(isFocused ? 0.35 : 0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isFocused ? 1.2 : 0.8
                        )
                )

            HStack(alignment: .center, spacing: 14) {
                AttachmentMenuView(
                    isDisabled: isLoading || isRecording,
                    activeAttachment: pendingDocumentAttachment != nil ? .document : (pendingImageAttachment != nil ? .image : nil),
                    onSelectDocument: onAttachDocument,
                    onSelectImage: onAttachImage
                )
                .help("Attach document or image")

                ActionMenuView(
                    isDisabled: isLoading,
                    isOfflineMode: isOfflineMode,
                    tint: accentColor,
                    onSelect: onActionSelected,
                    onAttachTab: onAttachTab
                )
                .help("Aurora actions")

                inputField

                VoiceButton(
                    isRecording: isRecording,
                    isDisabled: isLoading,
                    onTap: onToggleVoice
                )
                .help(isRecording ? "Stop recording" : "Voice input")

                WebButton(
                    isDisabled: isLoading,
                    onTap: onWebSearch
                )
                .help("Search the web")

                trailingControls
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(minHeight: 62, maxHeight: 70)
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: AuroraChatContainer.InputBarFramePreferenceKey.self,
                    value: geometry.frame(in: .named("panelBody"))
                )
            }
        )
    }

    private var contextRow: some View {
        HStack(spacing: 8) {
            if isResearchMode {
                researchModeChip
            }
            ForEach(contextChips, id: \.self) { chip in
                contextChip(for: chip)
            }
            Spacer(minLength: 0)
        }
    }
    
    private var researchModeChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 12, weight: .medium))
            Text("Research Mode")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.kosmicBlue)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.kosmicBlue.opacity(0.25), Color.kosmicBlue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule()
                .stroke(Color.kosmicBlue.opacity(0.4), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            Button {
                onClearResearchMode?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.5))
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 16, height: 16)
                    )
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
            .help("Clear research mode")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Research Mode")
        .accessibilityHint("Press the X button to clear research mode.")
    }

    private func contextChip(for label: String) -> some View {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.25), glowColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(accentColor.opacity(0.4), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    onDetachChip?(label)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.5))
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 16, height: 16)
                        )
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .help("Detach")
            }
            .foregroundColor(.primary)
            .onHover { hovering in
                onHoverContext(hovering)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint("Press the X button to detach this tab.")
    }

    private var inputField: some View {
        VStack(alignment: .leading, spacing: 0) {
            MentionInputField(
                text: $text,
                isFocused: $isFocused,
                placeholder: placeholderOptions[placeholderIndex],
                onSubmit: onSend,
                linkedContext: $linkedContext,
                isEnabled: !isRecording,
                onSlashCommand: onSlashCommand,
                onAutocompleteVisibilityChanged: { showMention, showHashtag, showSlash, cursorPos, mentionResults, hashtagResults, slashCommands, mentionIndex, hashtagIndex, slashIndex, tabFilter in
                    onAutocompleteVisibilityChanged?(showMention, showHashtag, showSlash, cursorPos, mentionResults, hashtagResults, slashCommands, mentionIndex, hashtagIndex, slashIndex, tabFilter)
                },
                onSelectMentionResult: { result in
                    // This callback will be called when overlay selects a result
                    // The actual selection is handled by MentionInputField internally
                },
                onSelectSlashCommand: { command in
                    // This callback will be called when overlay selects a command
                    // The actual selection is handled by MentionInputField internally
                }
            )
            .font(.system(size: 15))
            .frame(minHeight: 32, maxHeight: 120)
            .fixedSize(horizontal: false, vertical: false)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: AuroraChatContainer.InputTextFieldFramePreferenceKey.self,
                        value: geometry.frame(in: .named("panelBody"))
                    )
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trailingControls: some View {
        HStack(spacing: 12) {
            if isLoading {
                GlassButton(
                    icon: "stop.circle.fill",
                    style: .iconOnly,
                    tintColor: .red,
                    action: onStop
                )
                .frame(width: 24, height: 24)
                .help("Stop response")
            } else {
                GlassButton(
                    icon: "arrow.up.circle.fill",
                    style: .iconOnly,
                    tintColor: canSend ? accentColor : .gray.opacity(0.35),
                    action: onSend
                )
                .frame(width: 22, height: 22)
                .disabled(!canSend)
                .help("Send message")
            }
        }
    }

    private var recordingBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .foregroundColor(.red)
                .symbolEffect(.variableColor.iterative, isActive: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Listening…")
                    .font(.caption)
                    .foregroundColor(.primary)
                if !voiceInputText.isEmpty {
                    Text(voiceInputText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button("Stop") {
                onToggleVoice()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.12))
        )
    }

    private var confidenceColor: Color {
        if confidenceLevel < 0.4 {
            return .orange
        } else if confidenceLevel < 0.7 {
            return .purple
        } else {
            return .green
        }
    }

    private var shouldShowConfidence: Bool {
        !text.isEmpty && !isLoading
    }
    
    private var flagIndicators: some View {
        HStack(spacing: 8) {
            if hasThinkFlag {
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 10, weight: .medium))
                    Text("Think")
                        .font(.caption2)
                }
                .foregroundStyle(accentColor.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(accentColor.opacity(0.15))
                )
            }
            
            if hasWebFlag {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 10, weight: .medium))
                    Text("Web")
                        .font(.caption2)
                }
                .foregroundStyle(glowColor.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(glowColor.opacity(0.15))
                )
            }
        }
        .padding(.leading, 4)
    }

    private var confidenceRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
                .opacity(0.7)

            Text(lastConfidenceScore != nil ? "Last response confidence: \(Int(confidenceLevel * 100))%" : "Input quality: \(Int(confidenceLevel * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private func attachmentPreview(icon: String, title: String, subtitle: String, onClear: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove attachment")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.08))
        )
    }

    private func documentDetailText(for attachment: DocumentAttachmentService.DocumentAttachment) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let sizeLabel = formatter.string(fromByteCount: Int64(attachment.sizeInBytes))
        var parts: [String] = [attachment.mimeType, sizeLabel]
        if let pages = attachment.pageCount, pages > 0 {
            parts.append("\(pages) page\(pages == 1 ? "" : "s")")
        }
        if let url = attachment.sourceURL {
            let host = url.host ?? url.absoluteString
            parts.append(host)
        }
        return parts.joined(separator: " • ")
    }

    private func estimateInputQuality(from input: String) -> Double {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0.5 }

        var quality: Double = 0.5
        let lengthScore = min(1.0, Double(trimmed.count) / 120.0) * 0.2
        quality += lengthScore

        if trimmed.contains("?") {
            quality += 0.12
        }

        let sentenceCount = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
        if sentenceCount > 1 {
            quality += 0.1
        }

        if trimmed.contains("@") {
            quality += 0.1
        }

        return min(1.0, max(0.3, quality))
    }

    private func startPlaceholderRotation() {
        guard placeholderOptions.count > 1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            guard text.isEmpty else { return }
            placeholderIndex = (placeholderIndex + 1) % placeholderOptions.count
            startPlaceholderRotation()
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @State var linkedContext = LinkedContext()
    @Previewable @FocusState var isFocused: Bool
    @Previewable @State var isRecording = false
    @Previewable @State var voiceText = ""

    return AuroraChatInputBar(
        text: $text,
        linkedContext: $linkedContext,
        isFocused: $isFocused,
        isRecording: $isRecording,
        voiceInputText: $voiceText,
        isLoading: false,
        pendingImageAttachment: nil,
        pendingDocumentAttachment: nil,
        lastConfidenceScore: nil,
        canRetry: false,
        onResendLastAssistant: nil,
        onSend: {},
        onAttachDocument: {},
        onAttachImage: {},
        onClearDocument: {},
        onClearImage: {},
        onStop: {},
        onRetry: {},
        onToggleVoice: {},
        onWebSearch: {},
        onActionSelected: { _ in },
        onAttachTab: nil,
        onSlashCommand: nil,
        isOfflineMode: false,
        accentColor: .kosmicBlue,
        glowColor: .kosmicPurple
    )
    .padding()
    .background(Color.black.opacity(0.95))
}
