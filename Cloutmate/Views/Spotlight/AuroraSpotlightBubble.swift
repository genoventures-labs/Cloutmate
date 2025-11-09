//
//  AuroraSpotlightBubble.swift
//  Cloutmate
//
//  Compact chat bubble component for Aurora Spotlight
//

import SwiftUI

struct AuroraSpotlightBubble: View {
    let message: AIMessage
    
    var isUser: Bool {
        message.role ?? "user" == "user"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isUser {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.kosmicBlue)
                    .frame(width: 20)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if let contentString = message.content, !contentString.isEmpty {
                    Text(contentString)
                        .font(.body)
                        .foregroundColor(isUser ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if isUser {
                                    LinearGradient(
                                        colors: [Color.kosmicBlue, Color.kosmicPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    Color(.controlBackgroundColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        )
                        .cornerRadius(12)
                }
                
                // Thinking view (collapsible) for assistant messages
                if !isUser, let thinking = message.thinkingContent, !thinking.isEmpty {
                    ThinkingView(thinkingContent: thinking)
                        .padding(.top, 4)
                }
                
                // Model badge at bottom
                if !isUser, let modelUsed = message.modelUsed, !modelUsed.isEmpty {
                    ModelBadge(modelName: modelUsed)
                        .padding(.top, 4)
                }
            }
            
            if isUser {
                Image(systemName: "person.circle.fill")
                    .font(.caption)
                    .foregroundColor(.kosmicBlue)
                    .frame(width: 20)
            }
        }
    }
}

