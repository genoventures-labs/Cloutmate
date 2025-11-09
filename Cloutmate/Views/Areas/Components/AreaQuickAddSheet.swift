//
//  AreaQuickAddSheet.swift
//  Cloutmate
//
//  Areas V2 - Quick add sheet with icon and color selection
//

import SwiftUI
import SwiftData
import CloutmateShared

struct AreaQuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedIcon: String = "rectangle.stack.fill"
    @State private var selectedColorAccent: String = "kosmicBlue"
    @State private var addInitialReviewNote = false
    @State private var isSaving = false
    
    let commonIcons = [
        "rectangle.stack.fill",
        "folder.fill",
        "heart.fill",
        "brain.head.profile",
        "flame.fill",
        "leaf.fill",
        "book.fill",
        "pencil.and.outline",
        "paintbrush.fill",
        "figure.run",
        "house.fill",
        "briefcase.fill",
        "graduationcap.fill",
        "gamecontroller.fill",
        "music.note"
    ]
    
    let colorAccents = [
        ("kosmicBlue", Color.kosmicBlue),
        ("kosmicPurple", Color.kosmicPurple),
        ("kosmicGreen", Color.kosmicGreen)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Title Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title *")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Area Title", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Description Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $description)
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Category Icon Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category Icon")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 50), spacing: 12)
                        ], spacing: 12) {
                            ForEach(commonIcons, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                        .frame(width: 50, height: 50)
                                        .background(
                                            selectedIcon == icon ?
                                            Color.kosmicBlue :
                                            Color.secondary.opacity(0.1)
                                        )
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Color Accent Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color Accent")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(colorAccents, id: \.0) { accent in
                                Button(action: {
                                    selectedColorAccent = accent.0
                                }) {
                                    Circle()
                                        .fill(accent.1)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    selectedColorAccent == accent.0 ?
                                                    Color.primary :
                                                    Color.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Optional Toggle
                    Toggle("Add initial review note", isOn: $addInitialReviewNote)
                        .toggleStyle(.switch)
                }
                .padding(20)
            }
            .navigationTitle("New Area")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createArea()
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
        .frame(minWidth: 500, idealWidth: 500, maxWidth: 600)
        .frame(minHeight: 400, idealHeight: 600, maxHeight: 800)
    }
    
    private func createArea() {
        guard !title.isEmpty else { return }
        
        isSaving = true
        
        // Create area
        let area = Area(
            title: title,
            notes: description.isEmpty ? nil : description,
            tags: [],
            status: .active,
            categoryIcon: selectedIcon,
            colorAccent: selectedColorAccent
        )
        
        modelContext.insert(area)
        
        // Create initial review note if requested
        if addInitialReviewNote {
            let note = Note(
                title: "\(title) - Initial Review",
                markdown: "Initial review note for \(title).",
                tags: [],
                areaId: area.id
            )
            modelContext.insert(note)
        }
        
        do {
            try modelContext.save()
            
            // Shimmer animation and haptic feedback
            if !reduceMotion {
                // Trigger shimmer effect (would need shimmer modifier implementation)
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            }
            
            // Show toast notification
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowToast"),
                object: "Area created."
            )
            
            dismiss()
        } catch {
            print("Failed to create area: \(error)")
            isSaving = false
        }
    }
}

#Preview {
    AreaQuickAddSheet()
        .modelContainer(for: [Area.self, Note.self])
}

