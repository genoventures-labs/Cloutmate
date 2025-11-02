//
//  SettingsView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import Combine
import CloutmateShared

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [PlatformAccount]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Glass Effects Preferences
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.kosmicPurple)
                            Text("Glass Effects")
                                .font(.headline)
                        }
                    )
                }) {
                    GlassEffectsSection()
                }
                
                // AI Assistant Settings
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.kosmicPurple)
                            Text("AI Assistant")
                                .font(.headline)
                        }
                    )
                }) {
                    AIAssistantSection()
                }
                
                // Accounts section
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.kosmicBlue)
                            Text("Connected Accounts")
                                .font(.headline)
                        }
                    )
                }) {
                    AccountsSection(accounts: accounts)
                }
                
                // Notion Integration
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "externaldrive.badge.icloud")
                                .foregroundColor(.kosmicPurple)
                            Text("Notion Integration")
                                .font(.headline)
                        }
                    )
                }) {
                    NotionIntegrationSection()
                }
                
                // Background posting
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "rectangle.stack.badge.play")
                                .foregroundColor(.kosmicGreen)
                            Text("Background Posting")
                                .font(.headline)
                        }
                    )
                }) {
                    BackgroundPostingSection()
                }
                
                // Menu Bar App
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "menubar.rectangle")
                                .foregroundColor(.kosmicBlue)
                            Text("Menu Bar")
                                .font(.headline)
                        }
                    )
                }) {
                    MenuBarSection()
                }
                
                // Appearance
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.kosmicPurple)
                            Text("Appearance")
                                .font(.headline)
                        }
                    )
                }) {
                    AppearanceSection()
                }
                
                // Permissions & Privacy
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.kosmicGreen)
                            Text("Permissions & Privacy")
                                .font(.headline)
                        }
                    )
                }) {
                    PermissionsPrivacySection()
                }
                
                // Notifications
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.yellow)
                            Text("Notifications")
                                .font(.headline)
                        }
                    )
                }) {
                    NotificationPreferencesSection()
                }
                
                // Data Management
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.orange)
                            Text("Data Management")
                                .font(.headline)
                        }
                    )
                }) {
                    DataManagementSection()
                }
                
                // About
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.kosmicBlue)
                            Text("About")
                                .font(.headline)
                        }
                    )
                }) {
                    AboutSection()
                }
            }
            .padding(28)
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [PlatformAccount.self])
}
