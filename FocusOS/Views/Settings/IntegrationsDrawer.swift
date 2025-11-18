//
//  IntegrationsDrawer.swift
//  FocusOS
//
//  Unified integrations drawer for managing all FocusOS integrations
//

import SwiftUI
import SwiftData
import AuthenticationServices
import EventKit
import os.log
import FocusOSShared

struct IntegrationsDrawer: View {
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    // Notion state
    @ObservedObject private var notionService = NotionImportService.shared
    @ObservedObject private var notionSettings = NotionImportSettings.shared
    @State private var showNotionSettings = false
    @State private var notionIsConnecting = false
    @State private var notionError: String?
    @State private var notionSuccessMessage: String?
    
    // Apple Calendar state
    @ObservedObject private var appleCalendarService = AppleCalendarImportService.shared
    @State private var showAppleCalendarSettings = false
    @State private var showAppleCalendarPermissionDenied = false
    @State private var permissionObserverTask: _Concurrency.Task<Void, Never>?
    
    // Apple Reminders state
    @ObservedObject private var appleRemindersService = AppleRemindersImportService.shared
    @State private var showAppleRemindersSettings = false
    @State private var showAppleRemindersPermissionDenied = false
    @State private var remindersPermissionObserverTask: _Concurrency.Task<Void, Never>?
    
    // Todoist state
    @ObservedObject private var todoistService = TodoistImportService.shared
    @ObservedObject private var todoistSettings = TodoistImportSettings.shared
    @State private var showTodoistSettings = false
    @State private var todoistIsConnecting = false
    @State private var todoistError: String?
    @State private var todoistSuccessMessage: String?
    
    // Monday.com state
    @ObservedObject private var mondayService = MondayImportService.shared
    @ObservedObject private var mondaySettings = MondayImportSettings.shared
    @State private var showMondaySettings = false
    @State private var mondayIsConnecting = false
    @State private var mondayError: String?
    @State private var mondaySuccessMessage: String?
    
    // Placeholder integration states
    @State private var placeholderConnecting: Set<String> = []
    @State private var placeholderShowComingSoon: Set<String> = []
    
    // Pagination state
    @State private var currentPage = 0
    private let itemsPerPage = 5
    
    // Category state
    @State private var selectedCategory: IntegrationCategory = .all
    
