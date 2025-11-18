//
//  View+EscapeDismiss.swift
//  FocusOS
//
//  Convenience modifier to dismiss drawers on Escape.
//

import SwiftUI

extension View {
    func onEscape(_ action: @escaping () -> Void) -> some View {
        self.onKeyPress(.escape) {
            action()
            return .handled
        }
    }
}


