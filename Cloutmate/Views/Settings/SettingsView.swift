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
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @StateObject private var themeManager = ReactiveThemeManager.shared
    @Query private var accounts: [PlatformAccount]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Glass Effects Preferences
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(glassColorSystem.emotionalAccent())
                            Text("Glass Effects")
                                .font(.headline)
                        }
                    )
                }) {
                    GlassEffectsSection()
                }

                // ARTE Quick Controls
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "circle.dashed.inset.filled")
                                .foregroundColor(glassColorSystem.emotionalAccent())
                            Text("Aurora Theme Engine")
                                .font(.headline)
                        }
                    )
                }) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Aurora Reactive Theme Engine")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(themeManager.isEnabled ? "ARTE is actively adapting your workspace." : "ARTE is currently disabled.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $themeManager.isEnabled)
                                .toggleStyle(.switch)
                                .onChange(of: themeManager.isEnabled) { _, newValue in
                                    handleArteToggleChange(newValue)
                                }
                        }
                        .padding(.vertical, 4)

                        if themeManager.isEnabled {
                            HStack(spacing: 12) {
                                Image(systemName: themeManager.currentState.iconName)
                                    .font(.system(size: 24))
                                    .foregroundColor(glassColorSystem.emotionalAccent())
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(glassColorSystem.emotionalAccent().opacity(0.12))
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(themeManager.currentState.displayName)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Confidence \(Int(themeManager.confidence * 100))% | Intensity \(Int(themeManager.intensity * 100))%")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(glassColorSystem.emotionalAccent().opacity(0.12))
                            )
                        }

                        Divider()
                            .background(glassColorSystem.dividerColor())

                        NavigationLink {
                            ARTESettingsView()
                                .navigationTitle("Aurora Theme Engine")
                        } label: {
                            HStack {
                                Spacer()
                                Text("Open Full ARTE Controls")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
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
                
                // Rituals & Nudges
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.kosmicBlue)
                            Text("Rituals & Nudges")
                                .font(.headline)
                        }
                    )
                }) {
                    VStack(alignment: .leading, spacing: 16) {
                        let settings = RitualSettings.shared
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Morning Ritual")
                                .font(.subheadline.weight(.semibold))
                            Text(formatTime(settings.morningTime))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Evening Reflection")
                                .font(.subheadline.weight(.semibold))
                            Text(formatTime(settings.eveningTime))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Weekly Review")
                                .font(.subheadline.weight(.semibold))
                            Text("\(weekdayName(settings.weeklyReviewDay)) \(formatTime(settings.weeklyReviewTime))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Smart Nudges")
                                .font(.subheadline.weight(.semibold))
                            Text(settings.nudgesEnabled ? "Enabled" : "Disabled")
                                .font(.footnote)
                                .foregroundColor(settings.nudgesEnabled ? .kosmicGreen : .secondary)
                        }

                        NavigationLink {
                            RitualSettingsView()
                                .navigationTitle("Rituals & Nudges")
                        } label: {
                            HStack {
                                Spacer()
                                Text("Open Ritual Controls")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Accounts section
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "brain.head.profile.fill")
                                .foregroundColor(.kosmicPurple)
                            Text("Predictive Cognition")
                                .font(.headline)
                        }
                    )
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Aurora predicts focus patterns and adapts proactively")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        NavigationLink {
                            PredictiveCognitionSettingsView()
                                .navigationTitle("Predictive Cognition")
                        } label: {
                            HStack {
                                Spacer()
                                Text("Configure Predictions")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "hourglass.circle")
                                .foregroundColor(.kosmicBlue)
                            Text("Temporal Intelligence")
                                .font(.headline)
                        }
                    )
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Adaptive scheduling, calendar sync, and guardrails for focus transitions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        NavigationLink {
                            TemporalIntelligenceSettingsView()
                                .navigationTitle("Temporal Intelligence")
                        } label: {
                            HStack {
                                Spacer()
                                Text("Open Temporal Controls")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Social media account connections are no longer available.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if !accounts.isEmpty {
                            Text("\(accounts.count) account(s) connected (legacy)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Background posting is no longer available. Social media posting has been removed.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
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
                
                // Flow Companion Settings
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                            Text("Flow Companion")
                                .font(.headline)
                        }
                    )
                }) {
                    FlowCompanionSettingsSection()
                }
            }
            .padding(28)
        }
        .background(
            ZStack {
                glassColorSystem.backgroundColor()
                glassColorSystem.emotionalBackgroundShift()
            }
            .ignoresSafeArea()
        )
        .navigationTitle("Settings")
    }
}

private extension SettingsView {
    func formatTime(_ components: DateComponents) -> String {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute
        let date = Calendar.current.date(from: dateComponents) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday - 1))
        return symbols[index]
    }

    func handleArteToggleChange(_ newValue: Bool) {
        glassColorSystem.isARTEEnabled = newValue
        themeManager.saveConfiguration(modelContext: modelContext)
        if newValue {
            themeManager.restart(modelContext: modelContext)
        } else {
            themeManager.stop()
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [PlatformAccount.self])
}
