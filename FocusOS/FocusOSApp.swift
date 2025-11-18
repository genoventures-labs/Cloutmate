//
//  FocusOSApp.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import Combine
import AppKit
import FocusOSShared
import os.log
import Carbon

typealias PostStatus = FocusOSShared.PostStatus

@main
struct FocusOSApp: App {
    @State private var selectedTab: TabIdentifier = .home
    @State private var publishingTimer: Timer?
    @StateObject private var glassColorSystem = GlassColorSystem()
    @StateObject private var accessibilityGlassManager = AccessibilityGlassManager()
    @StateObject private var distributedNotificationManager: DistributedNotificationManager
    @StateObject private var themeManager = ReactiveThemeManager.shared
    @StateObject private var focusRitualManager = FocusRitualManager.shared
    @StateObject private var smartNudgeService = SmartNudgeService.shared
    @State private var ritualsStarted = false
    
    static let sharedModelContainer: ModelContainer = FocusOSApp.createAppModelContainer()

    init() {
        _distributedNotificationManager = StateObject(wrappedValue: DistributedNotificationManager(modelContainer: FocusOSApp.sharedModelContainer))
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
                        startRitualSystemsIfNeeded()
                        startAIFlowCompanion()
                        startFlowCompanionEngine()
                        // Clear routing engine cooldown on app start to ensure fresh model selection
                        _Concurrency.Task {
                            await ModelRoutingEngine.shared.clearCooldown()
                        }
                        // Start ARTE after other systems
                        _Concurrency.Task { @MainActor in
                            try? await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds to ensure SwiftData is ready
                            startARTE()
                        }
                        // Perform hybrid bridge health check (core implementation)
                        _Concurrency.Task {
                            let apiKey = AISettings.shared.ollamaCloudAPIKey
                            _ = await HybridBridgeService.shared.performHealthCheck(apiKey: apiKey)
                        }
                    }
            }
            .modelContainer(FocusOSApp.sharedModelContainer)
            .defaultSize(width: 900, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Artifact") {
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
                
                Button("Artifacts") {
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
            
            // Aurora Toolbar Commands (⌘⇧1-6)
            CommandGroup(after: .textEditing) {
                Divider()
                
                Button("Create Task") {
                    NotificationCenter.default.post(name: NSNotification.Name("AuroraToolbarAction"), object: ToolbarAction.createTask)
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])
                
                Button("Create Project") {
                    NotificationCenter.default.post(name: NSNotification.Name("AuroraToolbarAction"), object: ToolbarAction.createProject)
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])
                
                Button("Create Note") {
                    NotificationCenter.default.post(name: NSNotification.Name("AuroraToolbarAction"), object: ToolbarAction.createNote)
                }
                .keyboardShortcut("3", modifiers: [.command, .shift])
                
                Button("Create Reminder") {
                    NotificationCenter.default.post(name: NSNotification.Name("AuroraToolbarAction"), object: ToolbarAction.createReminder)
                }
                .keyboardShortcut("4", modifiers: [.command, .shift])
                
                Button("Analyze Document") {
                    NotificationCenter.default.post(name: NSNotification.Name("AuroraToolbarAction"), object: ToolbarAction.analyzeDocument)
                }
                .keyboardShortcut("5", modifiers: [.command, .shift])
                
                Button("Analyze Image") {
                    NotificationCenter.default.post(name: NSNotification.Name("AuroraToolbarAction"), object: ToolbarAction.analyzeImage)
                }
                .keyboardShortcut("6", modifiers: [.command, .shift])
            }
        }
    }
    
    private func startPublishingTimer() {
        publishingTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            checkAndPublishScheduledPosts()
        }
    }

    private func startRitualSystemsIfNeeded() {
        guard !ritualsStarted else { return }
        ritualsStarted = true
        let context = FocusOSApp.sharedModelContainer.mainContext
        focusRitualManager.start(modelContext: context)
        smartNudgeService.start(modelContext: context)

        // Enable predictive mode by default if not set
        if UserDefaults.standard.object(forKey: "predictiveModeEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "predictiveModeEnabled")
        }
        
        if UserDefaults.standard.bool(forKey: "predictiveModeEnabled") {
            _Concurrency.Task { @MainActor in
                await CognitionPredictor.shared.start(modelContext: context)
                await DriftMonitor.shared.start(modelContext: context)
                await PredictiveContextManager.shared.start(modelContext: context)
                        await AdaptiveScheduler.shared.start(modelContext: context)
                        if CalendarSyncSettings.shared.syncEnabled {
                            await CalendarSyncService.shared.start(modelContext: context)
                        }
                        if ContextGuardSettings.shared.isGuardEnabled {
                            ContextSwitchGuard.shared.start(modelContext: context)
                        }
                    }
                }
                
                // Start Calendar Cognition services
                _Concurrency.Task { @MainActor in
                    let context = FocusOSApp.sharedModelContainer.mainContext
                    AuroraCalendarCognitionService.shared.start(modelContext: context)
                    ColorUpdateScheduler.shared.start(modelContext: context)
                }
        }
    
    private func checkAndPublishScheduledPosts() {
        // Note: Social media posting was removed, so scheduled posts are no longer published automatically
        // This function is kept for compatibility but does not perform actual publishing
        _Concurrency.Task { @MainActor in
            let context = FocusOSApp.sharedModelContainer.mainContext
            let descriptor = FetchDescriptor<Post>(
                predicate: #Predicate { 
                    $0.status == "scheduled" 
                }
            )
            
            guard let scheduledPosts = try? context.fetch(descriptor) else { return }
            let now = Date()
            
            for post in scheduledPosts where post.scheduledDate ?? Date.distantFuture <= now {
                post.postStatus = .failed
                post.lastError = "Social media posting has been removed. Use artifacts instead."
                try? context.save()
            }
        }
    }
    
    private func checkAndRunMigration() {
        _Concurrency.Task {
            // First, migrate from Cloutmate to FocusOS (if needed)
            do {
                os_log("Starting Cloutmate migration...", log: .default, type: .info)
                try await MigrationService.shared.migrateFromCloutmate(
                    context: FocusOSApp.sharedModelContainer.mainContext
                )
                os_log("Cloutmate migration completed successfully", log: .default, type: .info)
            } catch {
                os_log("Cloutmate migration failed: %{public}@", log: .default, type: .error, error.localizedDescription)
                os_log("Migration error details: %@", log: .default, type: .error, String(describing: error))
                
                // Log to console for debugging
                print("⚠️ Cloutmate migration failed: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   Domain: \(nsError.domain), Code: \(nsError.code)")
                    print("   UserInfo: \(nsError.userInfo)")
                }
            }
            
            // Check if migration needed
            if !UserDefaults.standard.bool(forKey: "phase3_migrated") {
                do {
                    try await MigrationService.shared.migrateExistingData(
                        context: FocusOSApp.sharedModelContainer.mainContext
                    )
                    UserDefaults.standard.set(true, forKey: "phase3_migrated")
                    os_log("Phase 3 migration completed successfully", log: .default, type: .info)
                } catch {
                    os_log("Migration failed: %{public}@", log: .default, type: .error, error.localizedDescription)
                }
            }
            
            if !UserDefaults.standard.bool(forKey: "note_author_migrated") {
                do {
                    try await MigrationService.shared.applyAuthorMetadataAndCleanup(
                        context: FocusOSApp.sharedModelContainer.mainContext
                    )
                    UserDefaults.standard.set(true, forKey: "note_author_migrated")
                    os_log("Author metadata migration completed successfully", log: .default, type: .info)
                } catch {
                    os_log("Author metadata migration failed: %{public}@", log: .default, type: .error, error.localizedDescription)
                }
            }
            
            if !UserDefaults.standard.bool(forKey: "project_external_fields_migrated") {
                do {
                    try await MigrationService.shared.migrateProjectExternalFields(
                        context: FocusOSApp.sharedModelContainer.mainContext
                    )
                    os_log("Project external fields migration completed successfully", log: .default, type: .info)
                } catch {
                    os_log("Project external fields migration failed: %{public}@", log: .default, type: .error, error.localizedDescription)
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
                EventHotKeyID(signature: OSType(("FOCS" as NSString).utf8String!.pointee), id: 1),
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            
            guard registerStatus == noErr else {
                print("Failed to register hotkey")
                return
            }
            
            print("Global hotkey ⌥Space registered successfully")
            
            // Register Cmd+Shift+A for Aurora Spotlight
            var spotlightHotKeyRef: EventHotKeyRef?
            let spotlightKeyCode = UInt32(kVK_ANSI_A)
            let spotlightModifiers = UInt32(cmdKey | shiftKey)
            
            var spotlightEventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            
            let spotlightHandlerStatus = InstallEventHandler(
                GetApplicationEventTarget(),
                { _, _, _ in
                    _Concurrency.Task { @MainActor in
                        AuroraSpotlightWindowController.shared.toggle()
                    }
                    return noErr
                },
                1,
                &spotlightEventType,
                nil,
                nil
            )
            
            guard spotlightHandlerStatus == noErr else {
                print("Failed to install Aurora Spotlight event handler")
                return
            }
            
            let spotlightRegisterStatus = RegisterEventHotKey(
                spotlightKeyCode,
                spotlightModifiers,
                EventHotKeyID(signature: OSType(("FOCS" as NSString).utf8String!.pointee), id: 2),
                GetApplicationEventTarget(),
                0,
                &spotlightHotKeyRef
            )
            
            guard spotlightRegisterStatus == noErr else {
                print("Failed to register Aurora Spotlight hotkey")
                return
            }
            
            print("Global hotkey ⌘⇧A (Aurora Spotlight) registered successfully")
        }
    }
    
    // MARK: - ARTE Integration (Phase 7)
    
    private func startARTE() {
        _Concurrency.Task { @MainActor in
            // Start ReactiveThemeManager
            let context = FocusOSApp.sharedModelContainer.mainContext
            themeManager.start(modelContext: context)
            glassColorSystem.updateEmotionalState(themeManager.currentState, intensity: themeManager.intensity)
            glassColorSystem.emotionalIntensity = themeManager.intensity
            SidebarToneSyncService.shared.prime(with: themeManager.currentState, intensity: themeManager.intensity)
            
            // Initialize AECI
            let aecIndex = await EmotionalContinuityEngine.shared.getCurrentAECI(modelContext: context)
            let aecHistory = await EmotionalContinuityEngine.shared.calculateWeeklyAECI(modelContext: context)
            if let history = aecHistory {
                glassColorSystem.updateAECI(history.aecIndex, category: history.category)
            } else {
                glassColorSystem.updateAECI(aecIndex, category: .neutral)
            }
            
            // Initialize ERI
            let eriIndex = await AuroraEcosphericLayer.shared.getCurrentERI(modelContext: context)
            let eriHistory = await AuroraEcosphericLayer.shared.calculateERI(modelContext: context)
            if let history = eriHistory {
                glassColorSystem.updateERI(history.eriIndex, category: history.category)
            } else {
                glassColorSystem.updateERI(eriIndex, category: .neutral)
            }
            
            // Initialize ERS
            let ersIndex = await AuroraMetaSymphony.shared.getCurrentERS(modelContext: context)
            let ersHistory = await AuroraMetaSymphony.shared.calculateERS(modelContext: context)
            if let history = ersHistory {
                glassColorSystem.updateERS(history.ersIndex, category: history.category)
            } else {
                glassColorSystem.updateERS(ersIndex, category: .neutral)
            }
            
            // Initialize Luminance Field
            let lfIndex = await AuroraLuminara.shared.getCurrentLF(modelContext: context)
            _ = await AuroraLuminara.shared.calculateLuminanceField(modelContext: context)
            
            // Subscribe to theme changes to update GlassColorSystem
            // Debounce to prevent rapid UI update cycles
            themeManager.$currentState
                .removeDuplicates()
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                .sink { [weak glassColorSystem] state in
                    glassColorSystem?.updateEmotionalState(state, intensity: themeManager.intensity)
                    SidebarToneSyncService.shared.prime(with: state, intensity: themeManager.intensity)
                }
                .store(in: &themeManager.cancellables)
            
            // Subscribe to intensity changes (debounced to prevent cycles)
            themeManager.$intensity
                .removeDuplicates()
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                .sink { [weak glassColorSystem] intensity in
                    glassColorSystem?.emotionalIntensity = intensity
                }
                .store(in: &themeManager.cancellables)
            
            // Update GlassMotion animation speed
            themeManager.$currentState
                .sink { state in
                    let palette = EmotionalPalette.palette(for: state)
                    GlassMotion.emotionalSpeedMultiplier = palette.animationSpeed
                }
                .store(in: &themeManager.cancellables)
            
            os_log("ARTE: Integration complete - reactive theme system active", log: .default, type: .info)
        }
    }
    
    // MARK: - AI Flow Companion Integration
    
    private func startAIFlowCompanion() {
        _Concurrency.Task { @MainActor in
            let context = FocusOSApp.sharedModelContainer.mainContext
            AIFlowCompanion.shared.start(modelContext: context)
            os_log("AI Flow Companion started", log: .default, type: .info)
        }
    }
    
    private func startFlowCompanionEngine() {
        _Concurrency.Task { @MainActor in
            let context = FocusOSApp.sharedModelContainer.mainContext
            FlowCompanionEngine.shared.start(modelContext: context)
            os_log("Flow Companion Engine started", log: .default, type: .info)
        }
    }
}

