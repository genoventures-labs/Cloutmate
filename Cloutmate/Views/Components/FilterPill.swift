//
//  FilterPill.swift
//  Cloutmate
//
//  Shared Filter Pill Component
//

import SwiftUI
import CloutmateShared

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? LinearGradient(
                                    colors: [Color.kosmicBlue, Color.kosmicPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [glassColorSystem.cardColor(), glassColorSystem.cardColor()],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                )
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.clear : glassColorSystem.borderColor(),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(GlassMotion.Easing.spring, value: isSelected)
    }
}

#Preview {
    HStack {
        FilterPill(title: "All", isSelected: true, action: {})
        FilterPill(title: "Filter", isSelected: false, action: {})
    }
    .padding()
    .environmentObject(GlassColorSystem())
}

