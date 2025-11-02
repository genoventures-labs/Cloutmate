//
//  ConceptGraphView.swift
//  Cloutmate
//
//  Phase 6.1 - Memory Graph Visualization
//

import SwiftUI
import SwiftData

struct ConceptGraphView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var themes: [ThemeNode] = []
    @State private var nodes: [MemoryNode] = []
    @State private var edges: [MemoryEdge] = []
    @State private var selectedTheme: ThemeNode?
    @State private var selectedNode: MemoryNode?
    @State private var graphVisualization: String = ""
    @State private var showDebugConsole = false
    
    var body: some View {
        HSplitView {
            // Left sidebar - Themes list
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Label("Active Themes", systemImage: "brain.head.profile")
                        .font(.headline)
                    Spacer()
                    Button(action: refreshGraph) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .padding()
                
                Divider()
                
                // Themes list
                if themes.isEmpty {
                    ContentUnavailableView(
                        "No Themes Yet",
                        systemImage: "brain",
                        description: Text("Enable Memory Graph in settings and start creating content")
                    )
                } else {
                    List(themes, id: \.id, selection: $selectedTheme) { theme in
                        ThemeRowView(theme: theme)
                            .tag(theme)
                    }
                }
            }
            .frame(minWidth: 250, maxWidth: 350)
            
            // Center - Graph visualization
            VStack(alignment: .leading, spacing: 0) {
                // Toolbar
                HStack {
                    Text(selectedTheme?.label ?? "Memory Graph")
                        .font(.title2.bold())
                    
                    Spacer()
                    
                    Button("Export DOT") {
                        exportGraphToDOT()
                    }
                    .disabled(nodes.isEmpty)
                    
                    Button("Debug Console") {
                        showDebugConsole.toggle()
                    }
                }
                .padding()
                
                Divider()
                
                // Graph canvas
                if let theme = selectedTheme {
                    ThemeDetailView(theme: theme, modelContext: modelContext)
                } else {
                    GraphOverviewView(
                        themes: themes,
                        nodes: nodes,
                        edges: edges
                    )
                }
            }
            .frame(minWidth: 400)
            
            // Right sidebar - Node details
            if let node = selectedNode {
                NodeDetailView(node: node, modelContext: modelContext)
                    .frame(minWidth: 250, maxWidth: 350)
            }
        }
        .sheet(isPresented: $showDebugConsole) {
            DebugConsoleView(modelContext: modelContext)
        }
        .task {
            refreshGraph()
        }
    }
    
    private func refreshGraph() {
        // Load themes
        themes = MemoryGraphService.shared.getActiveThemes(modelContext: modelContext)
        
        // Load all nodes
        let nodeDescriptor = FetchDescriptor<MemoryNode>()
        nodes = (try? modelContext.fetch(nodeDescriptor)) ?? []
        
        // Load all edges
        let edgeDescriptor = FetchDescriptor<MemoryEdge>()
        edges = (try? modelContext.fetch(edgeDescriptor)) ?? []
    }
    
    private func exportGraphToDOT() {
        let dot = MemoryGraphDebug.shared.exportToDOT(modelContext: modelContext, limit: 100)
        
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(dot, forType: .string)
        #endif
    }
}

// MARK: - Theme Row

struct ThemeRowView: View {
    let theme: ThemeNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(theme.label)
                    .font(.headline)
                
                Spacer()
                
