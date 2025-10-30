//
//  MenuBarQuickCaptureView.swift
//  CloutmateMenuBar
//
//  Quick Capture View for Menu Bar
//

import SwiftUI
import SwiftData
import CloutmateShared

enum CaptureType: String, CaseIterable {
    case draft = "Draft"
    case post = "Post"
    
    var icon: String {
        switch self {
        case .draft: return "doc.text"
        case .post: return "square.and.pencil"
        }
    }
}

struct MenuBarQuickCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var content = ""
    @State private var selectedType: CaptureType = .draft
    @State private var showSuccessMessage = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Type Selector
            Picker("Type", selection: $selectedType) {
                ForEach(CaptureType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.icon)
                        Text(type.rawValue)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Content Input
            TextEditor(text: $content)
                .font(.body)
                .frame(minHeight: 200)
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(.horizontal)
            
            // Action Button
            Button(action: captureContent) {
                HStack {
                    Image(systemName: selectedType.icon)
                    Text("Capture to \(selectedType.rawValue)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(content.isEmpty)
            .padding(.horizontal)
            
            if showSuccessMessage {
                Text("✓ Captured successfully!")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .onSubmit {
            if !content.isEmpty {
                captureContent()
            }
        }
    }
    
    private func captureContent() {
        guard !content.isEmpty else { return }
        
        switch selectedType {
        case .draft:
            let draft = CloutmateShared.Draft(caption: content)
            modelContext.insert(draft)
        case .post:
            let post = CloutmateShared.Post(caption: content)
            modelContext.insert(post)
        }
        
        do {
            try modelContext.save()
            content = ""
            showSuccessMessage = true
            
            // Reset message after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showSuccessMessage = false
            }
        } catch {
            print("Failed to save: \(error)")
        }
    }
}

#Preview {
    MenuBarQuickCaptureView()
        .modelContainer(for: [CloutmateShared.Draft.self, CloutmateShared.Post.self])
}

