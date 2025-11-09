//
//  InboxCaptureDrawer.swift
//  Cloutmate
//
//  Inbox V2 - Capture Drawer with Aurora Integration
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

struct InboxCaptureDrawer: View {
    @Bindable var item: InboxItem
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityGlassManager) private var accessibilityManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var editableTitle: String = ""
    @State private var editableContent: String = ""
    @State private var auroraSuggestion: AuroraSuggestion?
    @State private var linkedItems: [LinkedItem] = []
    @State private var isLoadingSuggestion = false
    
    struct AuroraSuggestion {
        let destination: String // "task", "note", "draft", "project"
        let confidence: Double
        let reasoning: String
        let tone: String?
    }
    
    struct LinkedItem {
        let id: UUID
        let title: String
        let type: String
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Backdrop
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        saveChanges()
                        withAnimation(GlassMotion.Easing.modalOpen) {
                            isPresented = false
                        }
                    }
                    .transition(.opacity)
                
                // Drawer
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Title", text: $editableTitle)
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.semibold)
                                .textFieldStyle(.plain)
                            
                            HStack(spacing: 8) {
                                TypeBadge(type: item.itemType)
                                
                                if let suggestion = auroraSuggestion {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.caption2)
                                        Text("\(suggestion.tone ?? "Creative") • \(Int(suggestion.confidence * 100))% confidence")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.kosmicPurple)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            saveChanges()
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
                    .padding(20)
                    .background(.ultraThinMaterial)
                    
                    // Body
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Aurora Suggestion Banner
                            if let suggestion = auroraSuggestion {
                                AuroraSuggestionBanner(suggestion: suggestion) {
                                    convertToSuggestedDestination(suggestion.destination)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                            }
                            
                            // Linked Context
                            if !linkedItems.isEmpty {
                                LinkedContextSection(items: linkedItems)
                                    .padding(.horizontal, 20)
                            }
                            
                            // Content Editor
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Content")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                if item.itemType == "voice" {
                                    // Transcript Viewer
                                    Text(editableContent)
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.primary)
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(glassColorSystem.cardColor())
                                        )
                                } else {
                                    // Markdown Editor
                                    TextEditor(text: $editableContent)
                                        .font(.system(.body, design: .rounded))
                                        .frame(minHeight: 200)
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(glassColorSystem.cardColor())
                                        )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 16)
                    }
                    
                    // Footer: Convert Actions
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ConvertActionButton(
                                icon: "checkmark.circle",
                                title: "Task",
                                color: .kosmicBlue,
                                action: { convertToTask() }
                            )
                            
                            ConvertActionButton(
                                icon: "doc.text",
                                title: "Note",
                                color: .kosmicPurple,
                                action: { convertToNote() }
                            )
                            
                            ConvertActionButton(
                                icon: "square.and.pencil",
                                title: "Draft",
                                color: .orange,
                                action: { convertToDraft() }
                            )
                            
                            ConvertActionButton(
                                icon: "folder.fill",
                                title: "Project",
                                color: .kosmicGreen,
                                action: { convertToProject() }
                            )
                        }
                        
                        Button(action: { archiveItem() }) {
                            HStack {
                                Image(systemName: "archivebox")
                                Text("Archive")
                            }
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(glassColorSystem.cardColor())
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                }
                .frame(width: min(400, geometry.size.width * 0.4))
                .frame(maxHeight: .infinity, alignment: .top)
                .background(.ultraThinMaterial)
                .transition(reduceMotion ? .opacity : .move(edge: .trailing))
            }
        }
        .onAppear {
            editableTitle = item.content.prefix(50).description
            editableContent = item.content
            analyzeWithAurora()
            findLinkedItems()
        }
        .animation(reduceMotion ? nil : GlassMotion.Easing.modalOpen, value: isPresented)
        .accessibilityLabel("Inbox capture drawer")
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    
    private func saveChanges() {
        item.content = editableContent
        try? modelContext.save()
    }
    
    private func analyzeWithAurora() {
        _Concurrency.Task {
            await MainActor.run {
                isLoadingSuggestion = true
            }
            
            do {
                let prompt = """
                Analyze this inbox entry and suggest destination: Task, Note, Draft, or Project.
                Return JSON: {"suggestion": "task|note|draft|project", "confidence": 0.0-1.0, "reasoning": "brief explanation", "tone": "creative|analytical|emotional|actionable"}
                
                Entry: \(item.content)
                """
                
                let response = try await CoreResponseService.shared.generateResponse(
                    for: prompt,
                    modelContext: modelContext
                )
                
                // Parse JSON response
                if let jsonData = response.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let suggestionStr = json["suggestion"] as? String,
                   let confidence = json["confidence"] as? Double {
                    
                    let reasoning = json["reasoning"] as? String ?? ""
                    let tone = json["tone"] as? String
                    
                    await MainActor.run {
                        auroraSuggestion = AuroraSuggestion(
                            destination: suggestionStr,
                            confidence: confidence,
                            reasoning: reasoning,
                            tone: tone
                        )
                        isLoadingSuggestion = false
                    }
                } else {
                    await MainActor.run {
                        isLoadingSuggestion = false
                    }
                }
            } catch {
                print("Aurora analysis failed: \(error)")
                await MainActor.run {
                    isLoadingSuggestion = false
                }
            }
        }
    }
    
    private func findLinkedItems() {
        // Search for matching Project/Task titles (fuzzy match)
        let descriptor = FetchDescriptor<Project>()
        if let projects = try? modelContext.fetch(descriptor) {
            for project in projects {
                if item.content.localizedCaseInsensitiveContains(project.title) {
                    linkedItems.append(LinkedItem(id: project.id, title: project.title, type: "project"))
                }
            }
        }
        
        let taskDescriptor = FetchDescriptor<Task>()
        if let tasks = try? modelContext.fetch(taskDescriptor) {
            for task in tasks {
                if item.content.localizedCaseInsensitiveContains(task.title) {
                    linkedItems.append(LinkedItem(id: task.id, title: task.title, type: "task"))
                }
            }
        }
    }
    
    private func convertToSuggestedDestination(_ destination: String) {
        switch destination {
        case "task": convertToTask()
        case "note": convertToNote()
        case "draft": convertToDraft()
        case "project": convertToProject()
        default: break
        }
    }
    
    private func convertToTask() {
        let task = Task(
            title: editableTitle.isEmpty ? editableContent.prefix(100).description : editableTitle,
            notes: editableContent
        )
        modelContext.insert(task)
        item.convertedToType = "task"
        item.convertedToId = task.id
        item.convertedAt = Date()
        saveChanges()
        isPresented = false
    }
    
    private func convertToNote() {
        let note = Note(
            title: editableTitle.isEmpty ? editableContent.prefix(50).description : editableTitle,
            markdown: editableContent
        )
        note.author = .user
        modelContext.insert(note)
        item.convertedToType = "note"
        item.convertedToId = note.id
        item.convertedAt = Date()
        saveChanges()
        isPresented = false
    }
    
    private func convertToDraft() {
        let draft = Draft(
            title: editableTitle.isEmpty ? editableContent.prefix(50).description : editableTitle,
            caption: editableContent,
            notes: nil
        )
        modelContext.insert(draft)
        item.convertedToType = "draft"
        item.convertedToId = draft.id
        item.convertedAt = Date()
        saveChanges()
        isPresented = false
    }
    
    private func convertToProject() {
        let project = Project(
            title: editableTitle.isEmpty ? editableContent.prefix(50).description : editableTitle
        )
        modelContext.insert(project)
        item.convertedToType = "project"
        item.convertedToId = project.id
        item.convertedAt = Date()
        saveChanges()
        isPresented = false
    }
    
    private func archiveItem() {
        item.isArchived = true
        saveChanges()
        isPresented = false
    }
}

