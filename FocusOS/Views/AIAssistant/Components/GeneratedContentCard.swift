//
//  GeneratedContentCard.swift
//  FocusOS
//
//  Card to Display AI-Generated Content
//

import SwiftUI

struct GeneratedContentCard: View {
    let content: String
    let onCopy: () -> Void
    
    @State private var copied = false
    
    var body: some View {
        GlassPanel(tier: .overlay, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.kosmicBlue)
                    
                    Text("Generated Content")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        onCopy()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copied = false
                        }
                    }) {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundColor(copied ? .kosmicGreen : .kosmicBlue)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.2))
                
                Text(content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
            .padding()
        }
    }
}

#Preview {
    GeneratedContentCard(
        content: "Here's an engaging hook for your social media post:\n\n💡 Ever wondered why some posts get tons of engagement while others don't? It all comes down to the hook!",
        onCopy: {}
    )
    .padding()
}
