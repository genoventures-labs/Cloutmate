//
//  AuroraAuthorBadge.swift
//  FocusOS
//
//  Subtle pill indicating Aurora-authored content
//

import SwiftUI

struct AuroraAuthorBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption2)
            Text("Aurora")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [
                    Color.kosmicBlue.opacity(0.25),
                    Color.kosmicPurple.opacity(0.25)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .foregroundColor(.kosmicPurple)
        .clipShape(Capsule())
        .accessibilityLabel("Aurora authored")
    }
}


