//
//  FocusGravityView.swift
//  FocusOS
//
//  Phase 3: CPS-Driven Priority View
//  Shows the top priority items dynamically ranked by the Contextual Priority System
//

import SwiftUI
import SwiftData
import FocusOSShared

struct FocusGravityView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var priorityItems: [PriorityItem] = []
    @State private var selectedFilter: FocusGravityFilter = .all
    @State private var isLoading = false
    @State private var orbitRotation: Double = 0
    @State private var loadingRotation: Double = 0
    @State private var isPulsing = false
    @State private var showAuroraInsights = false
    @State private var recenterToken = UUID()
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        V2GlassContentScaffold(
            accentGradient: AuroraPalette.linearGradient(for: colorScheme),
            showsSidebar: false,
            header: { headerBar },
            content: {
        ScrollViewReader { proxy in
                    focusContent
                        .onAppear {
                            scrollProxy = proxy
                    }
                }
            },
            sidebar: { EmptyView() }
        )
            .frame(minWidth: 700, minHeight: 500)
        .task {
            await refreshPriorities(animated: false)
            startPulse()
        }
        .onChange(of: selectedFilter) { _, _ in
            _Concurrency.Task { await refreshPriorities(animated: true) }
        }
        .sheet(isPresented: $showAuroraInsights) {
            AuroraInsightPlaceholder(accentColor: stateColor)
                .environmentObject(glassColorSystem)
        }
        .onDisappear {
            stopPulse()
        }
        .onChange(of: recenterToken) { _ in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                scrollProxy?.scrollTo("gravity-top", anchor: .top)
            }
        }
    }
    
    // MARK: - Header
    private var headerBar: some View {
        V2GlassHeaderBar(
            title: "Focus Gravity",
            subtitle: "Track how your attention shifts across CPS priorities.",
            trailingAccessory: {
                stateBadge
            }
        )
    }
    
    @ViewBuilder
    private var focusContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            filterPanel
            gravityCanvas
        }
        .padding(.top, 4)
        .id("gravity-top")
    }
    
    // MARK: - State Badge
    private var stateBadge: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(stateColor)
                    .frame(width: 8, height: 8)
                Circle()
                    .stroke(stateColor.opacity(0.25), lineWidth: 2)
                    .frame(width: 14, height: 14)
                Circle()
                    .stroke(stateColor.opacity(0.25), lineWidth: 2)
                    .frame(width: 14, height: 14)
                    .scaleEffect(isPulsing ? 1.6 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: isPulsing)
            }
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: glassColorSystem.emotionalState)
    }
    
    // MARK: - Filters
    private var filterPanel: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    Text("Prioritization Filters")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    Spacer()
                    controlCluster
                }
                
                GlassDivider()
                
        HStack(spacing: 8) {
            ForEach(FocusGravityFilter.allCases, id: \.self) { filter in
                filterChip(for: filter)
            }
        }
            }
            .padding(20)
        }
        .padding(.horizontal, 4)
    }
    
    private func filterChip(for filter: FocusGravityFilter) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            guard selectedFilter != filter else { return }
            selectedFilter = filter
        } label: {
            Text(filter.title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    
    // MARK: - Control Cluster
    private var controlCluster: some View {
        HStack(spacing: 8) {
            controlButton(title: "Aurora Insight", systemImage: "sparkles") {
                showAuroraInsights = true
            }
            controlButton(title: "Recenter View", systemImage: "scope") {
                recenterView()
            }
            .help("Recenter the gravity field placeholder")
            controlButton(title: "Refresh Data", systemImage: "arrow.clockwise") {
                _Concurrency.Task { await refreshPriorities(animated: true) }
            }
            .disabled(isLoading)
            .help("Request the latest CPS priorities")
            controlButton(title: "Open in Focus Mode", systemImage: "timer") {
                openInFocusMode()
            }
            .help("Jump to Focus Mode with the same dataset")
        }
    }
    
    private func controlButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(stateColor.opacity(0.75))
    }
    
    // MARK: - Gravity Canvas
    private var gravityCanvas: some View {
        GlassPanel(tier: .overlay, cornerRadius: 28) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Priority Signals")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(glassColorSystem.textPrimary())
                        Text(syncStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Label("\(priorityItems.count) items", systemImage: "list.number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 18)
                
                GlassDivider()
                
            ZStack {
                if glassColorSystem.isARTEEnabled {
                    glassColorSystem.emotionalBackgroundShift()
                        .opacity(0.28)
                            .blur(radius: 80)
                }
                    VStack(alignment: .leading, spacing: 20) {
                        if isLoading {
                            loadingState
                        } else if priorityItems.isEmpty {
                            emptyState
                        } else {
                            priorityList
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 24)
            }
            .padding(28)
            .frame(maxWidth: .infinity, minHeight: 380, alignment: .topLeading)
        }
    }
    
    private var priorityList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(priorityItems) { item in
                FocusPriorityItemCard(item: item, accentColor: stateColor)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(stateColor.opacity(0.22 - Double(index) * 0.06), lineWidth: 2)
                        .frame(width: 80 + CGFloat(index * 28), height: 80 + CGFloat(index * 28))
                        .rotationEffect(.degrees(orbitRotation + Double(index) * 90))
                }
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(stateColor)
            }
            .frame(width: 160, height: 160)
            .onAppear {
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    orbitRotation = 360
                }
            }
            .onDisappear {
                orbitRotation = 0
            }
            
            VStack(spacing: 8) {
                Text("Nothing's pulling your attention right now.")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(glassColorSystem.textPrimary())
                Text("Start a Focus Session or open your Tasks to set priorities.")
                    .font(.body)
                    .foregroundColor(glassColorSystem.textSecondary())
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(stateColor.opacity(0.15), lineWidth: 3)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(stateColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(loadingRotation))
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    loadingRotation = 360
                }
            }
            .onDisappear {
                loadingRotation = 0
            }
            Text("Calculating priorities…")
                .font(.subheadline)
                .foregroundColor(glassColorSystem.textSecondary())
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }
    
    // MARK: - Actions & Helpers
    @MainActor
    private func refreshPriorities(animated: Bool) async {
        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoading = true
            }
        } else {
            isLoading = true
        }
        
        let items: [PriorityItem]
        if let key = selectedFilter.engineKey {
            items = PriorityEngine.shared.getTopObjects(ofType: key, limit: 20, modelContext: modelContext)
        } else {
            items = PriorityEngine.shared.getTopObjects(limit: 20, modelContext: modelContext)
        }
        
        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                priorityItems = items
                isLoading = false
            }
        } else {
            priorityItems = items
            isLoading = false
        }
    }
    
    private func openInFocusMode() {
        NotificationCenter.default.post(name: .switchTab, object: TabIdentifier.focusMode)
    }
    
    private func recenterView() {
        recenterToken = UUID()
    }
    
    private func startPulse() {
        isPulsing = true
    }
    
    private func stopPulse() {
        isPulsing = false
    }
    
    private var syncStatusText: String {
        if let lastSync = PriorityEngine.shared.lastSyncTime {
            return "Synced \(timeAgo(from: lastSync))"
        } else if isLoading {
            return "Syncing…"
        } else {
            return "Waiting for CPS sync"
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "just now"
        }
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m ago"
        }
        let hours = Int(interval / 3600)
        if hours < 24 {
            return "\(hours)h ago"
        }
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }
    
    private var stateColor: Color {
        switch glassColorSystem.emotionalState {
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
        switch glassColorSystem.emotionalState {
        case .calm:
            return "Calm"
        case .focused:
            return "Flow"
        case .fatigued:
            return "Fatigue"
        case .energized:
            return "Energized"
        case .reflective:
            return "Reflective"
        }
    }
}

