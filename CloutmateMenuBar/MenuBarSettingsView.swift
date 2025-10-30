//
//  MenuBarSettingsView.swift
//  CloutmateMenuBar
//

import SwiftUI
import WidgetKit

struct MenuBarSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // App info
                VStack(spacing: 12) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Cloutmate")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Quick post scheduling")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                Divider()
                
                // Actions
                VStack(spacing: 12) {
                    Button(action: {
                        // Open main app - use direct bundle identifier launch
                        let bundleID = "com.kosmicapps.Cloutmate"
                        
                        // Open main app using the most reliable method
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "app.badge")
                            Text("Open Main App")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        // Refresh widget
                        WidgetCenter.shared.reloadTimelines(ofKind: "CloutmateWidget")
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Widget")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}

#Preview {
    MenuBarSettingsView()
}

