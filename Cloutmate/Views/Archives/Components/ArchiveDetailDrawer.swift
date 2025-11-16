//
//  ArchiveDetailDrawer.swift
//  Cloutmate
//
//  Archives V2 - Archive detail drawer
//

import SwiftUI
import SwiftData
import CloutmateShared
import os.log

struct ArchiveDetailDrawer: View {
    let archiveItem: ArchiveItem
    @Binding var isPresented: Bool
    let onRestore: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var reflection: ArchiveReflection?
    @State private var toneTimeline: [ReactiveThemeManager.ToneSnapshot] = []
    @State private var relatedEdges: [MemoryEdge] = []
    @State private var isLoading = true
    
    private var drawerWidth: CGFloat { 520 }
    
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
                                withAnimation(GlassMotion.Easing.modalOpen) {
                                    isPresented = false
                                }
                            }
                            .transition(.opacity)
                        
                        // Drawer
                        VStack(spacing: 0) {
                            V2DrawerScaffold(
                                accentGradient: accentGradient,
                                showsSidebar: false,
                                header: { headerContent },
                                content: { drawerContent },
                                sidebar: { EmptyView() }
                            )
                        }
                        .frame(width: drawerWidth)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    private var headerContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(archiveItem.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                HStack(spacing: 8) {
                    Text(archiveItem.entityType)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(entityColor.opacity(0.2))
                        .foregroundStyle(entityColor)
                        .cornerRadius(6)
                    
                    if let createdAt = getCreatedAt() {
                        Text("Created \(createdAt, style: .date)")
                            .font(.caption)
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                GlassButton(
                    "Restore",
                    icon: "arrow.counterclockwise",
                    style: .standard,
                    role: .primary,
                    tintColor: .kosmicBlue
                ) {
                    onRestore()
                    withAnimation(GlassMotion.Easing.modalOpen) {
                    isPresented = false
                }
                }
                
                GlassButton(
                    nil,
                    icon: "xmark",
                    style: .iconOnly,
                    role: .surface
                ) {
                    withAnimation(GlassMotion.Easing.modalOpen) {
                        isPresented = false
                    }
                }
                .accessibilityLabel("Close")
            }
        }
    }
    
    @ViewBuilder
    private var drawerContent: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
        .padding()
        } else {
            VStack(alignment: .leading, spacing: 24) {
                summarySection
                moodHistorySection
                reflectionSection
                auroraCommentarySection
            }
            .padding(.vertical, 8)
        }
    }
    
    private var entityColor: Color {
        switch archiveItem {
        case .project: return .kosmicBlue
        case .area: return .gray
        case .note: return .kosmicPurple
        case .artifact: return .kosmicGreen
        case .draft: return .kosmicBlue
        }
    }
    
    private func getCreatedAt() -> Date? {
        switch archiveItem {
        case .project(let p): return p.createdAt
        case .area(let a): return a.createdAt
        case .note(let n): return n.createdAt
        case .artifact(let a): return a.createdAt
        case .draft(let d): return d.createdAt
        }
    }
    
    private var summarySection: some View {
        DrawerSection(title: "Summary", icon: "doc.text") {
            if let reflectionText = reflection?.reflectionText {
                Text(reflectionText)
                    .font(.body)
                    .foregroundStyle(glassColorSystem.textSecondary())
            } else {
                Text("No summary available")
                    .font(.body)
                    .foregroundStyle(glassColorSystem.textSecondary().opacity(0.6))
                    .italic()
            }
        }
    }
    
    private var moodHistorySection: some View {
        DrawerSection(title: "Mood History Timeline", icon: "chart.line.uptrend.xyaxis") {
            if toneTimeline.isEmpty {
                Text("No mood history available")
                    .font(.caption)
                    .foregroundStyle(glassColorSystem.textSecondary().opacity(0.6))
                    .italic()
            } else {
                // Mini sparkline visualization
                HStack(spacing: 2) {
                    ForEach(Array(toneTimeline.enumerated()), id: \.offset) { index, snapshot in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(snapshot.color)
                            .frame(width: 4, height: 20 * snapshot.confidence)
                    }
                }
                .frame(height: 40)
            }
        }
    }
    
    private var reflectionSection: some View {
        DrawerSection(title: "Reflection Notes", icon: "note.text") {
            if let reflectionText = reflection?.reflectionText {
                Text(reflectionText)
                    .font(.body)
                    .foregroundStyle(glassColorSystem.textSecondary())
            } else {
                Text("No reflection available")
                    .font(.body)
                    .foregroundStyle(glassColorSystem.textSecondary().opacity(0.6))
                    .italic()
            }
        }
    }
    
    private var auroraCommentarySection: some View {
        DrawerSection(title: "Aurora Commentary", icon: "sparkles") {
            if let commentary = reflection?.auroraCommentary, !commentary.isEmpty {
                Text(commentary)
                    .font(.body)
                    .foregroundStyle(Color.kosmicPurple.opacity(0.9))
                    .italic()
            } else {
                Text("No commentary available")
                    .font(.body)
                    .foregroundStyle(glassColorSystem.textSecondary().opacity(0.6))
                    .italic()
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        
        // Load reflection - extract UUID from enum first
        let entityId = archiveItem.id
        let reflectionDescriptor = FetchDescriptor<ArchiveReflection>(
            predicate: #Predicate { reflection in
                reflection.entityId == entityId
            }
        )
        
        if let existing = try? modelContext.fetch(reflectionDescriptor).first {
            await MainActor.run {
                reflection = existing
            }
        } else {
            // Generate reflection if missing
            do {
                let newReflection = try await ArchiveReflectionService.shared.generateReflection(
                    for: archiveItem,
                    modelContext: modelContext
                )
                await MainActor.run {
                    reflection = newReflection
                }
            } catch {
                logger.error("Failed to generate reflection: \(error.localizedDescription)")
            }
        }
        
        // Load tone timeline
        if let archivedAt = archiveItem.archivedAt {
            let startDate = getCreatedAt() ?? archivedAt
            let timeline = ReactiveThemeManager.shared.toneTimeline(
                for: archiveItem.id,
                startDate: startDate,
                endDate: archivedAt,
                modelContext: modelContext
            )
            await MainActor.run {
                toneTimeline = timeline
            }
        }
        
        // Load related items
        let edges = MemoryGraphService.shared.retrieveArchivedRelationships(
            for: archiveItem.id,
            modelContext: modelContext
        )
        await MainActor.run {
            relatedEdges = edges
        }
        
        isLoading = false
    }
}

import os.log
private let logger = Logger(subsystem: "com.kosmicapps.Cloutmate", category: "ArchiveDetailDrawer")

#Preview {
    @Previewable @State var isPresented = true
    
    ArchiveDetailDrawer(
        archiveItem: .project(CloutmateShared.Project(title: "Sample Project")),
        isPresented: $isPresented,
        onRestore: {}
    )
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [ArchiveReflection.self])
}

