//
//  ReflectionPanelView.swift
//  FocusOS
//
//  Phase 10: Full reflection sheet for deeper journaling
//

import SwiftUI
import SwiftData

struct ReflectionPanelView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var engine = FlowCompanionEngine.shared
    
    @State private var responseText: String = ""
    @State private var showingPastReflections: Bool = false
    @Query(sort: \ReflectionNote.timestamp, order: .reverse) private var pastReflections: [ReflectionNote]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Current prompt
                if let prompt = engine.currentPrompt {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reflection Prompt")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(prompt)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                    }
                    .padding(16)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Response field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Reflection")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $responseText)
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Sentiment preview (if we have past data)
                if !pastReflections.isEmpty {
                    sentimentPreview
                }
                
                // Actions
                HStack(spacing: 12) {
                    Button("Show Past Reflections") {
                        showingPastReflections.toggle()
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    
                    Button("Save & Close") {
                        if !responseText.isEmpty {
                            engine.handleResponse(responseText, modelContext: modelContext)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(responseText.isEmpty)
                }
            }
            .padding(24)
            .frame(maxWidth: 600)
            .navigationTitle("Reflection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPastReflections) {
                PastReflectionsView(reflections: pastReflections)
            }
        }
    }
    
    private var sentimentPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sentiment Trend")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                ForEach(pastReflections.prefix(3), id: \.id) { reflection in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(sentimentColor(reflection.sentimentScore))
                            .frame(width: 24, height: 24)
                        Text(formatDate(reflection.timestamp))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
    
    private func sentimentColor(_ score: Double) -> Color {
        if score > 0.3 {
            return .green
        } else if score < -0.3 {
            return .red
        } else {
            return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct PastReflectionsView: View {
    let reflections: [ReflectionNote]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(reflections) { reflection in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(reflection.prompt)
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text(formatDate(reflection.timestamp))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(reflection.response)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                        
                        if let summary = reflection.summary {
                            Text(summary)
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                                .italic()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Past Reflections")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