// MARK: - Filter Enum
private enum FocusGravityFilter: CaseIterable {
    case all
    case tasks
    case notes
    
    var title: String {
        switch self {
        case .all:
            return "All"
        case .tasks:
            return "Tasks Only"
        case .notes:
            return "Notes Only"
        }
    }
    
    var engineKey: String? {
        switch self {
        case .all:
            return nil
        case .tasks:
            return "task"
        case .notes:
            return "note"
        }
    }
}

// MARK: - Priority Card
private struct FocusPriorityItemCard: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    let item: PriorityItem
    let accentColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 54, height: 54)
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", item.score * 100))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(accentColor)
                    Text(item.objectType.uppercased())
                        .font(.caption2)
                        .foregroundColor(glassColorSystem.textSecondary())
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(glassColorSystem.textPrimary())
                    .lineLimit(2)
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundColor(glassColorSystem.textSecondary())
                        .lineLimit(3)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(glassColorSystem.glassTint(for: .surface).opacity(glassColorSystem.isARTEEnabled ? 0.24 : 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accentColor.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Aurora Insight Placeholder
private struct AuroraInsightPlaceholder: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.dismiss) private var dismiss
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(accentColor)
                Text("Aurora Insight")
                    .font(.title2.bold())
                    .foregroundColor(glassColorSystem.textPrimary())
                Spacer()
            }
            Text("Aurora will surface live focus insights here soon. For now, keep working through your top gravitational priorities—Aurora is listening.")
                .font(.system(size: 14))
                .foregroundColor(glassColorSystem.textSecondary())
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Spacer()
                Button("Got it") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(accentColor)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

// MARK: - Preview
#Preview {
    FocusGravityView()
        .modelContainer(for: [PriorityScore.self, FocusOSShared.Task.self, FocusOSShared.Project.self], inMemory: true)
        .environmentObject(GlassColorSystem())
}

