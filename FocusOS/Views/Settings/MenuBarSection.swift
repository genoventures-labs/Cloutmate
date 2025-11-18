//
//  MenuBarSection.swift
//  FocusOS
//
//  Menu Bar settings section
//

import SwiftUI
import AppKit

struct MenuBarSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                openMenuBarApp()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.kosmicBlue)
                        .frame(width: 20)
                    Text("Open Menu Bar App")
                        .font(.body)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.kosmicBlue)
                }
            }
            .buttonStyle(.plain)
            
            Text("Access quick posting and upcoming posts from your menu bar.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func openMenuBarApp() {
        // Find and launch the menu bar app bundle
        let bundleURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("FocusOSMenuBar.app")
        
        // Check if the menu bar app exists
        if FileManager.default.fileExists(atPath: bundleURL.path) {
            // Try to open the app
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open(bundleURL, configuration: config) { (app, error) in
                if let _ = error {
                    // If opening fails, show instructions
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Unable to Open Menu Bar App"
                        alert.informativeText = """
                        To use the menu bar app, please:
                        
                        1. Build the FocusOSMenuBar target in Xcode
                        2. In Terminal, run:
                           sudo xattr -cr "\(bundleURL.path)"
                           codesign --force --deep --sign - "\(bundleURL.path)"
                        3. Then try opening it again
                        
                        Or run the menu bar app directly from Xcode.
                        """
                        alert.addButton(withTitle: "OK")
                        alert.addButton(withTitle: "Open in Finder")
                        let response = alert.runModal()
                        
                        if response == .alertSecondButtonReturn {
                            NSWorkspace.shared.selectFile(bundleURL.path, inFileViewerRootedAtPath: bundleURL.deletingLastPathComponent().path)
                        }
                    }
                }
            }
        } else {
            // Fallback: show alert if menu bar app not found
            let alert = NSAlert()
            alert.messageText = "Menu Bar App Not Found"
            alert.informativeText = "Please build the FocusOSMenuBar target in Xcode first."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

#Preview {
    MenuBarSection()
        .padding()
        .frame(width: 600)
}