                if theme.isActive {
                    Circle()
                        .fill(.kosmicGreen)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(theme.themeDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label("\(theme.memberNodeIds.count)", systemImage: "circle.grid.3x3")
                    .font(.caption)
                
                Spacer()
                
                Text(String(format: "%.0f%%", theme.salience * 100))
                    .font(.caption.bold())
                    .foregroundColor(salienceColor)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var salienceColor: Color {
        if theme.salience > 0.7 { return .kosmicGreen }
        if theme.salience > 0.4 { return .kosmicBlue }
        return .gray
    }
}

// MARK: - Graph Overview

struct GraphOverviewView: View {
    let themes: [ThemeNode]
    let nodes: [MemoryNode]
    let edges: [MemoryEdge]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Stats
                HStack(spacing: 16) {
                    StatCard(
                        title: "Themes",
                        value: "\(themes.count)",
                        icon: "brain.head.profile",
                        color: .kosmicPurple
                    )
                    
                    StatCard(
                        title: "Nodes",
                        value: "\(nodes.count)",
                        icon: "circle.grid.3x3",
                        color: .kosmicBlue
                    )
                    
                    StatCard(
                        title: "Edges",
                        value: "\(edges.count)",
                        icon: "arrow.triangle.branch",
                        color: .kosmicGreen
                    )
                }
                .padding(.horizontal)
                
                // Theme cards
                ForEach(themes.prefix(6), id: \.id) { theme in
                    ThemeCard(theme: theme)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

struct ThemeCard: View {
    let theme: ThemeNode
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(theme.label)
                        .font(.title3.bold())
                    
                    Spacer()
                    
                    Text(String(format: "%.0f%%", theme.salience * 100))
                        .font(.headline)
                        .foregroundColor(.kosmicBlue)
                }
                
                Text(theme.themeDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if !theme.keywords.isEmpty {
                    HStack {
                        ForEach(theme.keywords.prefix(5), id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.kosmicBlue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
                
                HStack {
                    Label("\(theme.memberNodeIds.count) nodes", systemImage: "circle.grid.3x3")
                    Spacer()
                    Label("Momentum: \(momentumLabel)", systemImage: momentumIcon)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
        }
    }
    
    private var momentumLabel: String {
        if theme.momentum > 0.1 { return "Growing" }
        if theme.momentum < -0.1 { return "Declining" }
        return "Stable"
    }
    
    private var momentumIcon: String {
        if theme.momentum > 0.1 { return "arrow.up.right" }
        if theme.momentum < -0.1 { return "arrow.down.right" }
        return "arrow.right"
    }
}

// MARK: - Theme Detail View

struct ThemeDetailView: View {
    let theme: ThemeNode
    let modelContext: ModelContext
    
    @State private var memberNodes: [MemoryNode] = []
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Theme header
                VStack(alignment: .leading, spacing: 12) {
                    Text(theme.label)
                        .font(.largeTitle.bold())
                    
                    Text(theme.themeDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        MetricBadge(
                            label: "Salience",
                            value: String(format: "%.0f%%", theme.salience * 100),
                            color: .kosmicBlue
                        )
                        
                        MetricBadge(
                            label: "Coherence",
                            value: String(format: "%.0f%%", theme.coherence * 100),
                            color: .kosmicGreen
                        )
                        
                        MetricBadge(
                            label: "Members",
                            value: "\(theme.memberNodeIds.count)",
                            color: .kosmicPurple
                        )
                    }
                }
                .padding()
                
                Divider()
                
                // Member nodes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Member Nodes")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(memberNodes, id: \.id) { node in
                        NodeCard(node: node)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .task {
            loadMemberNodes()
        }
    }
    
    private func loadMemberNodes() {
        memberNodes = theme.memberNodeIds.compactMap { nodeId in
            let descriptor = FetchDescriptor<MemoryNode>(
                predicate: #Predicate { node in
                    node.id == nodeId
                }
            )
            return try? modelContext.fetch(descriptor).first
        }
    }
}

struct MetricBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NodeCard: View {
    let node: MemoryNode
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(node.label)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(String(format: "%.2f", node.importance))
                        .font(.caption.bold())
                        .foregroundColor(.kosmicBlue)
                }
                
                Text(node.content.prefix(150) + (node.content.count > 150 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                HStack {
                    Text(node.nodeType)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text("Accessed \(node.accessCount)x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
}

// MARK: - Node Detail View

struct NodeDetailView: View {
    let node: MemoryNode
    let modelContext: ModelContext
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Node Details")
                    .font(.title2.bold())
                
                GroupBox("Properties") {
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(label: "Type", value: node.nodeType)
                        DetailRow(label: "Importance", value: String(format: "%.2f", node.importance))
                        DetailRow(label: "Access Count", value: "\(node.accessCount)")
                        DetailRow(label: "Embedding Dims", value: "\(node.embeddingDimensions)")
                    }
                }
                
                GroupBox("Content") {
                    Text(node.content)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GroupBox("Timeline") {
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(label: "Created", value: node.createdAt.formatted())
                        DetailRow(label: "Last Accessed", value: node.lastAccessedAt.formatted())
                    }
                }
            }
            .padding()
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }
}

// MARK: - Debug Console

struct DebugConsoleView: View {
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var statistics = ""
    @State private var telemetryReport = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Memory Graph Debug Console")
                    .font(.title2.bold())
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding()
            
            Divider()
            
            TabView {
                // Statistics
                ScrollView {
                    Text(statistics)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar")
                }
                
                // Telemetry
                ScrollView {
                    Text(telemetryReport)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                .tabItem {
                    Label("Telemetry", systemImage: "waveform.path.ecg")
                }
            }
        }
        .frame(width: 600, height: 500)
        .task {
            statistics = MemoryGraphDebug.shared.printStatistics(modelContext: modelContext)
            telemetryReport = MemoryGraphTelemetry.shared.generateDebugReport(modelContext: modelContext)
        }
    }
}

#Preview {
    ConceptGraphView()
        .modelContainer(for: [MemoryNode.self, MemoryEdge.self, ThemeNode.self])
}