struct TypeBadge: View {
    let type: String
    
    var body: some View {
        Text(type.capitalized)
            .font(.system(.caption2, design: .rounded))
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(typeColor.opacity(0.15))
            )
            .foregroundColor(typeColor)
    }
    
    private var typeColor: Color {
        switch type {
        case "text": return .kosmicBlue
        case "file": return .kosmicPurple
        case "url": return .kosmicGreen
        case "voice": return .orange
        default: return .gray
        }
    }
}

struct AuroraSuggestionBanner: View {
    let suggestion: InboxCaptureDrawer.AuroraSuggestion
    let onAccept: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundColor(.kosmicPurple)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("This looks like a \(suggestion.destination.capitalized) idea")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if !suggestion.reasoning.isEmpty {
                    Text(suggestion.reasoning)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button(action: onAccept) {
                Text("Send to \(suggestion.destination.capitalized)")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.kosmicBlue)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.kosmicPurple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.kosmicPurple.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct LinkedContextSection: View {
    let items: [InboxCaptureDrawer.LinkedItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Linked Context")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.primary)
            
            ForEach(items, id: \.id) { item in
                HStack(spacing: 8) {
                    Image(systemName: iconForType(item.type))
                        .font(.caption)
                        .foregroundColor(.kosmicBlue)
                    
                    Text(item.title)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.kosmicBlue.opacity(0.05))
                )
            }
        }
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "project": return "folder.fill"
        case "task": return "checkmark.circle"
        default: return "doc"
        }
    }
}

struct ConvertActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let item = InboxItem(content: "Sample inbox item content", itemType: "text")
    
    return InboxCaptureDrawer(item: item, isPresented: .constant(true))
        .environmentObject(GlassColorSystem())
}

