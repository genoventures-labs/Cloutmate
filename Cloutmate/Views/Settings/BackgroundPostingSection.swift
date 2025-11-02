//
//  BackgroundPostingSection.swift
//  Cloutmate
//
//  Background Posting settings section
//

import SwiftUI

struct BackgroundPostingSection: View {
    @AppStorage("isBackgroundPostingEnabled") private var isBackgroundPostingEnabled = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isBackgroundPostingEnabled) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                        .frame(width: 20)
                    Text("Enable background posting")
                        .font(.body)
                }
            }
            .onChange(of: isBackgroundPostingEnabled) { _, newValue in
                if newValue {
                    _ = LoginItemService.shared.enableLoginItem()
                } else {
                    _ = LoginItemService.shared.disableLoginItem()
                }
            }
            
            Text("Background posting ensures your scheduled posts are published even when the app is closed.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    BackgroundPostingSection()
        .padding()
        .frame(width: 600)
}

