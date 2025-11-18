//
//  AppleCalendarImportSettingsView.swift
//  FocusOS
//
//  Settings drawer for Apple Calendar import configuration
//

import SwiftUI
import EventKit
import SwiftData
import FocusOSShared

struct AppleCalendarImportSettingsView: View {
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @ObservedObject private var importService = AppleCalendarImportService.shared
    @ObservedObject private var settings = AppleCalendarImportSettings.shared
    
    @State private var availableCalendars: [EKCalendar] = []
    @State private var selectedCalendarIds: Set<String> = []
    @State private var syncIntervalMinutes: Double = 15
    @State private var importRangeForward: Int = 90
    @State private var importRangeBack: Int = 30
    
    private var accentGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    var body: some View {
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
                .frame(width: min(800, geometry.size.width * 0.85))
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
        .onAppear {
            loadSettings()
            loadAvailableCalendars()
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
                Text("Apple Calendar Settings")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Configure calendar import and sync preferences")
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
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Enable/Disable Toggle
            DrawerSection(title: "Import Status", icon: "power") {
                Toggle(isOn: $settings.importEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Calendar Import")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        Text("Automatically sync events from selected calendars")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                }
                .toggleStyle(.switch)
                .tint(.kosmicPurple)
                .onChange(of: settings.importEnabled) { newValue in
                    handleImportEnabledChange(newValue)
                }
            }
            
            // Calendar Selection
            DrawerSection(title: "Calendars", icon: "calendar") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select which calendars to import")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    if availableCalendars.isEmpty {
                        Text("No calendars available")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(glassColorSystem.textSecondary())
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                                    HStack {
                                        Circle()
                                            .fill(Color(cgColor: calendar.cgColor))
                                            .frame(width: 12, height: 12)
                                        
                                        Text(calendar.title)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(glassColorSystem.textPrimary())
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: Binding(
                                            get: { selectedCalendarIds.contains(calendar.calendarIdentifier) },
                                            set: { isSelected in
                                                if isSelected {
                                                    selectedCalendarIds.insert(calendar.calendarIdentifier)
                                                } else {
                                                    selectedCalendarIds.remove(calendar.calendarIdentifier)
                                                }
                                                settings.selectedCalendarIds = Array(selectedCalendarIds)
                                            }
                                        ))
                                        .toggleStyle(.switch)
                                        .tint(.kosmicPurple)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
            
            // Sync Interval
            DrawerSection(title: "Sync Interval", icon: "clock") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How often to check for calendar changes")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    Picker("Sync Interval", selection: $syncIntervalMinutes) {
                        Text("15 minutes").tag(15.0)
                        Text("30 minutes").tag(30.0)
                        Text("1 hour").tag(60.0)
                        Text("Manual only").tag(0.0)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: syncIntervalMinutes) { newValue in
                        settings.syncInterval = newValue > 0 ? newValue * 60 : 0
                    }
                }
            }
            
            // Import Range
            DrawerSection(title: "Import Range", icon: "calendar.badge.clock") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How far back and forward to import events")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Days Back")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                            
                            Stepper(value: $importRangeBack, in: 1...365, step: 1) {
                                Text("\(importRangeBack) days")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                            }
                            .onChange(of: importRangeBack) { newValue in
                                settings.importRangeDaysBack = newValue
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Days Forward")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(glassColorSystem.textPrimary())
                            
                            Stepper(value: $importRangeForward, in: 1...365, step: 1) {
                                Text("\(importRangeForward) days")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(glassColorSystem.textPrimary())
                            }
                            .onChange(of: importRangeForward) { newValue in
                                settings.importRangeDaysForward = newValue
                            }
                        }
                    }
                }
            }
            
            // Last Sync
            if let lastSync = settings.lastSyncDate {
                DrawerSection(title: "Last Sync", icon: "clock.arrow.circlepath") {
                    Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
            }
            
            // Actions
            HStack(spacing: 12) {
                GlassButton("Sync Now", icon: "arrow.clockwise", role: .primary) {
                    syncNow()
                }
                .disabled(importService.isSyncing)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleImportEnabledChange(_ enabled: Bool) {
        if enabled {
            _Concurrency.Task { @MainActor in
                await importService.start(modelContext: modelContext)
            }
        } else {
            importService.stop()
        }
    }
    
    private func syncNow() {
        _Concurrency.Task { @MainActor in
            do {
                try await importService.syncAllCalendars(modelContext: modelContext)
            } catch {
                // Error handling could be added here
            }
        }
    }
    
    private func loadSettings() {
        syncIntervalMinutes = settings.syncInterval / 60
        importRangeForward = settings.importRangeDaysForward
        importRangeBack = settings.importRangeDaysBack
        selectedCalendarIds = Set(settings.selectedCalendarIds)
    }
    
    private func loadAvailableCalendars() {
        availableCalendars = importService.getAvailableCalendars()
        
        // If no calendars are selected, select all by default
        if selectedCalendarIds.isEmpty && !availableCalendars.isEmpty {
            selectedCalendarIds = Set(availableCalendars.map { $0.calendarIdentifier })
            settings.selectedCalendarIds = Array(selectedCalendarIds)
        }
    }
    
    private func closeDrawer() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
}

