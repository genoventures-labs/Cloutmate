//
//  AboutSection.swift
//  Cloutmate
//
//  About settings section
//

import SwiftUI
import AppKit

struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text("1")
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Button(action: {
                openSupport()
            }) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.kosmicBlue)
                    Text("Support & Feedback")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private func openSupport() {
        if let url = URL(string: "mailto:support@cloutmate.app?subject=Cloutmate Support Request") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    AboutSection()
        .padding()
        .frame(width: 600)
}

