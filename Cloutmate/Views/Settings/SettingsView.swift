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
    @Query private var allPosts: [CloutmateShared.Post]
    @Query private var drafts: [Draft]
    @Query private var templates: [Template]
    
    @AppStorage("isBackgroundPostingEnabled") private var isBackgroundPostingEnabled = false
    @AppStorage("appearanceMode") private var appearanceModeRawValue = "system"
    
    @State private var showClearCacheConfirmation = false
    @State private var showExportDialog = false
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @EnvironmentObject private var accessibilityGlassManager: AccessibilityGlassManager
    @State private var aiSettings = AISettings.shared
    
    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }
    
    private func updateAppearance(_ mode: AppearanceMode) {
        appearanceModeRawValue = mode.rawValue
        applyAppearance(mode)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Glass Effects Preferences
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                            Text("Glass Effects")
                                .font(.headline)
                        }
                    )
                }) {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle(isOn: Binding(
                            get: { glassColorSystem.isTimeBasedShiftingEnabled },
                            set: { glassColorSystem.isTimeBasedShiftingEnabled = $0 }
                        )) {
                            HStack {
                                Image(systemName: "sunrise")
                                    .foregroundColor(.orange)
                                Text("Time-based color shifting")
                            }
                        }
                        
                        Picker("Performance Mode", selection: Binding(
                            get: { accessibilityGlassManager.performanceMode },
                            set: { accessibilityGlassManager.performanceMode = $0 }
                        )) {
                            ForEach(PerformanceMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        
                        Toggle(isOn: Binding(
                            get: { accessibilityGlassManager.reduceTransparency },
                            set: { accessibilityGlassManager.reduceTransparency = $0 }
                        )) {
                            HStack {
                                Image(systemName: "eye")
                                    .foregroundColor(.blue)
                                Text("Reduce Transparency")
                            }
                        }
                        
                        Toggle(isOn: Binding(
                            get: { accessibilityGlassManager.isAnimationsEnabled },
                            set: { accessibilityGlassManager.isAnimationsEnabled = $0 }
                        )) {
                            HStack {
                                Image(systemName: "play.circle")
                                    .foregroundColor(.green)
                                Text("Enable Animations")
                            }
                        }
                    }
                }
                
                // AI Assistant Settings
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.purple)
                            Text("AI Assistant")
                                .font(.headline)
                        }
                    )
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: Binding(
                            get: { aiSettings.isAIEnabled },
                            set: { aiSettings.isAIEnabled = $0 }
                        )) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.blue)
                                Text("Enable AI Features")
                            }
                        }
                        
                        Text("When enabled, AI features include: content brainstorming, hook generation, caption writing, text improvement, hashtag suggestions, and conversational AI chat.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Accounts section
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.blue)
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
                                .foregroundColor(.purple)
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
                                .foregroundColor(.green)
                            Text("Background Posting")
                                .font(.headline)
                        }
                    )
                }) {
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
                
                // Menu Bar App
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "menubar.rectangle")
                                .foregroundColor(.blue)
                            Text("Menu Bar")
                                .font(.headline)
                        }
                    )
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: {
                            openMenuBarApp()
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.blue)
                                Text("Open Menu Bar App")
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Text("Access quick posting and upcoming posts from your menu bar.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Appearance
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.purple)
                            Text("Appearance")
                                .font(.headline)
                        }
                    )
                }) {
                    Picker("Theme", selection: Binding(
                        get: { appearanceMode },
                        set: { updateAppearance($0) }
                    )) {
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
                    VStack(spacing: 12) {
                        Button(action: {
                            showClearCacheConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                                Text("Clear Cache")
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                        
                        Button(action: {
                            exportAllData()
                        }) {
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
                .alert("Clear Cache", isPresented: $showClearCacheConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Clear", role: .destructive) {
                        clearCache()
                    }
                } message: {
                    Text("This will remove all cached media files and temporary data. This cannot be undone.")
                }
                
                // About
                GlassCard(showHeader: true, headerContent: {
                    AnyView(
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("About")
                                .font(.headline)
                        }
                    )
                }) {
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
                        
                        Button(action: {
                            openSupport()
                        }) {
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
            .padding(28)
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Settings")
        .onAppear {
            applyAppearance(appearanceMode)
        }
    }
    
    private func applyAppearance(_ mode: AppearanceMode) {
        switch mode {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }
    
    private func clearCache() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for file in contents {
                try? fileManager.removeItem(at: file)
            }
        } catch {
            print("Failed to clear cache: \(error)")
        }
        
        // Clear media cache if exists
        if let cacheDir = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            do {
                let cacheContents = try fileManager.contentsOfDirectory(at: cacheDir.appendingPathComponent("Cloutmate"), includingPropertiesForKeys: nil)
                for file in cacheContents {
                    try? fileManager.removeItem(at: file)
                }
            } catch {
                // Cache directory doesn't exist yet, that's fine
            }
        }
    }
    
    private func exportAllData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "cloutmate-export-\(Date().formatted(date: .numeric, time: .omitted)).csv"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            var csvString = "Type,ID,Caption,Platform,Status,Scheduled Date,Published Date,Tags,Media URLs\n"
            
            // Export posts
            for post in allPosts {
                let escapedCaption = post.caption.replacingOccurrences(of: "\"", with: "\"\"")
                let platforms = post.postPlatforms.map { $0.displayName }.joined(separator: "|")
                let scheduledDate = post.scheduledDate?.ISO8601Format() ?? ""
                let publishedDate = post.publishedDate?.ISO8601Format() ?? ""
                let tags = post.tags.joined(separator: "|")
                let mediaURLs = post.mediaURLs.joined(separator: "|")
                
                csvString += "Post,\(post.id.uuidString),\"\(escapedCaption)\",\(platforms),\(post.postStatus.displayName),\(scheduledDate),\(publishedDate),\(tags),\(mediaURLs)\n"
            }
            
            // Export drafts
            for draft in drafts {
                let escapedCaption = draft.caption.replacingOccurrences(of: "\"", with: "\"\"")
                let tags = draft.tags.joined(separator: "|")
                let mediaURLs = draft.mediaURLs.joined(separator: "|")
                let updatedAt = draft.updatedAt.ISO8601Format()
                
                csvString += "Draft,\(draft.id.uuidString),\"\(escapedCaption)\",-,Draft,-,\(updatedAt),\(tags),\(mediaURLs)\n"
            }
            
            // Export templates
            for template in templates {
                let escapedCaption = template.caption.replacingOccurrences(of: "\"", with: "\"\"")
                let platforms = template.templatePlatforms.map { $0.displayName }.joined(separator: "|")
                let tags = template.tags.joined(separator: "|")
                
                csvString += "Template,\(template.id.uuidString),\"\(escapedCaption)\",\(platforms),Template,-,-,\(tags),-\n"
            }
            
            do {
                try csvString.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Export error: \(error)")
            }
        }
    }
    
    private func openSupport() {
        if let url = URL(string: "mailto:support@cloutmate.app?subject=Cloutmate Support Request") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openMenuBarApp() {
        // Find and launch the menu bar app bundle
        let bundleURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("CloutmateMenuBar.app")
        
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
                        
                        1. Build the CloutmateMenuBar target in Xcode
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
            alert.informativeText = "Please build the CloutmateMenuBar target in Xcode first."
            alert.addButton(withTitle: "OK")
            alert.runModal()
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

