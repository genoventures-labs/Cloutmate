//
//  ArtifactEditorToolbar.swift
//  FocusOS
//
//  Artifacts V2 - AI-powered toolbar for artifact refinement
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import FocusOSShared

struct ArtifactEditorToolbar: View {
    let artifact: Artifact
    
    @Environment(\.modelContext) private var modelContext
    @State private var showExportMenu = false
    @State private var isGenerating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Generate Summary
            Button(action: {
                generateSummary()
            }) {
                Label("Generate Summary", systemImage: "text.alignleft")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .disabled(isGenerating)
            
            // Refine Tone
            Button(action: {
                refineTone()
            }) {
                Label("Refine Tone", systemImage: "paintbrush")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .disabled(isGenerating)
            
            Spacer()
            
            // Export Menu
            Menu {
                Button(action: {
                    exportToPDF()
                }) {
                    Label("Export to PDF", systemImage: "doc.fill")
                }
                
                Button(action: {
                    exportToMarkdown()
                }) {
                    Label("Export to Markdown", systemImage: "doc.text")
                }
                
                Button(action: {
                    exportToPlaintext()
                }) {
                    Label("Export to Plaintext", systemImage: "doc.plaintext")
                }
                
                Divider()
                
                Button(action: {
                    exportToDrafts()
                }) {
                    Label("Copy to Drafts", systemImage: "doc.on.clipboard")
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            
            // Forecast
            Button(action: {
                showForecast()
            }) {
                Label("Forecast", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func generateSummary() {
        isGenerating = true
        // TODO: Implement AI summary generation
        isGenerating = false
    }
    
    private func refineTone() {
        isGenerating = true
        // TODO: Implement tone refinement
        isGenerating = false
    }
    
    private func exportToPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(artifact.title).pdf"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? ArtifactExportService.shared.exportToPDF(artifact, url: url)
        }
    }
    
    private func exportToMarkdown() {
        let markdown = ArtifactExportService.shared.exportToMarkdown(artifact)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(artifact.title).md"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? markdown.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func exportToPlaintext() {
        let text = ArtifactExportService.shared.exportToPlaintext(artifact)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(artifact.title).txt"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func exportToDrafts() {
        try? ArtifactExportService.shared.exportToDrafts(artifact, modelContext: modelContext)
    }
    
    private func showForecast() {
        // TODO: Show forecast badge/meter
    }
}

#Preview {
    ArtifactEditorToolbar(artifact: Artifact(title: "Test", content: "Content"))
        .padding()
}

