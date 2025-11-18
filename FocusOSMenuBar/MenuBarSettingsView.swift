//
//  MenuBarSettingsView.swift
//  FocusOSMenuBar
//

import SwiftUI
import WidgetKit
import FocusOSShared

struct MenuBarSettingsView: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Section
                VStack(spacing: 12) {
                    Text("FocusOS")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 72/255, green: 131/255, blue: 255/255), // kosmicBlue
                                    Color(red: 124/255, green: 77/255, blue: 255/255)  // kosmicPurple
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Quick access to your workspace")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(glassColorSystem.textSecondary())
                }
                .padding(.top, 40)
                
                Divider()
                    .background(glassColorSystem.borderColor())
                
                // Actions
                VStack(spacing: 12) {
                    GlassButton(
                        "Open Main App",
                        icon: "app.badge",
                        style: .pill,
                        role: .primary
                    ) {
                        // Open main app - use direct bundle identifier launch
                        let bundleID = "com.kosmicapps.FocusOS"
                        
                        // Open main app using the most reliable method
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    GlassButton(
                        "Refresh Widget",
                        icon: "arrow.clockwise",
                        style: .pill,
                        role: .surface
                    ) {
                        // Refresh widget
                        WidgetCenter.shared.reloadTimelines(ofKind: "FocusOSWidget")
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    MenuBarSettingsView()
}

