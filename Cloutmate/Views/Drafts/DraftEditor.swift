//
//  DraftEditor.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI

struct DraftEditor: View {
    @Bindable var draft: Draft
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Caption editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Caption")
                        .font(.headline)
                    
                    TextEditor(text: $draft.caption)
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text("\(draft.caption.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.headline)
                    
                    TagsView(tags: $draft.tags)
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    
                    TextEditor(text: Binding(
                        get: { draft.notes ?? "" },
                        set: { draft.notes = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
            // Actions
            HStack {
                Button("Save Draft") {
                    // Draft auto-saves via SwiftData
                }
                .buttonStyle(.borderedProminent)
                
                Button("Schedule Post") {
                    convertToScheduledPost()
                }
                .buttonStyle(.bordered)
            }
            }
            .padding()
        }
    }
    
    func convertToScheduledPost() {
        // Implementation to convert draft to scheduled post
        // This would open the composer with draft content
    }
}

struct TagsView: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Existing tags
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(text: tag) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }
            
            // Add tag field
            HStack {
                TextField("Add tag...", text: $newTag)
                    .onSubmit {
                        addTag()
                    }
                
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newTag.isEmpty)
            }
        }
    }
    
    private func addTag() {
        guard !newTag.isEmpty, !tags.contains(newTag) else { return }
        tags.append(newTag)
        newTag = ""
    }
}

struct TagChip: View {
    let text: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.2))
        .foregroundColor(.accentColor)
        .cornerRadius(12)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                          proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var current: CGPoint = .zero
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if current.x + size.width > maxWidth && current.x > 0 {
                    current.x = 0
                    current.y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: current, size: size))
                lineHeight = max(lineHeight, size.height)
                current.x += size.width + spacing
            }
            
            self.size = CGSize(
                width: subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0,
                height: current.y + lineHeight
            )
        }
    }
}

#Preview {
    DraftEditor(draft: Draft(caption: "Sample draft"))
}

