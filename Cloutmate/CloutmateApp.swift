//
//  CloutmateApp.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import Combine
import AppKit
import CloutmateShared
import os.log
import Carbon

@main
struct CloutmateApp: App {
    @State private var selectedTab: TabIdentifier = .home
    @State private var publishingTimer: Timer?
    @StateObject private var glassColorSystem = GlassColorSystem()
    @StateObject private var accessibilityGlassManager = AccessibilityGlassManager()
    @StateObject private var distributedNotificationManager: DistributedNotificationManager
    
    static let sharedModelContainer: ModelContainer = CloutmateApp.createAppModelContainer()

    init() {
        _distributedNotificationManager = StateObject(wrappedValue: DistributedNotificationManager(modelContainer: CloutmateApp.sharedModelContainer))
    }

    var body: some Scene {
            WindowGroup {
                ContentView()
                    .environmentObject(glassColorSystem)
                    .environmentObject(accessibilityGlassManager)
                    .environmentObject(distributedNotificationManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                    .onAppear {
                        startPublishingTimer()
                        checkAndRunMigration()
                        registerGlobalHotkey()
                    }
            }
            .modelContainer(CloutmateApp.sharedModelContainer)
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
    }
    
    private func startPublishingTimer() {
        publishingTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            checkAndPublishScheduledPosts()
        }
    }
    
    private func checkAndPublishScheduledPosts() {
        _Concurrency.Task { @MainActor in
            let context = CloutmateApp.sharedModelContainer.mainContext
            let descriptor = FetchDescriptor<Post>(
                predicate: #Predicate { 
                    $0.status == "scheduled" 
                }
            )
            
            guard let scheduledPosts = try? context.fetch(descriptor) else { return }
            let now = Date()
            
            for post in scheduledPosts where post.scheduledDate ?? Date.distantFuture <= now {
                await PublishingService.shared.publishPost(post, context: context)
            }
        }
    }
    
    private func checkAndRunMigration() {
        _Concurrency.Task {
            // Check if migration needed
            if !UserDefaults.standard.bool(forKey: "phase3_migrated") {
                do {
                    try await MigrationService.shared.migrateExistingData(
                        context: CloutmateApp.sharedModelContainer.mainContext
                    )
                    UserDefaults.standard.set(true, forKey: "phase3_migrated")
                    os_log("Phase 3 migration completed successfully", log: .default, type: .info)
                } catch {
                    os_log("Migration failed: %{public}@", log: .default, type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    private func registerGlobalHotkey() {
        do {
            var hotKeyRef: EventHotKeyRef?
            let keyCode = UInt32(kVK_Space)
            let modifiers = UInt32(optionKey)
            
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            
            let handlerStatus = InstallEventHandler(
                GetApplicationEventTarget(),
                { _, _, _ in
                    _Concurrency.Task { @MainActor in
                        QuickCaptureWindowController.shared.show()
                    }
                    return noErr
                },
                1,
                &eventType,
                nil,
                nil
            )
            
            guard handlerStatus == noErr else {
                print("Failed to install event handler")
                return
            }
            
            let registerStatus = RegisterEventHotKey(
                keyCode,
                modifiers,
                EventHotKeyID(signature: OSType(("CLMT" as NSString).utf8String!.pointee), id: 1),
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            
            guard registerStatus == noErr else {
                print("Failed to register hotkey")
                return
            }
            
            print("Global hotkey ⌥Space registered successfully")
        }
    }
}

extension CloutmateApp {
    static func createAppModelContainer() -> ModelContainer {
        let schema = Schema([
            // Shared models used in the app (publicly accessible)
            CloutmateShared.Post.self,
            CloutmateShared.Draft.self,
            CloutmateShared.Template.self,
            CloutmateShared.PlatformAccount.self,
            CloutmateShared.PerformancePrediction.self,
            CloutmateShared.RecyclablePost.self,
            CloutmateShared.ContentTopic.self,
            CloutmateShared.ContentBalance.self,
            CloutmateShared.PostingTimeTest.self,
            CloutmateShared.OptimalPostingTime.self,
            CloutmateShared.CustomPostProperty.self,
            CloutmateShared.PostView.self,
            CloutmateShared.HashtagPerformance.self,
            CloutmateShared.HashtagSet.self,
            // App-local PARA models for dashboard cards
            Note.self,
            Task.self,
            Project.self,
            InboxItem.self,
            // App-specific models
            DashboardCard.self
        ])
        
        let appGroupID = "group.kosmicapps.cloutmate"
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("Unable to access app group container")
        }
        // Bump the store filename to force schema recreation after adding new models
        let storeURL = appGroupURL.appendingPathComponent("Cloutmate_v2.sqlite")
        
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}

// Manager to handle distributed notifications from menu bar
class DistributedNotificationManager: ObservableObject {
    private var observer: NSObjectProtocol?
    let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        // Use the app's container to ensure schema/file match
        self.modelContainer = modelContainer
        setupNotifications()
    }
    
    func setupNotifications() {
        let center = DistributedNotificationCenter.default
        
        // Listen for post creation
        center.addObserver(
            forName: NSNotification.Name("CloutmatePostCreated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("Received CloutmatePostCreated notification: \(notification.userInfo ?? [:])")
            self?.refreshViews()
        }
        
        // Listen for post published
        center.addObserver(
            forName: NSNotification.Name("CloutmatePostPublished"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("Received CloutmatePostPublished notification: \(notification.userInfo ?? [:])")
            self?.refreshViews()
        }
        
        // Listen for post failed
        center.addObserver(
            forName: NSNotification.Name("CloutmatePostFailed"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("Received CloutmatePostFailed notification: \(notification.userInfo ?? [:])")
            self?.refreshViews()
        }
    }
    
    func refreshViews() {
        // Post notification to refresh views
        NotificationCenter.default.post(name: NSNotification.Name("RefreshViewsFromMenuBar"), object: nil)
    }
    
    deinit {
        if let observer = observer {
            DistributedNotificationCenter.default.removeObserver(observer)
        }
    }
}
