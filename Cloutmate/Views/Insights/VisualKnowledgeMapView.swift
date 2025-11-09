//
//  VisualKnowledgeMapView.swift
//  Cloutmate
//
//  Interactive Knowledge Map - Force-directed graph visualization
//

import SwiftUI
import SwiftData
import CoreGraphics

struct VisualKnowledgeMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryNode.importance, order: .reverse) private var allNodes: [MemoryNode]
    @Query private var allEdges: [MemoryEdge]
    @Query private var allThemes: [ThemeNode]
    
    @State private var selectedNode: MemoryNode?
    @State private var hoveredNode: MemoryNode?
    @State private var selectedTheme: ThemeNode?
    @State private var layoutAlgorithm: LayoutAlgorithm = .forceDirected
    @State private var zoomLevel: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var nodePositions: [UUID: CGPoint] = [:]
    @State private var isAnimating = false
    @State private var showAINarration = true
    @State private var narrationText: String = ""
    
    enum LayoutAlgorithm: String, CaseIterable {
        case forceDirected = "Force-Directed"
        case hierarchical = "Hierarchical"
        case circular = "Circular"
    }
    
    var filteredNodes: [MemoryNode] {
        if let theme = selectedTheme {
            return allNodes.filter { theme.memberNodeIds.contains($0.id) }
        }
        return allNodes
    }
    
    var filteredEdges: [MemoryEdge] {
        let nodeIds = Set(filteredNodes.map { $0.id })
        return allEdges.filter { edge in
            nodeIds.contains(edge.sourceNodeId) && nodeIds.contains(edge.targetNodeId)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            
            HSplitView {
                // Left sidebar - Controls and themes
                sidebar
                    .frame(minWidth: 250, maxWidth: 350)
                
                // Center - Graph canvas
                ZStack {
                    graphCanvas
                        .background(Color(.windowBackgroundColor))
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    zoomLevel = max(0.5, min(3.0, value))
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    panOffset = CGSize(
                                        width: panOffset.width + value.translation.width,
                                        height: panOffset.height + value.translation.height
                                    )
                                }
                        )
                    
                    // AI Narration overlay
                    if showAINarration && !narrationText.isEmpty {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                narrationBubble
                                    .padding()
                            }
                        }
                    }
                }
                
                // Right sidebar - Node details
                if let node = selectedNode {
                    nodeDetailSidebar(node: node)
                        .frame(minWidth: 250, maxWidth: 350)
                }
            }
        }
        .task {
            await calculateLayout()
            generateNarration()
        }
        .onChange(of: selectedTheme) { _, _ in
            Task {
                await calculateLayout()
                generateNarration()
            }
        }
        .onChange(of: layoutAlgorithm) { _, _ in
            Task {
                await calculateLayout()
            }
        }
    }
    
    private var toolbar: some View {
        HStack {
            Text("Visual Knowledge Map")
                .font(.title2.bold())
            
            Spacer()
            
            // Layout algorithm picker
            Picker("Layout", selection: $layoutAlgorithm) {
                ForEach(LayoutAlgorithm.allCases, id: \.self) { algorithm in
                    Text(algorithm.rawValue).tag(algorithm)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            
            Toggle("AI Narration", isOn: $showAINarration)
            
            Button(action: { Task { await calculateLayout() } }) {
                Label("Recalculate", systemImage: "arrow.clockwise")
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Theme filter
            VStack(alignment: .leading, spacing: 12) {
                Text("Filter by Theme")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                Button(action: { selectedTheme = nil }) {
                    HStack {
                        Text("All Nodes")
                        Spacer()
                        if selectedTheme == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(selectedTheme == nil ? Color.kosmicBlue.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                
                ForEach(allThemes.prefix(10), id: \.id) { theme in
                    Button(action: { selectedTheme = theme }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(theme.label)
                                    .font(.subheadline.bold())
                                Spacer()
                                if selectedTheme?.id == theme.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                            
                            Text("\(theme.memberNodeIds.count) nodes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(selectedTheme?.id == theme.id ? Color.kosmicBlue.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
            
            Divider()
            
            // Stats
            VStack(alignment: .leading, spacing: 12) {
                Text("Graph Stats")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                StatRow(label: "Nodes", value: "\(filteredNodes.count)")
                StatRow(label: "Edges", value: "\(filteredEdges.count)")
                StatRow(label: "Themes", value: "\(allThemes.count)")
                StatRow(label: "Clusters", value: "\(clusterCount)")
            }
            .padding(.bottom)
        }
    }
    
    private var graphCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw edges
                ForEach(filteredEdges, id: \.id) { edge in
                    if let sourcePos = nodePositions[edge.sourceNodeId],
                       let targetPos = nodePositions[edge.targetNodeId] {
                        EdgeView(
                            from: sourcePos,
                            to: targetPos,
                            weight: edge.weight,
                            type: edge.type
                        )
                        .stroke(
                            edgeColor(for: edge.type),
                            lineWidth: CGFloat(edge.weight * 3)
                        )
                    }
                }
                
                // Draw nodes
                ForEach(filteredNodes, id: \.id) { node in
                    if let position = nodePositions[node.id] {
                        NodeView(
                            node: node,
                            position: position,
                            isSelected: selectedNode?.id == node.id,
                            isHovered: hoveredNode?.id == node.id
                        )
                        .position(
                            x: position.x * zoomLevel + panOffset.width + geometry.size.width / 2,
                            y: position.y * zoomLevel + panOffset.height + geometry.size.height / 2
                        )
                        .onTapGesture {
                            selectedNode = node
                        }
                        .onHover { hovering in
                            hoveredNode = hovering ? node : nil
                        }
                    }
                }
            }
        }
    }
    
    private var narrationBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.kosmicPurple)
                Text("Aurora's Insight")
                    .font(.caption.bold())
                Spacer()
                Button(action: { showAINarration = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text(narrationText)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .frame(maxWidth: 300)
        .shadow(radius: 8)
    }
    
    private func nodeDetailSidebar(node: MemoryNode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Node Details")
                    .font(.title2.bold())
                
                GroupBox("Properties") {
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(label: "Type", value: node.nodeType)
                        DetailRow(label: "Importance", value: String(format: "%.2f", node.importance))
                        DetailRow(label: "Access Count", value: "\(node.accessCount)")
                        DetailRow(label: "Edge Count", value: "\(node.edgeCount)")
                    }
                }
                
                GroupBox("Content") {
                    Text(node.content)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Connected nodes
                let connectedNodes = getConnectedNodes(for: node)
                if !connectedNodes.isEmpty {
                    GroupBox("Connections") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(connectedNodes.prefix(5), id: \.id) { connectedNode in
                                Button(action: { selectedNode = connectedNode }) {
                                    HStack {
                                        Text(connectedNode.label)
                                            .font(.caption)
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var clusterCount: Int {
        // Calculate number of distinct clusters
        var clusters: Set<UUID> = []
        for theme in allThemes {
            clusters.insert(theme.id)
        }
        return clusters.count
    }
    
    private func calculateLayout() async {
        isAnimating = true
        defer { isAnimating = false }
        
        let nodes = filteredNodes
        guard !nodes.isEmpty else { return }
        
        var positions: [UUID: CGPoint] = [:]
        
        switch layoutAlgorithm {
        case .forceDirected:
            positions = await calculateForceDirectedLayout(nodes: nodes, edges: filteredEdges)
        case .hierarchical:
            positions = calculateHierarchicalLayout(nodes: nodes, edges: filteredEdges)
        case .circular:
            positions = calculateCircularLayout(nodes: nodes)
        }
        
        await MainActor.run {
            nodePositions = positions
        }
    }
    
    private func calculateForceDirectedLayout(
        nodes: [MemoryNode],
        edges: [MemoryEdge]
    ) async -> [UUID: CGPoint] {
        // Simplified force-directed layout
        // In production, would use a more sophisticated algorithm
        
        var positions: [UUID: CGPoint] = [:]
        let center = CGPoint(x: 0, y: 0)
        let radius: CGFloat = 200
        
        // Initialize positions in a circle
        for (index, node) in nodes.enumerated() {
            let angle = Double(index) * 2 * .pi / Double(nodes.count)
            positions[node.id] = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
        }
        
        // Simple force-directed iterations
        for _ in 0..<50 {
            var newPositions = positions
            
            for node in nodes {
                var forceX: CGFloat = 0
                var forceY: CGFloat = 0
                
                let currentPos = positions[node.id] ?? center
                
                // Repulsion from other nodes
                for otherNode in nodes where otherNode.id != node.id {
                    if let otherPos = positions[otherNode.id] {
                        let dx = currentPos.x - otherPos.x
                        let dy = currentPos.y - otherPos.y
                        let distance = sqrt(dx * dx + dy * dy)
                        if distance > 0 {
                            let repulsion = 1000 / (distance * distance)
                            forceX += (dx / distance) * repulsion
                            forceY += (dy / distance) * repulsion
                        }
                    }
                }
                
                // Attraction from edges
                for edge in edges where edge.sourceNodeId == node.id {
                    if let targetPos = positions[edge.targetNodeId] {
                        let dx = targetPos.x - currentPos.x
                        let dy = targetPos.y - currentPos.y
                        let distance = sqrt(dx * dx + dy * dy)
                        if distance > 0 {
                            let attraction = distance * CGFloat(edge.weight) * 0.01
                            forceX += (dx / distance) * attraction
                            forceY += (dy / distance) * attraction
                        }
                    }
                }
                
                // Apply forces with damping
                let damping: CGFloat = 0.1
                let newX = currentPos.x + forceX * damping
                let newY = currentPos.y + forceY * damping
                newPositions[node.id] = CGPoint(x: newX, y: newY)
            }
            
            positions = newPositions
        }
        
        return positions
    }
    
    private func calculateHierarchicalLayout(
        nodes: [MemoryNode],
        edges: [MemoryEdge]
    ) -> [UUID: CGPoint] {
        var positions: [UUID: CGPoint] = [:]
        
        // Group nodes by importance
        let sortedNodes = nodes.sorted { $0.importance > $1.importance }
        let levels = 5
        let levelHeight: CGFloat = 150
        
        for (index, node) in sortedNodes.enumerated() {
            let level = min(levels - 1, Int(Double(index) / Double(sortedNodes.count / levels)))
            let nodesInLevel = sortedNodes.filter { node in
                let nodeLevel = min(levels - 1, Int(Double(sortedNodes.firstIndex(where: { $0.id == node.id }) ?? 0) / Double(sortedNodes.count / levels)))
                return nodeLevel == level
            }
            let nodeIndexInLevel = nodesInLevel.firstIndex(where: { $0.id == node.id }) ?? 0
            let spacing: CGFloat = 300
            let startX = -CGFloat(nodesInLevel.count - 1) * spacing / 2
            
            positions[node.id] = CGPoint(
                x: startX + CGFloat(nodeIndexInLevel) * spacing,
                y: CGFloat(level) * levelHeight
            )
        }
        
        return positions
    }
    
    private func calculateCircularLayout(nodes: [MemoryNode]) -> [UUID: CGPoint] {
        var positions: [UUID: CGPoint] = [:]
        let radius: CGFloat = 200
        
        for (index, node) in nodes.enumerated() {
            let angle = Double(index) * 2 * .pi / Double(nodes.count)
            positions[node.id] = CGPoint(
                x: radius * cos(angle),
                y: radius * sin(angle)
            )
        }
        
        return positions
    }
    
    private func generateNarration() {
        guard showAINarration else { return }
        
        if let theme = selectedTheme {
            narrationText = "This cluster represents '\(theme.label)' — \(theme.memberNodeIds.count) connected concepts showing \(theme.momentum > 0 ? "growing" : theme.momentum < 0 ? "declining" : "stable") momentum."
        } else {
            let topTheme = allThemes.max { $0.salience < $1.salience }
            if let theme = topTheme {
                narrationText = "Your knowledge map has \(allNodes.count) nodes connected by \(allEdges.count) relationships. The most prominent theme is '\(theme.label)' with \(Int(theme.salience * 100))% salience."
            } else {
                narrationText = "Your knowledge map is growing. As you create more content, connections will emerge."
            }
        }
    }
    
    private func getConnectedNodes(for node: MemoryNode) -> [MemoryNode] {
        let connectedIds = filteredEdges
            .filter { $0.sourceNodeId == node.id || $0.targetNodeId == node.id }
            .map { edge in
                edge.sourceNodeId == node.id ? edge.targetNodeId : edge.sourceNodeId
            }
        
        return filteredNodes.filter { connectedIds.contains($0.id) }
    }
    
    private func edgeColor(for type: MemoryEdgeType) -> Color {
        switch type {
        case .references: return .kosmicBlue
        case .similarTo: return .kosmicPurple
        case .partOf: return .kosmicGreen
        case .precedes: return .orange
        case .relatedTo: return .gray
        case .contradicts: return .red
        case .supports: return .kosmicGreen
        }
    }
}

// MARK: - Node View

struct NodeView: View {
    let node: MemoryNode
    let position: CGPoint
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(nodeColor)
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: isSelected ? .kosmicBlue : .black.opacity(0.2), radius: isSelected ? 8 : 4)
            
            if node.importance > 0.7 {
                Circle()
                    .stroke(Color.kosmicBlue, lineWidth: 2)
                    .frame(width: nodeSize + 4, height: nodeSize + 4)
            }
        }
        .overlay(
            Text(node.label.prefix(1).uppercased())
                .font(.caption.bold())
                .foregroundColor(.white),
            alignment: .center
        )
        .scaleEffect(isHovered ? 1.2 : 1.0)
        .animation(.spring(response: 0.2), value: isHovered)
    }
    
    private var nodeSize: CGFloat {
        baseSize + CGFloat(node.importance * 20)
    }
    
    private let baseSize: CGFloat = 20
    
    private var nodeColor: Color {
        switch node.type {
        case .workspaceObject: return .kosmicBlue
        case .concept: return .kosmicPurple
        case .theme: return .kosmicGreen
        case .conversation: return .orange
        case .session: return .kosmicBlue
        case .insight: return .kosmicPurple
        }
    }
}

// MARK: - Edge View

struct EdgeView: Shape {
    let from: CGPoint
    let to: CGPoint
    let weight: Double
    let type: MemoryEdgeType
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        return path
    }
}

// MARK: - Stat Row

struct StatRow: View {
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
        .padding(.horizontal)
    }
}

#Preview {
    VisualKnowledgeMapView()
        .modelContainer(for: [MemoryNode.self, MemoryEdge.self, ThemeNode.self], inMemory: true)
}

