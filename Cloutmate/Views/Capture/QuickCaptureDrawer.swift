//
//  QuickCaptureDrawer.swift
//  Cloutmate
//
//  Drawer presentation for quick capture - V2 Design
//

import SwiftUI
import SwiftData
import CloutmateShared

struct QuickCaptureDrawer: View {
    @Binding var isPresented: Bool
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var templates: [PARATemplate]
    
    @State private var content = ""
    @State private var captureType: CaptureType = .inbox
    @State private var attachmentURL: URL?
    @State private var selectedTemplate: PARATemplate?
    @State private var showTemplatePicker = false
    @State private var tags: [String] = []
    
    private var accentGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    var body: some View {
        V2DrawerScaffold(
            accentGradient: accentGradient,
            showsSidebar: false,
            header: { headerContent },
            content: { captureContent },
            sidebar: { EmptyView() }
        )
        .frame(minWidth: 700, minHeight: 560)
        .frame(idealWidth: 860, idealHeight: 640)
        .background(glassColorSystem.backgroundColor())
        .onEscape {
            closeDrawer()
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
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet(
                templates: relevantTemplates,
                selectedTemplate: $selectedTemplate
            )
        }
    }
    
    private var headerContent: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Capture")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Capture thoughts, tasks, or notes instantly")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                GlassButton(
                    "Capture",
                    icon: "checkmark",
                    style: .pill,
                    role: .primary
                ) {
                    performCapture()
                }
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
                
                GlassButton(
                    nil,
                    icon: "xmark",
                    style: .iconOnly,
                    role: .surface,
                    tintColor: glassColorSystem.backgroundElevated()
                ) {
                    closeDrawer()
                }
                .accessibilityLabel("Close")
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
    
    @ViewBuilder
    private var captureContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            typeSelectorSection
            if !relevantTemplates.isEmpty {
                templateSection
            }
            contentEditorSection
            if attachmentURL != nil {
                attachmentSection
            }
            actionButtonsSection
        }
    }
    
    private var typeSelectorSection: some View {
        DrawerSection(title: "Capture Type", icon: "tray.fill") {
            HStack(spacing: 12) {
                ForEach([CaptureType.inbox, .task, .note], id: \.self) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            captureType = type
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(type.displayName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(typeAccentColor(for: type).opacity(captureType == type ? 0.26 : 0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(typeAccentColor(for: type).opacity(captureType == type ? 0.55 : 0.24), lineWidth: captureType == type ? 1.4 : 1)
                        )
                        .foregroundStyle(captureType == type ? Color.white : glassColorSystem.textSecondary())
                        .shadow(color: typeAccentColor(for: type).opacity(captureType == type ? 0.20 : 0.0), radius: captureType == type ? 12 : 0, y: captureType == type ? 6 : 0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func typeAccentColor(for type: CaptureType) -> Color {
        switch type {
        case .inbox: return .kosmicBlue
        case .task: return .kosmicGreen
        case .note: return .kosmicPurple
        case .post: return .kosmicBlue
        }
    }
    
    private var templateSection: some View {
        DrawerSection(title: "Template", icon: "doc.on.clipboard") {
            Button {
                showTemplatePicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    Text(selectedTemplate?.title ?? "Select Template")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(glassColorSystem.textSecondary())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(glassColorSystem.backgroundElevated().opacity(0.28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(glassColorSystem.borderColor().opacity(0.35), lineWidth: 0.9)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var contentEditorSection: some View {
        DrawerSection(title: "Content", icon: "doc.richtext") {
            TextEditor(text: $content)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(glassColorSystem.textPrimary())
                .frame(minHeight: 200)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(glassColorSystem.backgroundElevated().opacity(0.32))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(glassColorSystem.borderColor().opacity(0.35), lineWidth: 0.9)
                        )
                )
                .scrollContentBackground(.hidden)
        }
    }
    
    @ViewBuilder
    private var attachmentSection: some View {
        if let url = attachmentURL {
            DrawerSection(title: "Attachment", icon: "paperclip") {
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(glassColorSystem.textSecondary())
                    
                    Text(url.lastPathComponent)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .lineLimit(1)
                    
                    Spacer()
                    
                    GlassButton(
                        nil,
                        icon: "xmark",
                        style: .iconOnly,
                        role: .surface,
                        tintColor: glassColorSystem.backgroundElevated()
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            attachmentURL = nil
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(glassColorSystem.backgroundElevated().opacity(0.28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(glassColorSystem.borderColor().opacity(0.35), lineWidth: 0.9)
                        )
                )
            }
        }
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            MediaAttachmentPicker { url in
                withAnimation(.easeInOut(duration: 0.15)) {
                    attachmentURL = url
                }
            }
            
            Spacer()
            
            GlassButton(
                "Cancel",
                icon: nil,
                style: .pill,
                role: .surface,
                tintColor: glassColorSystem.backgroundElevated()
            ) {
                closeDrawer()
            }
            .keyboardShortcut(.escape, modifiers: [])
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
    
    private func performCapture() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        switch captureType {
        case .inbox:
            let item = InboxItem(
                content: trimmedContent,
                itemType: attachmentURL != nil ? "file" : "text",
                fileURL: attachmentURL?.path
            )
            modelContext.insert(item)
        case .task:
            let task = Task(title: trimmedContent)
            modelContext.insert(task)
        case .note:
            let note = Note(title: String(trimmedContent.prefix(50)), markdown: trimmedContent)
            note.author = .user
            modelContext.insert(note)
        case .post:
            let post = Post(caption: trimmedContent)
            modelContext.insert(post)
        }
        
        // Track template usage
        if let template = selectedTemplate {
            template.usageCount += 1
        }
        
        try? modelContext.save()
        closeDrawer()
    }
    
    private func closeDrawer() {
        withAnimation(reduceMotion ? nil : GlassMotion.Easing.modalOpen) {
            content = ""
            attachmentURL = nil
            selectedTemplate = nil
            tags = []
            isPresented = false
        }
    }
}
