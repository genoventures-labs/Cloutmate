//
//  SettingsView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [PlatformAccount]
    
    @State private var isBackgroundPostingEnabled = false
    @State private var appearanceMode: AppearanceMode = .system
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Accounts section
                SettingsCard(title: "Connected Accounts", icon: "person.crop.circle") {
                    AccountsSection(accounts: accounts)
                }
                
                // Background posting
                SettingsCard(title: "Background Posting", icon: "rectangle.stack.badge.play") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $isBackgroundPostingEnabled) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.yellow)
                                Text("Enable background posting")
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
                    }
                }
                
                // Appearance
                SettingsCard(title: "Appearance", icon: "paintbrush.fill") {
                    Picker("Theme", selection: $appearanceMode) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                            Text("Light")
                        }.tag(AppearanceMode.light)
                        
                        HStack {
                            Image(systemName: "moon.fill")
                            Text("Dark")
                        }.tag(AppearanceMode.dark)
                        
                        HStack {
                            Image(systemName: "circle.lefthalf.filled")
                            Text("System")
                        }.tag(AppearanceMode.system)
                    }
                }
                
                // Notifications
                SettingsCard(title: "Notifications", icon: "bell.fill") {
                    VStack(spacing: 12) {
                        Toggle(isOn: .constant(true)) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Post published")
                            }
                        }
                        
                        Toggle(isOn: .constant(true)) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Post failed")
                            }
                        }
                        
                        Toggle(isOn: .constant(false)) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.blue)
                                Text("Insights updated")
                            }
                        }
                    }
                }
                
                // Data Management
                SettingsCard(title: "Data Management", icon: "folder.fill") {
                    VStack(spacing: 12) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                                Text("Clear Cache")
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "square.and.arrow.up.fill")
                                    .foregroundColor(.blue)
                                Text("Export All Data")
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // About
                SettingsCard(title: "About", icon: "info.circle.fill") {
                    VStack(spacing: 12) {
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
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Support & Feedback")
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Settings")
        .onAppear {
            isBackgroundPostingEnabled = LoginItemService.shared.isLoginItemEnabled()
        }
    }
}

enum AppearanceMode: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
}

#Preview {
    SettingsView()
        .modelContainer(for: [PlatformAccount.self])
}

