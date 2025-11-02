//
//  AIPromptDialog.swift
//  Cloutmate
//
//  AI Prompt Dialog for user input
//

import SwiftUI
import CloutmateShared

struct AIPromptDialog: View {
    let platform: CloutmateShared.Platform
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    
    @State private var userPrompt = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var examplePrompts: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.kosmicBlue)
                Text("AI Assistant")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("What would you like to generate?")
                    .font(.headline)
                
                Text(getPromptHint())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Text input
            VStack(alignment: .leading, spacing: 8) {
                TextField(getPlaceholder(), text: $userPrompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if !userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onConfirm(userPrompt)
                        }
                    }
                
                // Example prompts
                if !examplePrompts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Examples:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(examplePrompts, id: \.self) { prompt in
                                    Button(action: {
                                        userPrompt = prompt
                                        isTextFieldFocused = true
                                    }) {
                                        Text(prompt)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.kosmicBlue.opacity(0.1))
                                            .foregroundColor(.kosmicBlue)
                                            .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Generate") {
                    let trimmed = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onConfirm(trimmed)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500)
        .background(.regularMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            examplePrompts = getExamplePrompts()
            isTextFieldFocused = true
        }
    }
    
    private func getPromptHint() -> String {
        switch platform {
        case .facebook:
            return "Tell me about your content idea, topic, or theme for Facebook"
        case .threads:
            return "Tell me about your content idea, topic, or theme for Threads"
        @unknown default:
            return "Tell me about your content idea, topic, or theme"
        }
    }
    
    private func getPlaceholder() -> String {
        switch platform {
        case .facebook:
            return "e.g., Share tips about productivity, announce a new product, or brainstorm content ideas about..."
        case .threads:
            return "e.g., Share a quick tip, ask a question, or discuss..."
        @unknown default:
            return "e.g., Share your content idea or topic..."
        }
    }
    
    private func getExamplePrompts() -> [String] {
        switch platform {
        case .facebook:
            return [
                "Tips for productivity",
                "New product announcement",
                "Behind the scenes",
                "Community spotlight"
            ]
        case .threads:
            return [
                "Quick tip",
                "Ask a question",
                "Share a thought",
                "Start a discussion"
            ]
        @unknown default:
            return [
                "Content idea",
                "Topic discussion",
                "Share thoughts",
                "Engage audience"
            ]
        }
    }
}
