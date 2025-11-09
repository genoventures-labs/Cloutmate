//
//  ReflectionBubbleView.swift
//  Cloutmate
//
//  Phase 10: Floating chat bubble - minimal footprint
//

import SwiftUI
import AppKit

struct ReflectionBubbleView: View {
    @ObservedObject var engine = FlowCompanionEngine.shared
    @Environment(\.modelContext) private var modelContext
    
    @State private var responseText: String = ""
    @State private var isExpanded: Bool = false
    @State private var mouseMonitor: Any?
    
    var body: some View {
        Group {
            if engine.isBubbleVisible {
                VStack(spacing: 0) {
                    if isExpanded {
                        expandedView
                    } else {
                        collapsedView
                    }
                }
                .transition(.opacity.combined(with: .scale))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
                .zIndex(1000) // Ensure it's on top
                .onAppear {
                    setupMouseTracking()
                }
                .onDisappear {
                    removeMouseTracking()
                }
            }
        }
    }
    
    private func setupMouseTracking() {
        // Reset dismiss timer when mouse moves
        // The timer is set to 60 seconds, so it will stay visible for at least 1 minute
        // after the last mouse movement
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak engine] event in
            if let engine = engine, engine.isBubbleVisible {
                // Reset the dismiss timer on mouse movement
                // This ensures the bubble stays visible for at least 1 minute after mouse stops moving
                Task { @MainActor in
                    engine.resetDismissTimer()
                }
            }
            return event // Pass through the event
        }
    }
    
    private func removeMouseTracking() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
    
    private var collapsedView: some View {
        Button(action: {
            withAnimation {
                isExpanded = true
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                Text("Reflect")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Prompt
            if let prompt = engine.currentPrompt {
                Text(prompt)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            // Response field
            TextField("Your reflection...", text: $responseText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
                .lineLimit(3...6)
            
            // Actions
            HStack(spacing: 8) {
                Button("Cancel") {
                    engine.collapseBubble()
                    responseText = ""
                    isExpanded = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                
                Spacer()
                
                Button("More") {
                    engine.expandToPanel()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                
                Button("Save") {
                    if !responseText.isEmpty {
                        engine.handleResponse(responseText, modelContext: modelContext)
                        responseText = ""
                        isExpanded = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 12))
                .disabled(responseText.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
        )
    }
}

