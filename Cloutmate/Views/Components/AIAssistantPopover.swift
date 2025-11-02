//
//  AIAssistantPopover.swift
//  Cloutmate
//
//  AI Assistant Popover with Tool Options
//

import SwiftUI
import CloutmateShared

struct AIAssistantPopover: View {
    let onToolSelected: (AITool) -> Void
    let contextText: String = ""
    let platform: CloutmateShared.Platform
    
    var availableTools: [AITool] {
        // Convert CloutmateShared.Platform to local Platform for configuration
        // Local Platform enum is in Cloutmate/Models/Platform.swift
        enum LocalPlatform: String {
            case threads = "threads"
            case facebook = "facebook"
        }
        let localPlatformValue = LocalPlatform(rawValue: platform.rawValue) ?? .facebook
        // Use platform-specific tool availability
        switch localPlatformValue {
        case .facebook:
            return [.brainstorm, .generateCaptions, .suggestHashtags, .improveText, .adjustTone]
        case .threads:
            return [.brainstorm, .generateCaptions, .suggestHashtags, .improveText]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.kosmicBlue)
                Text("AI Assistant")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Tool Options (filtered by platform)
            VStack(spacing: 0) {
                ForEach(availableTools, id: \.self) { tool in
                    Button(action: {
                        onToolSelected(tool)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: tool.icon)
                                .foregroundColor(.kosmicBlue)
                                .frame(width: 24)
                            
                            Text(tool.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(.clear)
                    
                    if tool != availableTools.last {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 220)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

#Preview {
    AIAssistantPopover(onToolSelected: { _ in }, platform: .facebook)
        .padding()
}
