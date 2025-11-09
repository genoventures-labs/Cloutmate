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
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var reflection: ArchiveReflection?
    @State private var toneTimeline: [ReactiveThemeManager.ToneSnapshot] = []
    @State private var relatedEdges: [MemoryEdge] = []
    @State private var isLoading = true
    
    private var drawerWidth: CGFloat { 480 }
    
    var body: some View {
        Group {
            if isPresented {
                GeometryReader { geometry in
                    ZStack(alignment: .trailing) {
                        // Backdrop
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(GlassMotion.Easing.modalOpen) {
                                    isPresented = false
                                }
                            }
                            .transition(.opacity)
                        
                        // Drawer
                        VStack(spacing: 0) {
                            // Header
                            headerSection
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 20) {
                                    if isLoading {
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                    } else {
                                        summarySection
                                        moodHistorySection
                                        reflectionSection
                                        auroraCommentarySection
                                    }
                                }
                                .padding()
                            }
                        }
                        .frame(width: drawerWidth)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(.ultraThinMaterial)
                        .transition(.move(edge: .trailing))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(archiveItem.title)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                
                HStack(spacing: 8) {
                    Text(archiveItem.entityType)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(entityColor.opacity(0.2))
                        .foregroundColor(entityColor)
                        .cornerRadius(6)
                    
                    if let createdAt = getCreatedAt() {
                        Text("Created \(createdAt, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                GlassButton(
                    "Restore",
                    icon: "arrow.counterclockwise",
                    style: .standard,
                    tintColor: .kosmicBlue
                ) {
                    onRestore()
                    isPresented = false
                }
                
                Button(action: {
                    withAnimation(GlassMotion.Easing.modalOpen) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
            
            if let reflectionText = reflection?.reflectionText {
                Text(reflectionText)
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                Text("No summary available")
                    .font(.body)
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
            }
        }
        .padding()
        .background(GlassPanel(tier: .contentCard, cornerRadius: 12) {
            Color.clear
        })
    }
    
    private var moodHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood History Timeline")
                .font(.headline)
            
            if toneTimeline.isEmpty {
                Text("No mood history available")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
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
        .padding()
        .background(GlassPanel(tier: .contentCard, cornerRadius: 12) {
            Color.clear
        })
    }
    
    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reflection Notes")
                .font(.headline)
            
            if let reflectionText = reflection?.reflectionText {
                Text(reflectionText)
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                Text("No reflection available")
                    .font(.body)
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
            }
        }
        .padding()
        .background(GlassPanel(tier: .contentCard, cornerRadius: 12) {
            Color.clear
        })
    }
    
    private var auroraCommentarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.kosmicPurple)
                Text("Aurora Commentary")
                    .font(.headline)
            }
            
            if let commentary = reflection?.auroraCommentary, !commentary.isEmpty {
                Text(commentary)
                    .font(.body)
                    .foregroundColor(.kosmicPurple.opacity(0.9))
                    .italic()
            } else {
                Text("No commentary available")
                    .font(.body)
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
            }
        }
        .padding()
        .background(GlassPanel(tier: .contentCard, cornerRadius: 12) {
            Color.clear
        })
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

