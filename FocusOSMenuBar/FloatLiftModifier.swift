//
//  FloatLiftModifier.swift
//  FocusOSMenuBar
//
//  Float lift effect modifier
//

import SwiftUI

extension View {
    func floatLift() -> some View {
        modifier(FloatLiftEffect())
    }
}

struct FloatLiftEffect: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.015 : 1.0)
            .shadow(
                color: .black.opacity(isHovered ? 0.15 : 0.05),
                radius: isHovered ? 12 : 4,
                y: isHovered ? 8 : 2
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

