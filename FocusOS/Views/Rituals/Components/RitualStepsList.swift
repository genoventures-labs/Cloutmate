//
//  RitualStepsList.swift
//  FocusOS
//
//  Rituals V2: Sequential steps list with completion toggles
//

import SwiftUI
import SwiftData
import FocusOSShared
#if canImport(UIKit)
import UIKit
#endif

struct RitualStepsList: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    let ritualType: FocusRitualType
    @Binding var steps: [RitualStep]
    let onStepComplete: (RitualStep) -> Void
    let onStepSkip: (RitualStep) -> Void
    let onTaskPreviewTap: () -> Void
    
    @State private var topPriorityItems: [PriorityItem] = []
    @State private var isLoadingTasks = false
    @State private var expandedStepId: UUID?
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                RitualStepRow(
                    step: step,
                    index: index,
                    totalSteps: steps.count,
                    isExpanded: expandedStepId == step.id,
                    topPriorityItems: step.type == .taskPreview ? topPriorityItems : [],
                    isLoadingTasks: isLoadingTasks && step.type == .taskPreview,
                    onToggle: {
                        toggleStep(step)
                    },
                    onSkip: {
                        skipStep(step)
                    },
                    onExpand: {
                        withAnimation(.spring(duration: 0.25)) {
                            expandedStepId = expandedStepId == step.id ? nil : step.id
                        }
                    },
                    onTaskPreviewTap: onTaskPreviewTap
                )
            }
        }
        .task {
            await loadTopPriorities()
        }
    }
    
    private func toggleStep(_ step: RitualStep) {
        if let index = steps.firstIndex(where: { $0.id == step.id }) {
            steps[index].isCompleted.toggle()
            
            // Haptic feedback
            #if canImport(UIKit)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
            
            onStepComplete(steps[index])
        }
    }
    
    private func skipStep(_ step: RitualStep) {
        if let index = steps.firstIndex(where: { $0.id == step.id }) {
            onStepSkip(steps[index])
        }
    }
    
    @MainActor
    private func loadTopPriorities() async {
        isLoadingTasks = true
        let items = PriorityEngine.shared.getTopObjects(limit: 3, modelContext: modelContext)
        topPriorityItems = items
        isLoadingTasks = false
    }
}

private struct RitualStepRow: View {
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    let step: RitualStep
    let index: Int
    let totalSteps: Int
    let isExpanded: Bool
    let topPriorityItems: [PriorityItem]
    let isLoadingTasks: Bool
    let onToggle: () -> Void
    let onSkip: () -> Void
    let onExpand: () -> Void
    let onTaskPreviewTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Step number indicator
                    ZStack {
                        Circle()
                            .fill(step.isCompleted ? Color.kosmicGreen : Color.secondary.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        if step.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(glassColorSystem.textPrimary())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: step.type.icon)
                                .font(.system(size: 14))
                                .foregroundColor(step.isCompleted ? .kosmicGreen : glassColorSystem.textSecondary())
                            
                            Text(step.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(glassColorSystem.textPrimary())
                                .strikethrough(step.isCompleted)
                        }
                        
                        Text(step.description)
                            .font(.system(size: 13))
                            .foregroundColor(glassColorSystem.textSecondary())
                            .lineLimit(isExpanded ? nil : 2)
                    }
                    
                    Spacer()
                    
                    // Completion toggle
                    Button {
                        onToggle()
                    } label: {
                        Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundColor(step.isCompleted ? .kosmicGreen : glassColorSystem.textSecondary())
                    }
                    .buttonStyle(.plain)
                }
                
                // Expanded content
                if isExpanded {
                    expandedContent
                }
                
                // Task preview (if this is the taskPreview step)
                if step.type == .taskPreview && !topPriorityItems.isEmpty {
                    taskPreviewContent
                }
            }
            .padding(16)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        // Swipe left to skip
                        onSkip()
                    }
                }
        )
        .onLongPressGesture {
            onExpand()
        }
    }
    
    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            if let duration = step.duration {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                        .foregroundColor(.kosmicBlue)
                    Text("Suggested duration: \(Int(duration)) seconds")
                        .font(.system(size: 12))
                        .foregroundColor(glassColorSystem.textSecondary())
                }
            }
            
            Button {
                onSkip()
            } label: {
                HStack {
                    Image(systemName: "forward.fill")
                    Text("Skip this step")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var taskPreviewContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            Text("Top priorities")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(glassColorSystem.textPrimary())
            
            if isLoadingTasks {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(topPriorityItems.prefix(3), id: \.objectId) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.kosmicBlue.opacity(0.2))
                            .frame(width: 6, height: 6)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(glassColorSystem.textPrimary())
                            
                            if !item.detail.isEmpty {
                                Text(item.detail)
                                    .font(.system(size: 11))
                                    .foregroundColor(glassColorSystem.textSecondary())
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                Button {
                    onTaskPreviewTap()
                } label: {
                    Text("View in Focus Gravity")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.kosmicBlue)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }
}

#Preview {
    RitualStepsList(
        ritualType: .morning,
        steps: .constant(RitualStepConfiguration.steps(for: .morning)),
        onStepComplete: { _ in },
        onStepSkip: { _ in },
        onTaskPreviewTap: {}
    )
    .padding()
    .environmentObject(GlassColorSystem())
}

