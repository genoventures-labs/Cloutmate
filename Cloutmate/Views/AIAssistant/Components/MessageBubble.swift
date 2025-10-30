//
//  MessageBubble.swift
//  Cloutmate
//
//  Glass-themed Message Bubble
//

import SwiftUI

struct MessageBubble: View {
    let message: AIMessage
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var isUser: Bool {
        message.role ?? "user" == "user"
    }
    
    var isSystemMessage: Bool {
        message.isSystemMessage
    }
    
    @ViewBuilder
    private var messageBackground: some View {
        if isUser {
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isSystemMessage {
            Color.yellow.opacity(0.2)
                .background(.ultraThinMaterial)
        } else {
            Color.clear
                .background(.ultraThinMaterial)
        }
    }
    
    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 60)
            }
            
            if isSystemMessage {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isSystemMessage ? .center : (isUser ? .trailing : .leading), spacing: 4) {
                Text(message.content ?? "")
                    .font(isSystemMessage ? .caption : .body)
                    .fontWeight(isSystemMessage ? .medium : .regular)
                    .foregroundColor(isUser ? .white : (isSystemMessage ? .secondary : .primary))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(messageBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isUser ? Color.white.opacity(0.2) : Color.white.opacity(0.15),
                                lineWidth: 1
                            )
                    )
                
                Text((message.timestamp ?? Date()).formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                if let tool = message.toolUsed {
                    Text("Used: \(tool)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4)
                }
            }
            
            if !isUser && !isSystemMessage {
                Spacer(minLength: 60)
            }
            
            if isSystemMessage {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
    }
}

#Preview {
    VStack {
        MessageBubble(message: AIMessage(role: "user", content: "Generate a hook for my social media post"))
        MessageBubble(message: AIMessage(role: "assistant", content: "Here are some engaging hook ideas:\n\n💡 Ever wondered...\n🚀 This one simple trick..."))
    }
    .environmentObject(GlassColorSystem())
}
