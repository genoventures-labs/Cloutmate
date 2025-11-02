//
//  KnowledgeGraphView.swift
//  Cloutmate
//
//  Visual knowledge graph showing relationships between notes, projects, and tasks
//

import SwiftUI
import SwiftData
import CloutmateShared

struct KnowledgeGraphView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [CloutmateShared.Note]
    @Query private var projects: [CloutmateShared.Project]
    @Query private var tasks: [CloutmateShared.Task]
    @Query private var posts: [CloutmateShared.Post]
    
    @State private var selectedNode: GraphNode?
    @State private var layoutMode: LayoutMode = .forceDirected
    
    enum LayoutMode: String, CaseIterable {
        case hierarchical
        case forceDirected
        case radial
    }
    
    var nodes: [GraphNode] {
        var allNodes: [GraphNode] = []
        
        // Add note nodes
        for note in notes where !note.isArchived {
            allNodes.append(GraphNode(id: note.id, type: .note, title: note.title, entity: note))
        }
        
        // Add project nodes
        for project in projects {
            allNodes.append(GraphNode(id: project.id, type: .project, title: project.title, entity: project))
        }
        
        // Add task nodes with backlinks
        for task in tasks where task.status != .done {
            allNodes.append(GraphNode(id: task.id, type: .task, title: task.title, entity: task))
        }
        
        return allNodes
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Controls
            HStack {
                Picker("Layout", selection: $layoutMode) {
                    ForEach(LayoutMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                HStack(spacing: 16) {
                    LegendItem(icon: "doc.text", label: "Notes", count: notes.filter { !$0.isArchived }.count)
                    LegendItem(icon: "folder.fill", label: "Projects", count: projects.count)
                    LegendItem(icon: "checkmark.circle", label: "Tasks", count: tasks.filter { $0.status != .done }.count)
                }
            }
            .padding()
            .glassPanel(tier: .contentCard, cornerRadius: 12)
            .padding(.horizontal)
            
            // Graph visualization
            ZStack {
                // Background grid
                GraphGrid()
                
                // Nodes
                ForEach(nodes) { node in
                    GraphNodeView(node: node)
                        .position(x: 100 + CGFloat(node.id.uuidString.hashValue % 400),
                                 y: 100 + CGFloat(node.id.uuidString.hashValue % 300))
                        .onTapGesture {
                            selectedNode = node
                        }
                }
                
                // Lines showing backlinks (would use path drawing in real implementation)
                if let selected = selectedNode {
                    ForEach(backlinks(for: selected)) { linkedNode in
                        Path { path in
                            path.move(to: CGPoint(x: 100, y: 100))
                            path.addLine(to: CGPoint(x: 300, y: 200))
                        }
                        .stroke(Color.kosmicBlue.opacity(0.3), lineWidth: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
        .navigationTitle("Knowledge Graph")
        .sheet(item: $selectedNode) { node in
            NodeDetailSheet(node: node, notes: notes, projects: projects, tasks: tasks)
        }
    }
    
    private func backlinks(for node: GraphNode) -> [GraphNode] {
        // Find nodes that link to this one via backlinks
        switch node.type {
        case .note:
            // Find notes/projects/tasks that reference this note
            return nodes.filter { otherNode in
                switch otherNode.type {
                case .note:
                    if let note = otherNode.entity as? Note {
                        return note.backlinks.contains(node.id)
                    }
                case .project:
                    if let project = otherNode.entity as? Project {
                        return project.noteIds.contains(node.id)
                    }
                case .task:
                    return false // Tasks don't store backlinks array
                }
                return false
            }
        case .project:
            return nodes.filter { otherNode in
                // Find items linked to this project
                switch otherNode.type {
                case .note:
                    if let note = otherNode.entity as? Note {
                        return note.projectId == node.id
                    }
                case .task:
                    if let task = otherNode.entity as? Task {
                        return task.projectId == node.id
                    }
                default:
                    return false
                }
                return false
            }
        case .task:
            return []
        }
    }
}

struct GraphNode: Identifiable {
    let id: UUID
    let type: NodeType
    let title: String
    let entity: Any
    
    enum NodeType: String {
        case note
        case project
        case task
    }
    
    static func == (lhs: GraphNode, rhs: GraphNode) -> Bool {
        lhs.id == rhs.id
    }
}

struct GraphNodeView: View {
    let node: GraphNode
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: iconForType(node.type))
                .font(.title2)
                .foregroundStyle(colorForType(node.type).gradient)
            
            Text(node.title)
                .font(.caption2)
                .lineLimit(2)
                .frame(width: 80)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .glassPanel(tier: .contentCard, cornerRadius: 12, tintColor: colorForType(node.type).opacity(0.1))
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func iconForType(_ type: GraphNode.NodeType) -> String {
        switch type {
        case .note: return "doc.text"
        case .project: return "folder.fill"
        case .task: return "checkmark.circle"
        }
    }
    
    private func colorForType(_ type: GraphNode.NodeType) -> Color {
        switch type {
        case .note: return .kosmicPurple
        case .project: return .kosmicBlue
        case .task: return .kosmicGreen
        }
    }
}

struct GraphGrid: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let spacing: CGFloat = 50
                
                // Vertical lines
                var x: CGFloat = 0
                while x < geometry.size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    x += spacing
                }
                
                // Horizontal lines
                var y: CGFloat = 0
                while y < geometry.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    y += spacing
                }
            }
            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        }
    }
}

struct LegendItem: View {
    let icon: String
    let label: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption)
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.kosmicBlue)
                .cornerRadius(8)
        }
    }
}

struct NodeDetailSheet: View {
    let node: GraphNode
    let notes: [Note]
    let projects: [Project]
    let tasks: [Task]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack {
                        Image(systemName: iconForType(node.type))
                            .foregroundStyle(colorForType(node.type).gradient)
                            .font(.largeTitle)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(node.type.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(node.title)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                    .glassPanel(tier: .overlay, cornerRadius: 12)
                    .padding()
                    
                    // Backlinks count
                    let backlinkCount = countBacklinks()
                    if backlinkCount > 0 {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundStyle(Color.kosmicBlue)
                            Text("\(backlinkCount) connections")
                                .font(.subheadline)
                        }
                        .padding()
                        .glassPanel(tier: .contentCard, cornerRadius: 12)
                        .padding(.horizontal)
                    }
                }
            }
            .background(Color.clear)
            .navigationTitle("Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
    
    private func countBacklinks() -> Int {
        switch node.type {
        case .note:
            if let note = node.entity as? Note {
                return note.backlinks.count
            }
        case .project:
            if let project = node.entity as? Project {
                return project.noteIds.count + project.taskIds.count
            }
        case .task:
            return 0
        }
        return 0
    }
    
    private func iconForType(_ type: GraphNode.NodeType) -> String {
        switch type {
        case .note: return "doc.text"
        case .project: return "folder.fill"
        case .task: return "checkmark.circle"
        }
    }
    
    private func colorForType(_ type: GraphNode.NodeType) -> Color {
        switch type {
        case .note: return .kosmicPurple
        case .project: return .kosmicBlue
        case .task: return .kosmicGreen
        }
    }
}

#Preview {
    KnowledgeGraphView()
        .modelContainer(for: [CloutmateShared.Note.self, CloutmateShared.Project.self, CloutmateShared.Task.self])
}

