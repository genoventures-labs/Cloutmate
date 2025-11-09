//
//  AIMessageComposer.swift
//  Cloutmate
//
//  AI Assistant V2 - Message Composer Component (ContentCard Tier)
//  Rounded text field with @mention autocomplete, Send button, confidence meter
//

import SwiftUI
import SwiftData
import CloutmateShared
import AppKit

struct AIMessageComposer: View {
    @Binding var text: String
    @Binding var linkedContext: LinkedContext
    @FocusState.Binding var isFocused: Bool
    @Binding var isRecording: Bool
    @Binding var voiceInputText: String
    var isLoading: Bool
    var pendingImageAttachment: ImageAttachmentService.ImageAttachment?
    var pendingDocumentAttachment: DocumentAttachmentService.DocumentAttachment?
    var lastConfidenceScore: Double? // Confidence score from last assistant message
    
    let onSend: () -> Void
    let onAttachImage: () -> Void
    let onAttachDocument: () -> Void
    let onClearImage: () -> Void
    let onClearDocument: () -> Void
    
    @Environment(\.glassTier) private var glassTier
    @Environment(\.modelContext) private var modelContext
    
    // Calculate confidence level from last response or estimate from input quality
    private var confidenceLevel: Double {
        if let lastConfidence = lastConfidenceScore {
            return lastConfidence
        }
        // Estimate confidence based on input quality indicators
        return estimateInputQuality(from: text)
    }
    
    private func estimateInputQuality(from input: String) -> Double {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0.5 }
        
        var quality: Double = 0.5 // Base quality
        
        // Longer inputs tend to be more specific (higher quality)
        let lengthScore = min(1.0, Double(trimmed.count) / 100.0) * 0.2
        quality += lengthScore
        
        // Questions (?) indicate clear intent
        if trimmed.contains("?") {
            quality += 0.15
        }
        
        // Multiple sentences suggest thoughtful input
        let sentenceCount = trimmed.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        if sentenceCount > 1 {
            quality += 0.1
        }
        
        // @mentions indicate context-aware input (higher quality)
        if trimmed.contains("@") {
            quality += 0.1
        }
        
        return min(1.0, max(0.3, quality))
    }
    
    var body: some View {
        GlassPanel(tier: .contentCard) {
        VStack(spacing: 12) {
            // Voice recording indicator
            if isRecording {
                    GlassPanel(tier: .overlay, cornerRadius: 8) {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .foregroundColor(.red)
                            .symbolEffect(.variableColor.iterative, isActive: true)
                        Text("Listening...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        
                                GlassButton(
                                    icon: "checkmark.circle.fill",
                                    style: .standard,
                                    tintColor: .kosmicBlue,
                                    action: {
                            isRecording = false
                                    }
                                )
                                .frame(height: 24)
                                
                                Button("Cancel") {
                                    isRecording = false
                        }
                        .buttonStyle(.plain)
                                .foregroundColor(.red)
                                .font(.caption)
                    }
                    
                    if !voiceInputText.isEmpty {
                        Text(voiceInputText)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                    }
                .background(Color.red.opacity(0.1))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Attachment previews
            if let document = pendingDocumentAttachment {
                attachmentPreview(
                    icon: "doc.text.fill",
                    title: document.fileName,
                    subtitle: documentDetailText(for: document),
                    onClear: onClearDocument
                )
            } else if let attachment = pendingImageAttachment {
                attachmentPreview(
                    icon: "photo.fill",
                    title: attachment.fileName ?? "Attached Image",
                    subtitle: attachment.mimeType,
                    onClear: onClearImage
                )
            }
            
                // Text input with @mention support
            HStack(spacing: 10) {
                let attachmentIconName: String = {
                    if pendingDocumentAttachment != nil {
                        return "paperclip.circle.fill"
                    }
                    if pendingImageAttachment != nil {
                        return "photo.fill"
                    }
                    return "paperclip.circle"
                }()
                
                    GlassButton(
                        icon: attachmentIconName,
                        style: .iconOnly,
                        action: {
                            // Menu will be handled by parent
                        }
                    )
                    .frame(width: 24, height: 24)
                    .disabled(isRecording || isLoading)
                    .help("Attach file")
                    .overlay {
                Menu {
                    Button("Document", action: onAttachDocument)
                        .disabled(pendingDocumentAttachment != nil || isLoading)
                    Divider()
                    Button("Image From Computer", action: onAttachImage)
                } label: {
                            EmptyView()
                }
                .menuStyle(BorderlessButtonMenuStyle())
                    }
                
                // Text input with @mention support
                ZStack(alignment: .topLeading) {
                    MentionInputField(
                        text: $text,
                        isFocused: $isFocused,
                        placeholder: "Ask me anything...",
                        onSubmit: onSend,
                        linkedContext: $linkedContext,
                        isEnabled: !isRecording && !isLoading
                    )
                        .frame(minHeight: 36, maxHeight: 200)
                        .fixedSize(horizontal: false, vertical: false)
                    .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                    isFocused ? Color.kosmicBlue : Color(nsColor: .separatorColor),
                                lineWidth: isFocused ? 1.5 : 0.5
                            )
                            .allowsHitTesting(false)
                    )
                }
                
                    // Send button
                let hasAttachment = pendingImageAttachment != nil || pendingDocumentAttachment != nil
                let canSend = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasAttachment
                
                    GlassButton(
                        icon: "arrow.up.circle.fill",
                        style: .iconOnly,
                        tintColor: canSend ? .kosmicBlue : nil,
                        action: onSend
                    )
                    .frame(width: 32, height: 32)
                .disabled(!canSend || isRecording || isLoading)
                .help("Send message")
            }
            
            // Confidence Preview Meter (shows last response confidence or input quality estimate)
            if !text.isEmpty && !isLoading {
                HStack(spacing: 4) {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 8, height: 8)
                        .opacity(0.7)
                    Text(lastConfidenceScore != nil ? "Last response confidence: \(Int(confidenceLevel * 100))%" : "Input quality: \(Int(confidenceLevel * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        }
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
    
    private func attachmentPreview(icon: String, title: String, subtitle: String, onClear: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.kosmicBlue)
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
        .padding(8)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
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
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @State var linkedContext = LinkedContext()
    @Previewable @FocusState var isFocused: Bool
    @Previewable @State var isRecording = false
    @Previewable @State var voiceText = ""
    
    AIMessageComposer(
        text: $text,
        linkedContext: $linkedContext,
        isFocused: $isFocused,
        isRecording: $isRecording,
        voiceInputText: $voiceText,
        isLoading: false,
        pendingImageAttachment: nil,
        pendingDocumentAttachment: nil,
        lastConfidenceScore: nil,
        onSend: {},
        onAttachImage: {},
        onAttachDocument: {},
        onClearImage: {},
        onClearDocument: {}
    )
    .environment(\.glassTier, .contentCard)
}

