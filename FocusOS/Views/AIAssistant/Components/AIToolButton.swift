//
//  AIToolButton.swift
//  FocusOS
//
//  AI Tool Quick Action Button
//

import SwiftUI

struct AIToolButton: View {
    let tool: AITool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: tool.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.kosmicBlue)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                Text(tool.rawValue)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 100)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 16) {
        AIToolButton(tool: .brainstorm, action: {})
        AIToolButton(tool: .generateCaptions, action: {})
        AIToolButton(tool: .suggestHashtags, action: {})
    }
    .padding()
}
