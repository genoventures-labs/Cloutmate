//
//  UnifiedFocusModeView.swift
//  FocusOS
//
//  Focus Mode V2 - Unified Main View
//  Wrapper that uses the new FocusModeView
//

import SwiftUI
import SwiftData
import FocusOSShared

struct UnifiedFocusModeView: View {
    var body: some View {
        FocusModeView()
    }
}

#Preview {
    UnifiedFocusModeView()
        .environmentObject(GlassColorSystem())
        .modelContainer(for: [FocusSession.self])
}
