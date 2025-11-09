//
//  FocusDurationSheet.swift
//  Cloutmate
//
//  Sheet for selecting focus session duration
//

import SwiftUI

struct FocusDurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDuration: TimeInterval
    let itemTitle: String
    let itemType: String
    let onStart: () -> Void
    
    let durations: [(String, TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hour", 3600),
        ("2 hours", 7200)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Focus Session")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Focus on: \(itemTitle)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
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
                    dismiss()
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
        .padding()
        .frame(width: 500)
    }
}

