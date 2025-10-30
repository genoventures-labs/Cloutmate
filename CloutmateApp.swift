//
//  CloutmateApp.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import Combine

@main
struct CloutmateApp: App {
    @State private var selectedTab: TabIdentifier = .home
    @State private var publishingTimer: Timer?
    @StateObject private var glassColorSystem = GlassColorSystem()
    @StateObject private var accessibilityGlassManager = AccessibilityGlassManager()
    
    var sharedModelContainer: ModelContainer = SharedDataManager.createSharedModelContainer()

    var body: some Scene {
            WindowGroup {
                ContentView()
                    .environmentObject(glassColorSystem)
                    .environmentObject(accessibilityGlassManager)
                    .onAppear {
                        startPublishingTimer()
                    }
            }
            .modelContainer(sharedModelContainer)
            .defaultSize(width: 900, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Post") {
                    NotificationCenter.default.post(name: .openComposer, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .sidebar) {
                Divider()
                
                Button("Home") {
                    NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.home)
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("Calendar") {
                    NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.calendar)
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button("Posts") {
                    NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.posts)
                }
                .keyboardShortcut("3", modifiers: .command)
                
                Button("Drafts") {
                    NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.drafts)
                }
                .keyboardShortcut("4", modifiers: .command)
                
                Button("AI Assistant") {
                    NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.aiAssistant)
                }
                .keyboardShortcut("5", modifiers: .command)
                
                Button("Insights") {
                    NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.insights)
                }
                .keyboardShortcut("6", modifiers: .command)
                
                Button("Settings") {
                    NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.settings)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.toolbar) {
                // Add toolbar commands if needed
            }
        }
    }
    
    private func startPublishingTimer() {
        // Check for posts to publish every 60 seconds
        publishingTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            NotificationCenter.default.post(name: .checkPublishing, object: nil)
        }
    }
}

extension Notification.Name {
    static let switchTab = Notification.Name("switchTab")
    static let openComposer = Notification.Name("openComposer")
    static let checkPublishing = Notification.Name("checkPublishing")
    static let appWillBecomeActive = Notification.Name("appWillBecomeActive")
}