    private var accentGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    var body: some View {
        Group {
            if isPresented {
                GeometryReader { geometry in
                    ZStack(alignment: .trailing) {
                        // Backdrop
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                closeDrawer()
                            }
                            .transition(.opacity)
                        
                        // Drawer
                        VStack(spacing: 0) {
                            V2DrawerScaffold(
                                accentGradient: accentGradient,
                                showsSidebar: false,
                                header: { headerView },
                                content: { contentView },
                                sidebar: { EmptyView() }
                            )
                        }
                        .frame(width: min(1200, geometry.size.width * 0.9))
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .overlay(alignment: .trailing) {
            if showNotionSettings {
                NotionImportSettingsView(
                    isPresented: $showNotionSettings
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            if showAppleCalendarSettings {
                AppleCalendarImportSettingsView(
                    isPresented: $showAppleCalendarSettings
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            if showAppleCalendarPermissionDenied {
                AppleCalendarPermissionDeniedDrawer(
                    isPresented: $showAppleCalendarPermissionDenied,
                    onOpenSystemSettings: {
                        // Start observing for permission changes
                        observeCalendarPermissionChanges()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onChange(of: showAppleCalendarPermissionDenied) { newValue in
                    if !newValue {
                        // Stop observing when drawer is dismissed
                        permissionObserverTask?.cancel()
                        permissionObserverTask = nil
                    }
                }
            }
            
            if showAppleRemindersSettings {
                AppleRemindersImportSettingsView(
                    isPresented: $showAppleRemindersSettings
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            
            if showAppleRemindersPermissionDenied {
                AppleRemindersPermissionDeniedDrawer(
                    isPresented: $showAppleRemindersPermissionDenied,
                    onOpenSystemSettings: {
                        // Start observing for permission changes
                        observeRemindersPermissionChanges()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onChange(of: showAppleRemindersPermissionDenied) { newValue in
                    if !newValue {
                        // Stop observing when drawer is dismissed
                        remindersPermissionObserverTask?.cancel()
                        remindersPermissionObserverTask = nil
                    }
                }
            }
            
            if showTodoistSettings {
                TodoistImportSettingsView(
                    isPresented: $showTodoistSettings
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            if showMondaySettings {
                MondayImportSettingsView(
                    isPresented: $showMondaySettings
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .alert("Todoist Connection Error", isPresented: Binding(
            get: { todoistError != nil },
            set: { if !$0 { todoistError = nil } }
        )) {
            Button("OK") {
                todoistError = nil
            }
        } message: {
            if let error = todoistError {
                Text(error)
            }
        }
        .alert("Todoist Connected", isPresented: Binding(
            get: { todoistSuccessMessage != nil },
            set: { if !$0 { todoistSuccessMessage = nil } }
        )) {
            Button("OK") {
                todoistSuccessMessage = nil
            }
        } message: {
            if let message = todoistSuccessMessage {
                Text(message)
            }
        }
        .onAppear {
            checkNotionConnectionStatus()
            checkAppleCalendarConnectionStatus()
            checkAppleRemindersConnectionStatus()
            checkTodoistConnectionStatus()
        }
        .alert(
            "Notion Connection",
            isPresented: Binding(
                get: { notionError != nil || notionSuccessMessage != nil },
                set: { newValue in
                    if !newValue {
                        notionError = nil
                        notionSuccessMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                notionError = nil
                notionSuccessMessage = nil
            }
        } message: {
            if let message = notionError {
                Text(message)
            } else if let message = notionSuccessMessage {
                Text(message)
            }
        }
        .alert(
            "Monday.com",
            isPresented: Binding(
                get: { mondayError != nil || mondaySuccessMessage != nil },
                set: { newValue in
                    if !newValue {
                        mondayError = nil
                        mondaySuccessMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                mondayError = nil
                mondaySuccessMessage = nil
            }
        } message: {
            if let message = mondayError {
                Text(message)
            } else if let message = mondaySuccessMessage {
                Text(message)
            }
        }
        .onKeyPress(.escape) {
            closeDrawer()
            return .handled
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Integrations")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Connect your favorite tools and services")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Spacer()
            
            GlassButton(
                nil,
                icon: "xmark",
                style: .iconOnly,
                role: .surface
            ) {
                closeDrawer()
            }
        }
    }
    
    // MARK: - Content
    
    enum IntegrationCategory: String, CaseIterable, Identifiable {
        case all = "All"
        case taskManagement = "Task Management"
        case calendar = "Calendar"
        case projectManagement = "Project Management"
        case development = "Development"
        case communication = "Communication"
        case music = "Music"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .taskManagement: return "checkmark.circle"
            case .calendar: return "calendar"
            case .projectManagement: return "folder"
            case .development: return "hammer"
            case .communication: return "message"
            case .music: return "music.note"
            }
        }
    }
    
    private enum IntegrationSectionType: Identifiable {
        case appleCalendar
        case appleReminders
        case googleCalendar
        case googleTasks
        case todoist
        case notion
        case monday
        case trello
        case spotify
        case microsoftTodo
        case githubIssues
        case discord
        case slack
        
        var id: String {
            switch self {
            case .appleCalendar: return "apple_calendar"
            case .appleReminders: return "apple_reminders"
            case .googleCalendar: return "google_calendar"
            case .googleTasks: return "google_tasks"
            case .todoist: return "todoist"
            case .notion: return "notion"
            case .monday: return "monday"
            case .trello: return "trello"
            case .spotify: return "spotify"
            case .microsoftTodo: return "microsoft_todo"
            case .githubIssues: return "github_issues"
            case .discord: return "discord"
            case .slack: return "slack"
            }
        }
        
        var category: IntegrationCategory {
            switch self {
            case .appleCalendar, .googleCalendar:
                return .calendar
            case .appleReminders, .googleTasks, .todoist, .microsoftTodo:
                return .taskManagement
            case .notion, .monday, .trello:
                return .projectManagement
            case .githubIssues:
                return .development
            case .discord, .slack:
                return .communication
            case .spotify:
                return .music
            }
        }
    }
    
    private var allIntegrationSections: [IntegrationSectionType] {
        [
            .appleCalendar,
            .appleReminders,
            .googleCalendar,
            .googleTasks,
            .todoist,
            .notion,
            .monday,
            .trello,
            .spotify,
            .microsoftTodo,
            .githubIssues,
            .discord,
            .slack
        ]
    }
    
    private var filteredIntegrationSections: [IntegrationSectionType] {
        if selectedCategory == .all {
            return allIntegrationSections
        }
        return allIntegrationSections.filter { $0.category == selectedCategory }
    }
    
    private var totalPages: Int {
        max(1, Int(ceil(Double(filteredIntegrationSections.count) / Double(itemsPerPage))))
    }
    
    private var currentPageSections: [IntegrationSectionType] {
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, filteredIntegrationSections.count)
        return Array(filteredIntegrationSections[startIndex..<endIndex])
    }
    
    @ViewBuilder
    private func sectionView(for type: IntegrationSectionType) -> some View {
        switch type {
        case .appleCalendar:
            appleCalendarIntegrationSection
        case .appleReminders:
            appleRemindersIntegrationSection
        case .googleCalendar:
            integrationSection(
                id: "google_calendar",
                title: "Google Calendar",
                icon: "calendar",
                color: .kosmicBlue,
                description: "Sync events from your Google Calendar account",
                isConnected: false,
                isConnecting: placeholderConnecting.contains("google_calendar"),
                showComingSoon: placeholderShowComingSoon.contains("google_calendar"),
                onConnect: { handlePlaceholderConnect("google_calendar") },
                onDisconnect: { handlePlaceholderDisconnect("google_calendar") },
                onManage: nil
            )
        case .googleTasks:
            integrationSection(
                id: "google_tasks",
                title: "Google Tasks",
                icon: "list.bullet.rectangle",
                color: .kosmicGreen,
                description: "Import tasks from your Google Tasks account",
                isConnected: false,
                isConnecting: placeholderConnecting.contains("google_tasks"),
                showComingSoon: placeholderShowComingSoon.contains("google_tasks"),
                onConnect: { handlePlaceholderConnect("google_tasks") },
                onDisconnect: { handlePlaceholderDisconnect("google_tasks") },
                onManage: nil
            )
        case .todoist:
            todoistIntegrationSection
        case .notion:
            notionIntegrationSection
        case .monday:
            mondayIntegrationSection
        case .trello:
            integrationSection(
                id: "trello",
                title: "Trello",
                icon: "square.grid.2x2",
                color: .kosmicPurple,
                description: "Import boards, lists, and cards from your Trello workspace",
                isConnected: false,
                isConnecting: placeholderConnecting.contains("trello"),
                showComingSoon: placeholderShowComingSoon.contains("trello"),
                onConnect: { handlePlaceholderConnect("trello") },
                onDisconnect: { handlePlaceholderDisconnect("trello") },
                onManage: nil
            )
        case .spotify:
            integrationSection(
                id: "spotify",
                title: "Spotify",
                icon: "music.note",
                color: .kosmicGreen,
                description: "Sync your music preferences and playlists",
                isConnected: false,
                isConnecting: placeholderConnecting.contains("spotify"),
                showComingSoon: placeholderShowComingSoon.contains("spotify"),
                onConnect: { handlePlaceholderConnect("spotify") },
                onDisconnect: { handlePlaceholderDisconnect("spotify") },
                onManage: nil
            )
        case .microsoftTodo:
            integrationSection(
                id: "microsoft_todo",
                title: "Microsoft To Do",
                icon: "checklist",
                color: .kosmicBlue,
                description: "Import tasks and lists from Microsoft To Do",
                isConnected: false,
                isConnecting: placeholderConnecting.contains("microsoft_todo"),
                showComingSoon: placeholderShowComingSoon.contains("microsoft_todo"),
                onConnect: { handlePlaceholderConnect("microsoft_todo") },
                onDisconnect: { handlePlaceholderDisconnect("microsoft_todo") },
                onManage: nil
            )
        case .githubIssues:
            integrationSection(
                id: "github_issues",
                title: "GitHub Issues",
                icon: "exclamationmark.triangle",
                color: .kosmicPurple,
                description: "Import issues and pull requests from your GitHub repositories",
                isConnected: false,
                isConnecting: placeholderConnecting.contains("github_issues"),
                showComingSoon: placeholderShowComingSoon.contains("github_issues"),
                onConnect: { handlePlaceholderConnect("github_issues") },
                onDisconnect: { handlePlaceholderDisconnect("github_issues") },
                onManage: nil
            )
        case .discord:
            integrationSection(
                id: "discord",
                title: "Discord",
                icon: "message.fill",
                color: .kosmicPurple,
                description: "Sync messages and notifications from your Discord servers",
                isConnected: false,
                isConnecting: placeholderConnecting.contains("discord"),
                showComingSoon: placeholderShowComingSoon.contains("discord"),
                onConnect: { handlePlaceholderConnect("discord") },
                onDisconnect: { handlePlaceholderDisconnect("discord") },
                onManage: nil
            )
        case .slack:
            integrationSection(
                id: "slack",
                title: "Slack",
                icon: "message.badge",
                color: .kosmicBlue,
                description: "Import messages and tasks from your Slack workspace",
                isConnected: false,
                isConnecting: placeholderConnecting.contains("slack"),
                showComingSoon: placeholderShowComingSoon.contains("slack"),
                onConnect: { handlePlaceholderConnect("slack") },
                onDisconnect: { handlePlaceholderDisconnect("slack") },
                onManage: nil
            )
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Category selector
            categorySelector
            
            // Current page sections
            ForEach(currentPageSections) { sectionType in
                sectionView(for: sectionType)
            }
            
            // Pagination controls
            if totalPages > 1 {
                HStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        GlassButton(
                            nil,
                            icon: "chevron.left",
                            style: .iconOnly,
                            role: .surface
                        ) {
                            withAnimation {
                                currentPage = max(0, currentPage - 1)
                            }
                        }
                        .disabled(currentPage == 0)
                        
                        Text("Page \(currentPage + 1) of \(totalPages)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .frame(minWidth: 100)
                        
                        GlassButton(
                            nil,
                            icon: "chevron.right",
                            style: .iconOnly,
                            role: .surface
                        ) {
                            withAnimation {
                                currentPage = min(totalPages - 1, currentPage + 1)
                            }
                        }
                        .disabled(currentPage >= totalPages - 1)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
            }
        }
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(IntegrationCategory.allCases) { category in
                    GlassButton(
                        category.rawValue,
                        icon: category.icon,
                        role: selectedCategory == category ? .primary : .surface
                    ) {
                        withAnimation {
                            selectedCategory = category
                            currentPage = 0 // Reset to first page when changing category
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Integration Section Builder
    
    @ViewBuilder
    private func integrationSection(
        id: String,
        title: String,
        icon: String,
        color: Color,
        description: String,
        isConnected: Bool,
        isConnecting: Bool,
        showComingSoon: Bool,
        onConnect: @escaping () -> Void,
        onDisconnect: @escaping () -> Void,
        onManage: (() -> Void)?
    ) -> some View {
        DrawerSection(
            title: title,
            icon: icon,
            subtitle: showComingSoon ? "Coming Soon" : nil
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                if showComingSoon {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.questionmark")
                            .foregroundStyle(.orange)
                        Text("This integration is coming soon")
                            .font(.subheadline)
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                    .padding(.vertical, 8)
                }
                
                GlassButton(
                    isConnecting ? "Connecting..." : "Connect",
                    icon: isConnecting ? nil : "link.badge.plus",
                    role: .primary
                ) {
                    onConnect()
                }
                .disabled(isConnecting || showComingSoon)
                .opacity((isConnecting || showComingSoon) ? 0.6 : 1.0)
                .overlay(alignment: .trailing) {
                    if isConnecting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 12)
                    }
                }
            }
        }
    }
    
    // MARK: - Apple Calendar Integration Section
    
    private var appleCalendarIntegrationSection: some View {
        let settings = AppleCalendarImportSettings.shared
        let isConnected = settings.importEnabled
        
        return DrawerSection(
            title: "Apple Calendar",
            icon: "calendar.badge.clock",
            subtitle: isConnected ? "Connected" : nil
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sync events and appointments from your macOS Calendar")
                    .font(.caption)
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                if !isConnected {
                    GlassButton(
                        appleCalendarService.isSyncing ? "Connecting..." : "Connect",
                        icon: appleCalendarService.isSyncing ? nil : "link.badge.plus",
                        role: .primary
                    ) {
                        connectToAppleCalendar()
                    }
                    .disabled(appleCalendarService.isSyncing)
                    .opacity(appleCalendarService.isSyncing ? 0.6 : 1.0)
                    .overlay(alignment: .trailing) {
                        if appleCalendarService.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 12)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.kosmicGreen)
                            Text("Connected to Apple Calendar")
                                .font(.subheadline)
                                .foregroundStyle(glassColorSystem.textPrimary())
                        }
                        
                        Spacer()
                        
                        if appleCalendarService.isSyncing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing...")
                                    .font(.subheadline)
                                    .foregroundStyle(glassColorSystem.textSecondary())
                            }
                        } else if let lastSync = settings.lastSyncDate {
                            Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                        
                        GlassButton("Sync Now", icon: "arrow.clockwise", role: .surface) {
                            syncAppleCalendarNow()
                        }
                        .disabled(appleCalendarService.isSyncing)
                        
                        GlassButton("Settings", icon: "slider.horizontal.3", role: .primary) {
                            showAppleCalendarSettings = true
                        }
                        
                        GlassButton("Disconnect", icon: "link.badge.minus", role: .surface) {
                            disconnectFromAppleCalendar()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Apple Reminders Integration Section
    
    private var appleRemindersIntegrationSection: some View {
        let settings = AppleRemindersImportSettings.shared
        let isConnected = settings.importEnabled
        
        return DrawerSection(
            title: "Apple Reminders",
            icon: "bell.badge",
            subtitle: isConnected ? "Connected" : nil
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Import reminders and tasks from the Reminders app")
                    .font(.caption)
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                if !isConnected {
                    GlassButton(
                        appleRemindersService.isSyncing ? "Connecting..." : "Connect",
                        icon: appleRemindersService.isSyncing ? nil : "link.badge.plus",
                        role: .primary
                    ) {
                        connectToAppleReminders()
                    }
                    .disabled(appleRemindersService.isSyncing)
                    .opacity(appleRemindersService.isSyncing ? 0.6 : 1.0)
                    .overlay(alignment: .trailing) {
                        if appleRemindersService.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 12)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.kosmicGreen)
                            Text("Connected to Apple Reminders")
                                .font(.subheadline)
                                .foregroundStyle(glassColorSystem.textPrimary())
                        }
                        
                        Spacer()
                        
                        if appleRemindersService.isSyncing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing...")
                                    .font(.subheadline)
                                    .foregroundStyle(glassColorSystem.textSecondary())
                            }
                        } else if let lastSync = settings.lastSyncDate {
                            Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                        
                        GlassButton("Sync Now", icon: "arrow.clockwise", role: .surface) {
                            syncAppleRemindersNow()
                        }
                        .disabled(appleRemindersService.isSyncing)
                        
                        GlassButton("Settings", icon: "slider.horizontal.3", role: .primary) {
                            showAppleRemindersSettings = true
                        }
                        
                        GlassButton("Disconnect", icon: "link.badge.minus", role: .surface) {
                            disconnectFromAppleReminders()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Todoist Integration Section
    
    private var todoistIntegrationSection: some View {
        let settings = TodoistImportSettings.shared
        let isConnected = settings.isConnected && settings.importEnabled
        
        return DrawerSection(
            title: "Todoist",
            icon: "checkmark.circle.fill",
            subtitle: isConnected ? "Connected" : nil
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sync projects and tasks from your Todoist workspace")
                    .font(.caption)
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                if !isConnected {
                    GlassButton(
                        todoistIsConnecting ? "Connecting..." : "Connect",
                        icon: todoistIsConnecting ? nil : "link.badge.plus",
                        role: .primary
                    ) {
                        connectToTodoist()
                    }
                    .disabled(todoistIsConnecting)
                    .opacity(todoistIsConnecting ? 0.6 : 1.0)
                    .overlay(alignment: .trailing) {
                        if todoistIsConnecting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 12)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.kosmicGreen)
                            Text("Connected to Todoist")
                                .font(.subheadline)
                                .foregroundStyle(glassColorSystem.textPrimary())
                        }
                        
                        Spacer()
                        
                        if todoistService.isSyncing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing...")
                                    .font(.subheadline)
                                    .foregroundStyle(glassColorSystem.textSecondary())
                            }
                        } else if let lastSync = settings.lastSyncDate {
                            Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                        
                        GlassButton("Sync Now", icon: "arrow.clockwise", role: .surface) {
                            syncTodoistNow()
                        }
                        .disabled(todoistService.isSyncing)
                        
                        GlassButton("Settings", icon: "slider.horizontal.3", role: .primary) {
                            showTodoistSettings = true
                        }
                        
                        GlassButton("Disconnect", icon: "link.badge.minus", role: .surface) {
                            disconnectFromTodoist()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Todoist Connection Logic
    
    private func connectToTodoist() {
        todoistIsConnecting = true
        todoistError = nil
        todoistSuccessMessage = nil
        
        _Concurrency.Task {
            do {
                guard let oauthURL = TodoistService.shared.getOAuthURL() else {
                    let errorMsg = "Failed to generate Todoist OAuth URL. Check your Config.plist settings."
                    Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("\(errorMsg)")
                    await MainActor.run {
                        todoistIsConnecting = false
                        todoistError = errorMsg
                    }
                    return
                }
                
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Starting Todoist OAuth flow with URL: \(oauthURL.absoluteString)")
                
                let callbackURL = try await ASWebAuthenticationSession.start(
                    url: oauthURL,
                    callbackURLScheme: "focusos"
                )
                
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Received callback URL: \(callbackURL.absoluteString)")
                
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                    let errorMsg = "Invalid callback URL format"
                    Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("\(errorMsg): \(callbackURL.absoluteString)")
                    await MainActor.run {
                        todoistIsConnecting = false
                        todoistError = errorMsg
                    }
                    return
                }
                
                // Check for error in callback
                if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
                    var errorMsg = "OAuth error: \(error)"
                    
                    // Provide helpful error messages for common issues
                    if error == "redirect_uri_not_configured" {
                        errorMsg = """
                        Redirect URI not configured in Todoist OAuth app.
                        
                        Please add this redirect URI to your Todoist OAuth app settings:
                        focusos://todoist-oauth
                        
                        Steps:
                        1. Go to https://developer.todoist.com/appconsole
                        2. Select your OAuth app
                        3. Add "focusos://todoist-oauth" to the Redirect URIs list
                        4. Save and try again
                        """
                    } else if error == "access_denied" {
                        errorMsg = "Access was denied. Please try again and authorize the app."
                    } else if error == "invalid_client" {
                        errorMsg = "Invalid OAuth client. Please check your TodoistOAuthClientId and TodoistOAuthClientSecret in Config.plist."
                    }
                    
                    Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("\(errorMsg)")
                    await MainActor.run {
                        todoistIsConnecting = false
                        todoistError = errorMsg
                    }
                    return
                }
                
                guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    let errorMsg = "No authorization code in callback URL"
                    Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("\(errorMsg). Callback URL: \(callbackURL.absoluteString)")
                    await MainActor.run {
                        todoistIsConnecting = false
                        todoistError = errorMsg
                    }
                    return
                }
                
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Exchanging authorization code for access token...")
                
                let tokenResponse = try await TodoistService.shared.exchangeCodeForToken(code)
                
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Token exchange successful, storing tokens...")
                
                let settings = TodoistImportSettings.shared
                try settings.storeTokens(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken)
                settings.importEnabled = true
                
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Tokens stored, starting import service...")
                
                // If no projects selected, we'll let user select in settings
                // For now, just start the service
                await MainActor.run {
                    todoistIsConnecting = false
                    todoistSuccessMessage = "Successfully connected to Todoist!"
                    
                    // Start the service
                    _Concurrency.Task { @MainActor in
                        await todoistService.start(modelContext: modelContext)
                        
                        // Open settings drawer after a brief delay to show success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showTodoistSettings = true
                        }
                    }
                }
                
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Todoist OAuth completed successfully")
                
            } catch {
                let errorMsg = "OAuth failed: \(error.localizedDescription)"
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("\(errorMsg)")
                print("Todoist OAuth Error: \(error)")
                if let nsError = error as NSError? {
                    print("Error domain: \(nsError.domain), code: \(nsError.code)")
                    print("Error userInfo: \(nsError.userInfo)")
                }
                await MainActor.run {
                    todoistIsConnecting = false
                    todoistError = errorMsg
                }
            }
        }
    }
    
    private func disconnectFromTodoist() {
        let settings = TodoistImportSettings.shared
        settings.importEnabled = false
        settings.clearTokens()
        todoistService.stop()
    }
    
    private func syncTodoistNow() {
        _Concurrency.Task { @MainActor in
            do {
                try await todoistService.syncAllProjects(modelContext: modelContext)
            } catch {
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("Todoist sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkTodoistConnectionStatus() {
        // Status is managed by TodoistImportSettings
        // No additional check needed
    }
    
    // MARK: - Apple Reminders Connection Logic
    
    private func connectToAppleReminders() {
        _Concurrency.Task { @MainActor in
            let status = await appleRemindersService.checkPermissionStatus()
            
            if status == .authorized || status == .fullAccess {
                // Permission granted, proceed with connection
                let settings = AppleRemindersImportSettings.shared
                settings.importEnabled = true
                
                // If no reminder lists selected, use all available
                if settings.selectedReminderListIds.isEmpty {
                    let lists = appleRemindersService.getAvailableReminderLists()
                    settings.selectedReminderListIds = lists.map { $0.calendarIdentifier }
                }
                
                // Start the service
                await appleRemindersService.start(modelContext: modelContext)
            } else if status == .denied || status == .restricted {
                // Show custom permission denied drawer
                showAppleRemindersPermissionDenied = true
            } else {
                // .notDetermined - request access
                let authorized = await appleRemindersService.requestAccess()
                if authorized {
                    let settings = AppleRemindersImportSettings.shared
                    settings.importEnabled = true
                    
                    if settings.selectedReminderListIds.isEmpty {
                        let lists = appleRemindersService.getAvailableReminderLists()
                        settings.selectedReminderListIds = lists.map { $0.calendarIdentifier }
                    }
                    
                    await appleRemindersService.start(modelContext: modelContext)
                }
            }
        }
    }
    
    private func observeRemindersPermissionChanges() {
        // Cancel any existing observer
        remindersPermissionObserverTask?.cancel()
        
        // Check permission status periodically and auto-retry when enabled
        remindersPermissionObserverTask = _Concurrency.Task { @MainActor in
            while showAppleRemindersPermissionDenied {
                try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000) // Check every second
                
                guard showAppleRemindersPermissionDenied else { break }
                
                let status = await appleRemindersService.checkPermissionStatus()
                if status == .authorized || status == .fullAccess {
                    // Permission granted! Auto-connect
                    showAppleRemindersPermissionDenied = false
                    
                    let settings = AppleRemindersImportSettings.shared
                    settings.importEnabled = true
                    
                    if settings.selectedReminderListIds.isEmpty {
                        let lists = appleRemindersService.getAvailableReminderLists()
                        settings.selectedReminderListIds = lists.map { $0.calendarIdentifier }
                    }
                    
                    await appleRemindersService.start(modelContext: modelContext)
                    break
                }
            }
        }
    }
    
    private func disconnectFromAppleReminders() {
        let settings = AppleRemindersImportSettings.shared
        settings.importEnabled = false
        appleRemindersService.stop()
    }
    
    private func syncAppleRemindersNow() {
        _Concurrency.Task { @MainActor in
            do {
                try await appleRemindersService.syncAllReminderLists(modelContext: modelContext)
            } catch {
                // Error is logged by the service
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("Reminders sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkAppleRemindersConnectionStatus() {
        // Status is managed by AppleRemindersImportSettings
        // No additional check needed
    }
    
    // MARK: - Apple Calendar Connection Logic
    
    private func connectToAppleCalendar() {
        _Concurrency.Task { @MainActor in
            let status = await appleCalendarService.checkPermissionStatus()
            
            if status == .authorized || status == .fullAccess {
                // Permission granted, proceed with connection
                let settings = AppleCalendarImportSettings.shared
                settings.importEnabled = true
                
                // If no calendars selected, use all available
                if settings.selectedCalendarIds.isEmpty {
                    let calendars = appleCalendarService.getAvailableCalendars()
                    settings.selectedCalendarIds = calendars.map { $0.calendarIdentifier }
                }
                
                // Start the service
                await appleCalendarService.start(modelContext: modelContext)
            } else if status == .denied || status == .restricted {
                // Show custom permission denied drawer
                showAppleCalendarPermissionDenied = true
            } else {
                // .notDetermined - request access
                let authorized = await appleCalendarService.requestAccess()
                if authorized {
                    let settings = AppleCalendarImportSettings.shared
                    settings.importEnabled = true
                    
                    if settings.selectedCalendarIds.isEmpty {
                        let calendars = appleCalendarService.getAvailableCalendars()
                        settings.selectedCalendarIds = calendars.map { $0.calendarIdentifier }
                    }
                    
                    await appleCalendarService.start(modelContext: modelContext)
                }
            }
        }
    }
    
    private func observeCalendarPermissionChanges() {
        // Cancel any existing observer
        permissionObserverTask?.cancel()
        
        // Check permission status periodically and auto-retry when enabled
        permissionObserverTask = _Concurrency.Task { @MainActor in
            while showAppleCalendarPermissionDenied {
                try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000) // Check every second
                
                guard showAppleCalendarPermissionDenied else { break }
                
                let status = await appleCalendarService.checkPermissionStatus()
                if status == .authorized || status == .fullAccess {
                    // Permission granted! Auto-connect
                    showAppleCalendarPermissionDenied = false
                    
                    let settings = AppleCalendarImportSettings.shared
                    settings.importEnabled = true
                    
                    if settings.selectedCalendarIds.isEmpty {
                        let calendars = appleCalendarService.getAvailableCalendars()
                        settings.selectedCalendarIds = calendars.map { $0.calendarIdentifier }
                    }
                    
                    await appleCalendarService.start(modelContext: modelContext)
                    break
                }
            }
        }
    }
    
    private func disconnectFromAppleCalendar() {
        let settings = AppleCalendarImportSettings.shared
        settings.importEnabled = false
        appleCalendarService.stop()
    }
    
    private func syncAppleCalendarNow() {
        _Concurrency.Task { @MainActor in
            do {
                try await appleCalendarService.syncAllCalendars(modelContext: modelContext)
            } catch {
                // Error is logged by the service
                // Could show a toast notification here if needed
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("Sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkAppleCalendarConnectionStatus() {
        // Status is managed by AppleCalendarImportSettings
        // No additional check needed
    }
    
    // MARK: - Notion Integration Section
    
    private var notionIntegrationSection: some View {
        DrawerSection(
            title: "Notion",
            icon: "externaldrive.badge.icloud",
            subtitle: notionSettings.isConnected ? "Connected" : nil
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Import your projects, tasks, and notes from Notion")
                    .font(.caption)
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                if !notionSettings.isConnected {
                    GlassButton(
                        notionIsConnecting ? "Connecting..." : "Connect Notion",
                        icon: notionIsConnecting ? nil : "link.badge.plus",
                        role: .primary
                    ) {
                        connectToNotion()
                    }
                    .disabled(notionIsConnecting)
                    .opacity(notionIsConnecting ? 0.6 : 1.0)
                    .overlay(alignment: .trailing) {
                        if notionIsConnecting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 12)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.kosmicGreen)
                            Text("Connected to Notion")
                                .font(.subheadline)
                                .foregroundStyle(glassColorSystem.textPrimary())
                        }
                        
                        Spacer()
                        
                        if notionService.isSyncing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing...")
                                    .font(.subheadline)
                                    .foregroundStyle(glassColorSystem.textSecondary())
                            }
                        } else if let lastSync = notionSettings.lastSyncDate {
                            Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                        
                        GlassButton("Sync Now", icon: "arrow.clockwise", role: .surface) {
                            syncNotionNow()
                        }
                        .disabled(notionService.isSyncing)
                        
                        GlassButton("Settings", icon: "slider.horizontal.3", role: .primary) {
                            presentNotionIntegrationManager()
                        }
                        
                        GlassButton("Disconnect", icon: "link.badge.minus", role: .surface) {
                            disconnectFromNotion()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Notion Connection Logic
    
    private func connectToNotion() {
        notionIsConnecting = true
        
        _Concurrency.Task {
            do {
                guard let oauthURL = NotionService.shared.getOAuthURL() else {
                    Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("Failed to generate Notion OAuth URL")
                    await MainActor.run {
                        notionIsConnecting = false
                        notionError = "Failed to generate OAuth URL. Please check your Notion OAuth configuration."
                    }
                    return
                }
                
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Starting Notion OAuth flow with URL: \(oauthURL.absoluteString)")
                
                // Use focusos:// scheme for callback - server will redirect HTTPS -> focusos://
                let callbackURL = try await ASWebAuthenticationSession.start(
                    url: oauthURL,
                    callbackURLScheme: "focusos"
                )
                
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Received callback URL: \(callbackURL.absoluteString)")
                
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                    await MainActor.run {
                        notionIsConnecting = false
                        notionError = "Invalid callback URL"
                    }
                    return
                }
                
                // Handle focusos://oauth/notion URLs from server redirect
                // Expected format: focusos://oauth/notion?code=...&state=...
                // Also handle direct focusos:// URLs if server redirects to root
                let path = callbackURL.path
                let isNotionCallback = path.contains("notion") || path.isEmpty
                
                if !isNotionCallback && callbackURL.scheme == "focusos" {
                    Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").warning("Received focusos:// URL but path doesn't match notion: \(path)")
                }
                
                // Check for error in callback
                if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
                    await MainActor.run {
                        notionIsConnecting = false
                        if error == "access_denied" {
                            notionError = "Notion authorization was cancelled or denied."
                        } else {
                            notionError = "Notion authorization failed: \(error)"
                        }
                    }
                    return
                }
                
                guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                      let state = components.queryItems?.first(where: { $0.name == "state" })?.value else {
                    await MainActor.run {
                        notionIsConnecting = false
                        notionError = "Missing authorization code or state parameter. Please ensure your OAuth callback server at https://oauth.kosmicapps.com/auth/callback is configured to redirect to focusos://oauth/notion"
                    }
                    return
                }
                
                guard state.hasPrefix("notion:") else {
                    Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("Invalid state parameter: \(state)")
                    await MainActor.run {
                        notionIsConnecting = false
                        notionError = "Invalid state parameter. Expected state to start with 'notion:'"
                    }
                    return
                }
                
                let tokenResponse = try await NotionService.shared.exchangeCodeForToken(code)
                
                try notionSettings.storeTokens(accessToken: tokenResponse.accessToken, refreshToken: nil)
                
                await MainActor.run {
                    notionIsConnecting = false
                    notionSuccessMessage = "Successfully connected to Notion!"
                    
                    // Trigger initial import
                    if notionSettings.importEnabled {
                        _Concurrency.Task { @MainActor in
                            await notionService.start(modelContext: modelContext)
                        }
                    }
                }
                
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Notion OAuth completed successfully")
                
            } catch let error as ASWebAuthenticationSessionError where error.code.rawValue == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Notion OAuth flow cancelled by user.")
                await MainActor.run {
                    notionIsConnecting = false
                    notionError = "Notion connection cancelled."
                }
            } catch {
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("Notion OAuth failed: \(error.localizedDescription)")
                await MainActor.run {
                    notionIsConnecting = false
                    notionError = "Notion connection failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func disconnectFromNotion() {
        notionService.stop()
        notionSettings.clearTokens()
        notionSettings.importEnabled = false
        
        Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Disconnected from Notion")
    }
    
    private func syncNotionNow() {
        _Concurrency.Task { @MainActor in
            do {
                try await notionService.syncAllDatabases(modelContext: modelContext)
                notionSuccessMessage = "Notion sync completed successfully"
        } catch {
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("Notion sync failed: \(error.localizedDescription)")
                notionError = "Sync failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func checkNotionConnectionStatus() {
        // Status is automatically checked via notionSettings.isConnected
        // This method is kept for compatibility but doesn't need to do anything
    }
    
    private func presentNotionIntegrationManager() {
        guard notionSettings.isConnected else {
            notionError = "Please connect to Notion first"
            return
        }
        
        showNotionSettings = true
    }
    
    // MARK: - Monday.com Integration Section
    
    private var mondayIntegrationSection: some View {
        DrawerSection(
            title: "Monday.com",
            icon: "tablecells",
            subtitle: mondaySettings.isConnected ? "Connected" : nil
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Import your boards and items from Monday.com")
                    .font(.caption)
                    .foregroundStyle(glassColorSystem.textSecondary())
                
                if !mondaySettings.isConnected {
                    GlassButton(
                        mondayIsConnecting ? "Connecting..." : "Connect Monday.com",
                        icon: mondayIsConnecting ? nil : "link.badge.plus",
                        role: .primary
                    ) {
                        connectToMonday()
                    }
                    .disabled(mondayIsConnecting)
                    .opacity(mondayIsConnecting ? 0.6 : 1.0)
                    .overlay(alignment: .trailing) {
                        if mondayIsConnecting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 12)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.kosmicGreen)
                            Text("Connected to Monday.com")
                                .font(.subheadline)
                                .foregroundStyle(glassColorSystem.textPrimary())
                        }
                        
                        Spacer()
                        
                        if mondayService.isSyncing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing...")
                                    .font(.subheadline)
                                    .foregroundStyle(glassColorSystem.textSecondary())
                            }
                        } else if let lastSync = mondaySettings.lastSyncDate {
                            Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                        
                        GlassButton("Sync Now", icon: "arrow.clockwise", role: .surface) {
                            syncMondayNow()
                        }
                        .disabled(mondayService.isSyncing)
                        
                        GlassButton("Settings", icon: "slider.horizontal.3", role: .primary) {
                            presentMondayIntegrationManager()
                        }
                        
                        GlassButton("Disconnect", icon: "link.badge.minus", role: .surface) {
                            disconnectFromMonday()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Monday.com Connection Logic
    
    private func connectToMonday() {
        mondayIsConnecting = true
        
        _Concurrency.Task {
            do {
                guard let oauthURL = MondayService.shared.getOAuthURL() else {
                    Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("Failed to generate Monday.com OAuth URL")
                    await MainActor.run {
                        mondayIsConnecting = false
                        mondayError = "Failed to generate OAuth URL. Please check your Monday.com OAuth configuration."
                    }
                    return
                }
                
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Starting Monday.com OAuth flow with URL: \(oauthURL.absoluteString)")
                
                // Use focusos:// scheme for callback - server will redirect HTTPS -> focusos://
                let callbackURL = try await ASWebAuthenticationSession.start(
                    url: oauthURL,
                    callbackURLScheme: "focusos"
                )
                
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Received callback URL: \(callbackURL.absoluteString)")
                
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                    await MainActor.run {
                        mondayIsConnecting = false
                        mondayError = "Invalid callback URL"
                    }
                    return
                }
                
                // Handle focusos://oauth/monday URLs from server redirect
                let path = callbackURL.path
                let isMondayCallback = path.contains("monday") || path.isEmpty
                
                if !isMondayCallback && callbackURL.scheme == "focusos" {
                    Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").warning("Received focusos:// URL but path doesn't match monday: \(path)")
                }
                
                // Check for error in callback
                if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
                    await MainActor.run {
                        mondayIsConnecting = false
                        if error == "access_denied" {
                            mondayError = "Monday.com authorization was cancelled or denied."
                        } else {
                            mondayError = "Monday.com authorization failed: \(error)"
                        }
                    }
                    return
                }
                
                guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                      let state = components.queryItems?.first(where: { $0.name == "state" })?.value else {
                    await MainActor.run {
                        mondayIsConnecting = false
                        mondayError = "Missing authorization code or state parameter. Please ensure your OAuth callback server at https://oauth.kosmicapps.com/auth/callback is configured to redirect to focusos://oauth/monday"
                    }
                    return
                }
                
                guard state.hasPrefix("monday:") else {
                    Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("Invalid state parameter: \(state)")
                    await MainActor.run {
                        mondayIsConnecting = false
                        mondayError = "Invalid state parameter. Expected state to start with 'monday:'"
                    }
                    return
                }
                
                let tokenResponse = try await MondayService.shared.exchangeCodeForToken(code)
                
                try mondaySettings.storeTokens(accessToken: tokenResponse.accessToken)
                
                await MainActor.run {
                    mondayIsConnecting = false
                    mondaySuccessMessage = "Successfully connected to Monday.com!"
                    
                    // Trigger initial import
                    if mondaySettings.importEnabled {
                        _Concurrency.Task { @MainActor in
                            await mondayService.start(modelContext: modelContext)
                        }
                    }
                }
            } catch {
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("Monday.com connection failed: \(error.localizedDescription)")
                await MainActor.run {
                    mondayIsConnecting = false
                    mondayError = "Monday.com connection failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func disconnectFromMonday() {
        mondayService.stop()
        mondaySettings.clearTokens()
        mondaySettings.importEnabled = false
        
        Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").info("Disconnected from Monday.com")
    }
    
    private func syncMondayNow() {
        _Concurrency.Task { @MainActor in
            do {
                try await mondayService.syncAllBoards(modelContext: modelContext)
                mondaySuccessMessage = "Monday.com sync completed successfully"
            } catch {
                Logger(subsystem: "com.kosmicapps.FocusOS", category: "IntegrationsDrawer").error("Monday.com sync failed: \(error.localizedDescription)")
                mondayError = "Sync failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func checkMondayConnectionStatus() {
        // Status is automatically checked via mondaySettings.isConnected
        // This method is kept for compatibility but doesn't need to do anything
    }
    
    private func presentMondayIntegrationManager() {
        guard mondaySettings.isConnected else {
            mondayError = "Please connect to Monday.com first"
            return
        }
        
        showMondaySettings = true
    }
    
    // MARK: - Placeholder Integration Logic
    
    private func handlePlaceholderConnect(_ id: String) {
        placeholderConnecting.insert(id)
        
        // Simulate connection delay, then show "Coming Soon" message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            placeholderConnecting.remove(id)
            placeholderShowComingSoon.insert(id)
        }
    }
    
    private func handlePlaceholderDisconnect(_ id: String) {
        placeholderShowComingSoon.remove(id)
    }
    
    // MARK: - Drawer Management
    
    private func closeDrawer() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}

