//
//  QuickCaptureView.swift
//  Cloutmate
//
//  Enhanced Quick Capture with attachments and templates
//

import SwiftUI
import SwiftData
import CloutmateShared

enum CaptureType {
    case inbox, task, note, post
    
    var displayName: String {
        switch self {
        case .inbox: return "Inbox"
        case .task: return "Task"
        case .note: return "Note"
        case .post: return "Post"
        }
    }
    
    var icon: String {
        switch self {
        case .inbox: return "tray.fill"
        case .task: return "checkmark.circle"
        case .note: return "doc.text"
        case .post: return "square.and.pencil"
        }
    }
}

struct QuickCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Query private var templates: [PARATemplate]
    
    @State private var content = ""
    @State private var captureType: CaptureType = .inbox
    @State private var attachmentURL: URL?
    @State private var selectedTemplate: PARATemplate?
    @State private var showTemplatePicker = false
    @State private var tags: [String] = []
    
    var body: some View {
        VStack(spacing: 16) {
            // Type selector with icons
            Picker("Type", selection: $captureType) {
                ForEach([CaptureType.inbox, .task, .note, .post], id: \.self) { type in
                    Label(type.displayName, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            // Optional template selector
            if !relevantTemplates.isEmpty {
                Button(action: { showTemplatePicker = true }) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text(selectedTemplate?.title ?? "Select Template")
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // Content editor
            TextEditor(text: $content)
                .font(.body)
                .frame(minHeight: 150)
                .glassPanel(tier: .contentCard, cornerRadius: 8)
            
            // Attachment display
            if let url = attachmentURL {
            HStack {
                    Image(systemName: "paperclip")
                    Text(url.lastPathComponent)
                        .font(.caption)
                    Spacer()
                    Button(action: { attachmentURL = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .glassPanel(tier: .contentCard, cornerRadius: 8)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                MediaAttachmentPicker { url in
                    attachmentURL = url
                }
                
                Spacer()
                
                Button("Cancel") {
                    closeWindow()
                }
                .keyboardShortcut(.escape)
                
                Button("Capture") {
                    captureContent()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(content.isEmpty)
            }
        }
        .padding()
        .background(glassColorSystem.backgroundColor())
        .frame(width: 600, height: 400)
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet(
                templates: relevantTemplates,
                selectedTemplate: $selectedTemplate
            )
        }
        .onAppear {
            content = ""
            if let template = selectedTemplate {
                content = template.content
            }
        }
        .onChange(of: selectedTemplate) { _, newValue in
            if let template = newValue {
                content = template.content
            }
        }
    }
    
    private var relevantTemplates: [PARATemplate] {
        templates.filter { $0.type == templateTypeForCaptureType(captureType) }
    }
    
    private func templateTypeForCaptureType(_ type: CaptureType) -> TemplateType {
        switch type {
        case .inbox: return .note
        case .task: return .task
        case .note: return .note
        case .post: return .post
        }
    }
    
    private func captureContent() {
        switch captureType {
        case .inbox:
            let item = InboxItem(
                content: content,
                itemType: attachmentURL != nil ? "file" : "text",
                fileURL: attachmentURL?.path
            )
            modelContext.insert(item)
        case .task:
            let task = Task(title: content)
            modelContext.insert(task)
        case .note:
            let note = Note(title: content.prefix(50).description, markdown: content)
            note.author = .user
            modelContext.insert(note)
        case .post:
            let post = Post(caption: content)
            modelContext.insert(post)
        }
        
        // Track template usage
        if let template = selectedTemplate {
            template.usageCount += 1
        }
        
        try? modelContext.save()
        closeWindow()
    }
    
    private func closeWindow() {
        QuickCaptureWindowController.shared.close()
        content = ""
        attachmentURL = nil
        selectedTemplate = nil
    }
}

struct TemplatePickerSheet: View {
    let templates: [PARATemplate]
    @Binding var selectedTemplate: PARATemplate?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(templates) { template in
                    Button(action: {
                        selectedTemplate = template
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: template.type.icon)
                                .foregroundStyle(Color.kosmicBlue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.title)
                                    .font(.headline)
                                Text(template.templateDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if template.isBuiltIn {
                                Label("Built-in", systemImage: "checkmark.seal")
                                    .font(.caption2)
                                    .foregroundStyle(Color.kosmicBlue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Select Template")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

#Preview {
    QuickCaptureView()
        .modelContainer(for: [CloutmateShared.InboxItem.self, CloutmateShared.Task.self, CloutmateShared.Note.self, CloutmateShared.Post.self, PARATemplate.self])
}

