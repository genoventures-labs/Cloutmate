//
//  AIAssistantSection.swift
//  Cloutmate
//
//  AI Assistant settings section
//

import SwiftUI

struct AIAssistantSection: View {
    @State private var aiSettings = AISettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { aiSettings.isAIEnabled },
                set: { aiSettings.isAIEnabled = $0 }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicBlue)
                        .frame(width: 20)
                    Text("Enable AI Features")
                        .font(.body)
                }
            }
            
            Text("When enabled, AI features include: content brainstorming, hook generation, caption writing, text improvement, hashtag suggestions, and conversational AI chat.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    AIAssistantSection()
        .padding()
        .frame(width: 600)
}

