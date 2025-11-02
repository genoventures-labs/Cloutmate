//
//  AISelectionSheet.swift
//  Cloutmate
//
//  AI Selection Sheet for list-based AI generation
//

import SwiftUI
import CloutmateShared

struct AIGeneratedItem: Identifiable {
    let id: UUID
    let content: String
    let type: AITool
    
    init(content: String, type: AITool) {
        self.id = UUID()
        self.content = content
        self.type = type
    }
}

struct AISelectionSheet: View {
    let tool: AITool
    let items: [AIGeneratedItem]
    let platform: CloutmateShared.Platform
    let onInsert: (String) -> Void
    let onGenerate: ((String) async -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItems: Set<UUID> = []
    @State private var isGenerating = false
    @State private var errorMessage: String?
    
    var isActionableTool: Bool {
        tool.returnsActionableList
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Generated Options")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // List of items
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        ItemRow(
                            item: item,
                            isSelected: selectedItems.contains(item.id),
                            onToggle: {
                                if selectedItems.contains(item.id) {
                                    selectedItems.remove(item.id)
                                } else {
                                    selectedItems.insert(item.id)
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Insert Selected") {
                    insertSelected()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedItems.isEmpty || isGenerating)
                
                if isActionableTool && onGenerate != nil {
                    Button(isGenerating ? "Generating..." : "Generate Content") {
                        generateFromSelected()
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedItems.count != 1 || isGenerating)
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
    
    private func insertSelected() {
        guard !selectedItems.isEmpty else { return }
        
        let selectedContents = items.filter { selectedItems.contains($0.id) }
        
        // Determine separator based on tool type
        let separator: String
        if tool == .suggestHashtags {
            separator = " "
        } else {
            separator = "\n\n"
        }
        
        let text = selectedContents.map { $0.content }.joined(separator: separator)
        onInsert(text)
        dismiss()
    }
    
    private func generateFromSelected() {
        guard selectedItems.count == 1 else {
            errorMessage = "Please select only one item to generate content from"
            return
        }
        
        guard let selectedItem = items.first(where: { selectedItems.contains($0.id) }) else { return }
        
        isGenerating = true
        errorMessage = nil
        
        _Concurrency.Task {
            do {
                let prompt = "Write a complete social media post about: \(selectedItem.content). Make it engaging, platform-appropriate for \(platform.displayName), and ready to use."
                
                if let onGenerate = onGenerate {
                    await onGenerate(prompt)
                } else {
                    let result = try await GeminiService.shared.generateResponse(for: prompt, context: platform.rawValue)
                    await MainActor.run {
                        onInsert(result)
                        isGenerating = false
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate content: \(error.localizedDescription)"
                    isGenerating = false
                }
            }
        }
    }
}

struct ItemRow: View {
    let item: AIGeneratedItem
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .kosmicBlue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            Text(item.content)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.kosmicBlue.opacity(0.1) : Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.kosmicBlue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}
