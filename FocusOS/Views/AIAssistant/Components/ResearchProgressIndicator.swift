//
//  ResearchProgressIndicator.swift
//  FocusOS
//
//  Simple updating card that shows research progress with action text and source count
//

import SwiftUI

struct ResearchProgressIndicator: View {
    let action: String
    let sourceCount: Int
    
    @State private var opacity: Double = 1.0
    
    var body: some View {
        HStack(spacing: 8) {
            // Action text on left
            Text(action)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 8)
            
            // Source count on right (only if > 0)
            if sourceCount > 0 {
                Text("\(sourceCount) \(sourceCount == 1 ? "source" : "sources")")
                    .font(.caption)
                    .foregroundColor(.kosmicBlue)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.gray.opacity(0.06))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .opacity(opacity)
        .transition(.opacity)
    }
}

#Preview {
    VStack(spacing: 12) {
        ResearchProgressIndicator(
            action: "Searched for: retail foot traffic 2022...",
            sourceCount: 3
        )
        ResearchProgressIndicator(
            action: "Read: Page Title (source.com)",
            sourceCount: 1
        )
        ResearchProgressIndicator(
            action: "Analyzing locally...",
            sourceCount: 0
        )
    }
    .padding()
    .background(Color.black.opacity(0.95))
}

