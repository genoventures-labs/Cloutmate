//
//  ToolbarButtonStyle.swift
//  FocusOS
//
//  Standardized toolbar button style with ARTE tinting and micro-feedback
//

import SwiftUI

struct ToolbarButtonStyle: ButtonStyle {
    var tintColor: Color
    var isDisabled: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isDisabled ? Color.secondary.opacity(0.5) : tintColor)
            .opacity(configuration.isPressed ? 0.6 : 0.8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

