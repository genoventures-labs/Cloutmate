//
//  ScrollToBottomButton.swift
//  FocusOS
//

import SwiftUI

struct ScrollToBottomButton: View {
    let isVisible: Bool
    let action: () -> Void
    
    var body: some View {
        if isVisible {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.headline)
                    Text("New Messages")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(18)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: isVisible)
        }
    }
}

