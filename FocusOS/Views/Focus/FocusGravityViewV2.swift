//
//  FocusGravityViewV2.swift
//  FocusOS
//
//  Focus Gravity V2 - Cognitive Priority Visualization Dashboard
//  Immersive dashboard showing focus engagement, priority motion, and predictive overlays
//

import SwiftUI
import SwiftData
import Combine
import AppKit
import FocusOSShared

struct FocusGravityViewV2: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @StateObject private var reactiveTheme = ReactiveThemeManager.shared
    
    @State private var entities: [FocusEntity] = []
    @State private var selectedFilter: FocusEntityFilter = .all
    @State private var timeScope: FocusTimeScope = .week
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showInsightsDrawer = false
    @State private var selectedEntityId: UUID?
    @State private var forecast: FocusForecast?
    @FocusState private var isSearchFocused: Bool
    
    // Keyboard event monitor
    @State private var keyboardMonitor: Any?
    
    // Reduce motion support
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var filteredEntities: [FocusEntity] {
        var filtered = entities
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { entity in
                entity.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        mainContent
            .frame(minWidth: 900, minHeight: 600)
            .background(glassColorSystem.backgroundColor())
            .task {
                await refreshData()
            }
            .onChange(of: selectedFilter) { _, _ in
                _Concurrency.Task { await refreshData() }
            }
            .onChange(of: timeScope) { _, _ in
                _Concurrency.Task { await refreshData() }
            }
            .onChange(of: reactiveTheme.currentState) { _, _ in
                // Invalidate cache on ARTE state change
                FocusGravityService.shared.invalidateCache()
            }
            .onReceive(NotificationCenter.default.publisher(for: .focusSessionStatusChanged)) { _ in
                // Refresh on session changes
                FocusGravityService.shared.invalidateCache()
                _Concurrency.Task { await refreshData() }
            }
            .onAppear {
                setupKeyboardHandlers()
            }
            .onDisappear {
                removeKeyboardHandlers()
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Focus Gravity Dashboard")
            .accessibilityHint("Use arrow keys to navigate entities, Return to open selected entity")
    }
    
    private var mainContent: some View {
        HSplitView {
            // Main content area
            mainContentArea
            
            // Insights drawer
            if showInsightsDrawer {
                FocusInsightsDrawer(
                    entities: filteredEntities,
                    forecast: forecast,
                    modelContext: modelContext
                )
                .frame(width: 320)
            }
        }
    }
    
    private var mainContentArea: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Orbit visualization
                    FocusGravityOrbit(
                        entities: filteredEntities,
                        selectedEntityId: $selectedEntityId,
                        forecast: forecast,
                        reduceMotion: reduceMotion
                    )
                    .frame(height: 400)
                    .padding(.vertical, 24)
                    
                    // Priority list
                    if !filteredEntities.isEmpty {
                        priorityListSection
                    }
                    
                    // Trend panels
                    trendPanelsSection
                }
            }
        }
    }
    
    private var priorityListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Priority List")
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
            ForEach(filteredEntities.prefix(10)) { entity in
                FocusGravityCard(
                    entity: entity,
                    isSelected: selectedEntityId == entity.id,
                    accentColor: stateColor
                )
                .onTapGesture {
                    selectedEntityId = entity.id
                }
            }
        }
        .padding(.horizontal, 28)
    }
    
    private var trendPanelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Focus Trends")
                .font(.headline)
                .foregroundColor(glassColorSystem.textPrimary())
            
            FocusTrendChart(
                reduceMotion: reduceMotion
            )
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        // ARTE glow ring around title
                        ZStack {
                            Circle()
                                .fill(stateColor.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .blur(radius: 8)
                            
                            Text("Focus Gravity")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(glassColorSystem.textPrimary())
                        }
                        
                        if glassColorSystem.isARTEEnabled {
                            stateBadge
                        }
                    }
                    
                    Text("Live map of cognitive engagement and priority motion")
                        .font(.subheadline)
                        .foregroundColor(glassColorSystem.textSecondary())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 12) {
                    // Filter chips
                    HStack(spacing: 8) {
                        ForEach(FocusEntityFilter.allCases, id: \.self) { filter in
                            filterChip(for: filter)
                        }
                    }
                    
                    // Time scope selector
                    Picker("Time Scope", selection: $timeScope) {
                        ForEach(FocusTimeScope.allCases, id: \.self) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    
                    // Search and controls
                    HStack(spacing: 8) {
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                            .focused($isSearchFocused)
                        
                        Button {
                            _Concurrency.Task { await refreshData() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                        
                        Button {
                            showInsightsDrawer.toggle()
                        } label: {
                            Label("Insights", systemImage: showInsightsDrawer ? "sidebar.right" : "sidebar.left")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    private var stateBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
            
            Text(stateName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(stateColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(stateColor.opacity(0.12))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(stateColor.opacity(0.25), lineWidth: 1)
        )
    }
    
    private func filterChip(for filter: FocusEntityFilter) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            selectedFilter = filter
        } label: {
            Text(filter.displayName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? stateColor : glassColorSystem.textSecondary())
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? stateColor.opacity(0.16) : glassColorSystem.glassTint(for: .surface).opacity(0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? stateColor.opacity(0.35) : glassColorSystem.borderColor().opacity(0.4), lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    
    private var stateColor: Color {
        switch reactiveTheme.currentState {
        case .calm:
            return .kosmicBlue
        case .focused:
            return .kosmicPurple
        case .fatigued:
            return .orange
        case .energized:
            return .kosmicGreen
        case .reflective:
            return .cyan
        }
    }
    
    private var stateName: String {
        switch reactiveTheme.currentState {
        case .calm: return "Calm"
        case .focused: return "Flow"
        case .fatigued: return "Fatigue"
        case .energized: return "Energized"
        case .reflective: return "Reflective"
        }
    }
    
    @MainActor
    private func refreshData() async {
        isLoading = true
        
        // Fetch entities
        entities = FocusGravityService.shared.fetchFocusEntities(
            timeScope: timeScope,
            filter: selectedFilter,
            modelContext: modelContext
        )
        
        // Fetch forecast
        forecast = FocusGravityService.shared.getLatestForecast(modelContext: modelContext)
        
        // Auto-select first entity if none selected
        if selectedEntityId == nil, let firstEntity = entities.first {
            selectedEntityId = firstEntity.id
        }
        
        isLoading = false
    }
    
    private func navigateEntity(direction: Int) {
        guard !filteredEntities.isEmpty else { return }
        
        let currentIndex = filteredEntities.firstIndex { $0.id == selectedEntityId } ?? 0
        let newIndex = max(0, min(filteredEntities.count - 1, currentIndex + direction))
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedEntityId = filteredEntities[newIndex].id
        }
    }
    
    private func openSelectedEntity() {
        guard let selectedId = selectedEntityId,
              let entity = filteredEntities.first(where: { $0.id == selectedId }) else {
            return
        }
        
        // Navigate based on entity type
        switch entity.type.lowercased() {
        case "task":
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.tasks)
        case "project":
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.projects)
        case "note":
            NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.notes)
        default:
            break
        }
    }
    
    // MARK: - Keyboard Handling
    
    private func setupKeyboardHandlers() {
        // Only handle keyboard shortcuts when text fields are not focused
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // Don't intercept if a text field is focused
            if isSearchFocused {
                return event
            }
            
            // Handle arrow keys and return only
            switch event.keyCode {
            case 123: // Left arrow
                navigateEntity(direction: -1)
                return nil
            case 124: // Right arrow
                navigateEntity(direction: 1)
                return nil
            case 36: // Return
                openSelectedEntity()
                return nil
            default:
                return event
            }
        }
    }
    
    private func removeKeyboardHandlers() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }
}

#Preview {
    FocusGravityViewV2()
        .modelContainer(for: [PriorityScore.self, FocusSession.self, FocusForecast.self], inMemory: true)
        .environmentObject(GlassColorSystem())
}

