//
//  FilterChip.swift
//  FocusOSMenuBar
//
//  FilterChip component matching Archives V2 design system
//

import SwiftUI
import FocusOSShared

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(backgroundStyle)
                .foregroundColor(textColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var backgroundStyle: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(glassColorSystem.buttonColor(for: .primary))
        } else {
            return AnyShapeStyle(glassColorSystem.cardColor())
        }
    }
    
    private var textColor: Color {
        isSelected ? .white : glassColorSystem.textPrimary()
    }
    
    private var borderColor: Color {
        if isSelected {
            return glassColorSystem.buttonColor(for: .primary).opacity(0.3)
        } else {
            return glassColorSystem.borderColor()
        }
    }
}

