//
//  FocusDurationSheet.swift
//  Cloutmate
//
//  Inline overlay for selecting focus session duration
//

import SwiftUI

struct FocusDurationSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedDuration: TimeInterval
    let itemTitle: String
    let itemType: String
    let onStart: () -> Void
    
    private let overlayBackground = Color.black.opacity(0.35)
    
    var body: some View {
        ZStack {
            overlayBackground
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresented = false
                    }
                }
            
            FocusDurationPanel(
                isPresented: $isPresented,
                selectedDuration: $selectedDuration,
                itemTitle: itemTitle,
                itemType: itemType,
                onStart: onStart
            )
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 12)
            .frame(maxWidth: 520)
        }
        .transition(.opacity.combined(with: .scale))
        .zIndex(1000)
        .accessibilityAddTraits(.isModal)
    }
}

private struct FocusDurationPanel: View {
    @Binding var isPresented: Bool
    @Binding var selectedDuration: TimeInterval
    let itemTitle: String
    let itemType: String
    let onStart: () -> Void
    
    private let durations: [(String, TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hour", 3600),
        ("2 hours", 7200)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Focus Session")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Focus on: \(itemTitle)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("How long do you want to focus?")
                    .font(.headline)
                
                Picker("Duration", selection: $selectedDuration) {
                    ForEach(durations, id: \.1) { label, value in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            HStack {
                Button("Cancel") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresented = false
                    }
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Start Focus Session") {
                    onStart()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }
}

