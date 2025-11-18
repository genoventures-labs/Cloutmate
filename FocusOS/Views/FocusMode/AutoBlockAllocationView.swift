//
//  AutoBlockAllocationView.swift
//  FocusOS
//
//  Auto-Block Allocation UI - Shows top priorities with suggested time slots
//

import SwiftUI
import SwiftData
import FocusOSShared

struct AutoBlockAllocationView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var topPriorities: [PriorityItem] = []
    @State private var suggestedSlots: [UUID: SuggestedSlot] = [:]
    @State private var isLoading = false
    @State private var showingManualOverride = false
    @State private var selectedPriority: PriorityItem?
    
    struct SuggestedSlot: Identifiable {
        let id: UUID
        let startTime: Date
        let endTime: Date
        let energyAlignment: Double
        let calendarAvailable: Bool
        let reasoning: String
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                if isLoading {
                    ProgressView("Analyzing priorities and calendar...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if topPriorities.isEmpty {
                    emptyState
                } else {
                    prioritiesList
                }
            }
            .padding(24)
        }
        .background(Color(.windowBackgroundColor))
        .task {
            await loadPriorities()
        }
        .sheet(isPresented: $showingManualOverride) {
            if let priority = selectedPriority {
                ManualOverrideSheet(priority: priority)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-Block Allocation")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("AI-suggested time slots for your top priorities")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: refreshPriorities) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }
    
    private var prioritiesList: some View {
        VStack(spacing: 16) {
            ForEach(Array(topPriorities.prefix(3).enumerated()), id: \.element.id) { index, priority in
                PriorityCard(
                    priority: priority,
                    rank: index + 1,
                    suggestedSlot: suggestedSlots[priority.objectId],
                    onSchedule: {
                        schedulePriority(priority)
                    },
                    onManualOverride: {
                        selectedPriority = priority
                        showingManualOverride = true
                    }
                )
            }
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView(
            "No Priorities",
            systemImage: "calendar.badge.clock",
            description: Text("Create tasks or projects to see AI-suggested time blocks here.")
        )
        .frame(maxHeight: .infinity)
    }
    
    private func refreshPriorities() {
        _Concurrency.Task {
            await loadPriorities()
        }
    }
    
    private func loadPriorities() async {
        isLoading = true
        defer { isLoading = false }
        
        // Get top 3 priorities
        let priorities = PriorityEngine.shared.getTopObjects(limit: 3, modelContext: modelContext)
        
        await MainActor.run {
            topPriorities = priorities
        }
        
        // Generate suggested slots for each priority
        var slots: [UUID: SuggestedSlot] = [:]
        
        for priority in priorities {
            if let slot = await generateSuggestedSlot(for: priority) {
                slots[priority.objectId] = slot
            }
        }
        
        await MainActor.run {
            suggestedSlots = slots
        }
    }
    
    private func generateSuggestedSlot(for priority: PriorityItem) async -> SuggestedSlot? {
        // Determine energy requirement (simplified - would be stored on task/project)
        let energyRequirement = inferEnergyRequirement(for: priority)
        
        // Get optimal time window from chronotype mapper
        let optimalWindow = ChronotypeMapper.shared.getOptimalWindow(
            for: energyRequirement,
            modelContext: modelContext
        )
        
        // Get available slots from calendar
        let planningWindow = DateInterval(
            start: Date(),
            end: Date().addingTimeInterval(48 * 3600) // Next 48 hours
        )
        
        guard let availableSlots = try? await CalendarAvailabilityService.shared.availableTimeSlots(
            modelContext: modelContext,
            in: planningWindow,
            slotMinutes: 60
        ) else {
            return nil
        }
        
        // Filter slots by optimal window if available
        let filteredSlots = availableSlots.filter { slot in
            guard let optimalWindow = optimalWindow else { return true }
            let hour = Calendar.current.component(.hour, from: slot.start)
            return hour >= optimalWindow.startHour && hour <= optimalWindow.endHour
        }
        
        guard let bestSlot = filteredSlots.first else {
            return nil
        }
        
        // Calculate energy alignment score
        let energyAlignment = calculateEnergyAlignment(
            slot: bestSlot,
            energyRequirement: energyRequirement,
            optimalWindow: optimalWindow
        )
        
        // Build reasoning
        let reasoning = buildReasoning(
            priority: priority,
            slot: bestSlot,
            energyRequirement: energyRequirement,
            energyAlignment: energyAlignment
        )
        
        return SuggestedSlot(
            id: UUID(),
            startTime: bestSlot.start,
            endTime: bestSlot.end,
            energyAlignment: energyAlignment,
            calendarAvailable: true,
            reasoning: reasoning
        )
    }
    
    private func inferEnergyRequirement(for priority: PriorityItem) -> EnergyRequirement {
        // Simplified inference - in production would check task/project properties
        if priority.objectType == "task" {
            return .deep // Default to deep work for tasks
        } else if priority.objectType == "project" {
            return .creative // Default to creative for projects
        }
        return .shallow
    }
    
    private func calculateEnergyAlignment(
        slot: TimeSlot,
        energyRequirement: EnergyRequirement,
        optimalWindow: (startHour: Int, endHour: Int)?
    ) -> Double {
        guard let optimalWindow = optimalWindow else { return 0.5 }
        
        let slotHour = Calendar.current.component(.hour, from: slot.start)
        
        if slotHour >= optimalWindow.startHour && slotHour <= optimalWindow.endHour {
            return 0.9 // High alignment
        } else {
            let distance = min(
                abs(slotHour - optimalWindow.startHour),
                abs(slotHour - optimalWindow.endHour)
            )
            return max(0.1, 1.0 - Double(distance) / 8.0) // Decay with distance
        }
    }
    
    private func buildReasoning(
        priority: PriorityItem,
        slot: TimeSlot,
        energyRequirement: EnergyRequirement,
        energyAlignment: Double
    ) -> String {
        var reasoning = "Suggested for \(priority.title) based on:\n"
        reasoning += "• Priority score: \(String(format: "%.2f", priority.score))\n"
        reasoning += "• Energy type: \(energyRequirement.displayName)\n"
        reasoning += "• Alignment: \(Int(energyAlignment * 100))%\n"
        reasoning += "• Calendar availability: Available"
        return reasoning
    }
    
    private func schedulePriority(_ priority: PriorityItem) {
        guard let slot = suggestedSlots[priority.objectId] else { return }
        
        // Create a focus session for this priority
        // In production, this would integrate with FocusSessionService
        print("Scheduling \(priority.title) for \(slot.startTime.formatted(date: .complete, time: .shortened))")
        
        // Show confirmation
        // In production, would show a confirmation dialog and create the session
    }
}

// MARK: - Priority Card

struct PriorityCard: View {
    let priority: PriorityItem
    let rank: Int
    let suggestedSlot: AutoBlockAllocationView.SuggestedSlot?
    let onSchedule: () -> Void
    let onManualOverride: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(Color.kosmicBlue.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Text("\(rank)")
                        .font(.headline.bold())
                        .foregroundColor(.kosmicBlue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(priority.title)
                        .font(.headline)
                    
                    Text(priority.objectType.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Priority score
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.0f%%", priority.score * 100))
                        .font(.headline.bold())
                        .foregroundColor(scoreColor(priority.score))
                    
                    Text("Priority")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if let slot = suggestedSlot {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggested Time Slot")
                        .font(.subheadline.bold())
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(slot.startTime.formatted(date: .omitted, time: .shortened))
                                .font(.headline)
                            
                            Text(slot.startTime.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(slot.endTime.formatted(date: .omitted, time: .shortened))
                                .font(.headline)
                            
                            Text("\(Int(slot.endTime.timeIntervalSince(slot.startTime) / 60)) min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Energy alignment indicator
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(alignmentColor(slot.energyAlignment))
                                Text("\(Int(slot.energyAlignment * 100))%")
                                    .font(.subheadline.bold())
                                    .foregroundColor(alignmentColor(slot.energyAlignment))
                            }
                            
                            Text("Alignment")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Reasoning
                    Text(slot.reasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                    
                    // Actions
                    HStack(spacing: 12) {
                        Button(action: onSchedule) {
                            Label("Schedule", systemImage: "calendar.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: onManualOverride) {
                            Label("Manual Override", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Text("No available time slots found")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score > 0.7 {
            return .kosmicGreen
        } else if score > 0.4 {
            return .kosmicBlue
        } else {
            return .orange
        }
    }
    
    private func alignmentColor(_ alignment: Double) -> Color {
        if alignment > 0.7 {
            return .kosmicGreen
        } else if alignment > 0.4 {
            return .kosmicBlue
        } else {
            return .orange
        }
    }
}

// MARK: - Manual Override Sheet

struct ManualOverrideSheet: View {
    let priority: PriorityItem
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var selectedDuration = 60
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Priority") {
                    Text(priority.title)
                        .font(.headline)
                }
                
                Section("Schedule Manually") {
                    DatePicker("Start Time", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    
                    Picker("Duration", selection: $selectedDuration) {
                        Text("30 min").tag(30)
                        Text("60 min").tag(60)
                        Text("90 min").tag(90)
                        Text("120 min").tag(120)
                    }
                }
            }
            .navigationTitle("Manual Override")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        // Schedule with manual override
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

#Preview {
    AutoBlockAllocationView()
        .modelContainer(for: [PriorityScore.self], inMemory: true)
}