extension FocusOSApp {
    static func createAppModelContainer() -> ModelContainer {
        let schema = Schema([
            // Shared models used in the app (publicly accessible)
            FocusOSShared.Post.self,
            FocusOSShared.Artifact.self,  // New Artifact model for cognitive workspace
            FocusOSShared.ArtifactMention.self,  // Artifact mentions tracking
            Draft.self,  // Draft is app-local, not in FocusOSShared
            FocusOSShared.Template.self,
            FocusOSShared.PerformancePrediction.self,
            FocusOSShared.RecyclablePost.self,
            FocusOSShared.ContentTopic.self,
            FocusOSShared.ContentBalance.self,
            FocusOSShared.PostingTimeTest.self,
            FocusOSShared.OptimalPostingTime.self,
            FocusOSShared.CustomPostProperty.self,
            FocusOSShared.PostView.self,
            FocusOSShared.HashtagPerformance.self,
            FocusOSShared.HashtagSet.self,
            // Shared PARA models (used by dashboard cards and other features)
            FocusOSShared.Note.self,
            FocusOSShared.Task.self,
            FocusOSShared.Project.self,
            FocusOSShared.InboxItem.self,
            FocusOSShared.Reminder.self,
            // App-local PARA models
            Area.self,
            // App-specific models
            DashboardCard.self,
            AIMessage.self,
            AIConversation.self,
            ConversationDigest.self,
            UserPreferences.self,
            InsightSnapshot.self,
            Journal.self,
            Campaign.self,
            PARATemplate.self,
            // AI & Phase 3-5 models
            RecallIndexEntry.self,
            AIFeedbackEvent.self,
            PriorityScore.self,
            FocusSession.self,
            ConceptNode.self,
            StoryToken.self,
            // AI & Phase 6 models
            MemoryNode.self,
            MemoryEdge.self,
            ThemeNode.self,
            // AI & Phase 6.1 models
            WorkflowPattern.self,
            AutomationRule.self,
            WorkflowTemplate.self,
            // AI & Phase 7 models (ARTE)
            ARTEConfiguration.self,
            StateTransitionHistory.self,
            // Phase 8 models (Rituals)
            FocusRitual.self,
            RitualCompletion.self,
            WeeklyReview.self,
            SmartNudge.self,
            // Tone prediction feedback
            ToneForecastMetrics.self,
            ToneReliabilityProfile.self,
            EmotionEpoch.self,
            AECIHistory.self,
            ERIHistory.self,
            ERSHistory.self,
            LFHistory.self,
            // Phase 9 models (Predictive Cognition)
            FocusForecast.self,
            DriftEvent.self,
            EnergyWindow.self,
            // Calendar Cognition models
            EventColorReason.self,
            FocusOSShared.CalendarEvent.self,
            // Archives V2 models
            ArchiveReflection.self,
            // Context-aware create sheet models
            CreateActionUsage.self,
            // Hybrid Bridge models
            PerformanceMemory.self,
            // Missing Integrations models
            FlowCompanionState.self,
            StoryArc.self,
            StoryChapter.self,
            StoryScene.self,
            MoodEntry.self,
            ReflectionNote.self,
            MemorySummary.self,
            AuroraSelfDiagnostic.self
        ])
        
        let appGroupID = "group.kosmicapps.focusos"
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("Unable to access app group container")
        }
        // Bump the store filename to force schema recreation after adding new models
        let storeURL = appGroupURL.appendingPathComponent("FocusOS_v3.sqlite")
        
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
            forName: NSNotification.Name("FocusOSPostCreated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("Received FocusOSPostCreated notification: \(notification.userInfo ?? [:])")
            self?.refreshViews()
        }
        
        // Listen for post published
        center.addObserver(
            forName: NSNotification.Name("FocusOSPostPublished"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("Received FocusOSPostPublished notification: \(notification.userInfo ?? [:])")
            self?.refreshViews()
        }
        
        // Listen for post failed
        center.addObserver(
            forName: NSNotification.Name("FocusOSPostFailed"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("Received FocusOSPostFailed notification: \(notification.userInfo ?? [:])")
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
