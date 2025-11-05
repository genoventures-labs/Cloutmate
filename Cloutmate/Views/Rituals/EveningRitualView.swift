//
//  EveningRitualView.swift
//  Cloutmate
//
//  Phase 8: Cognitive Loop Completion
//  Evening reflection flow capturing Done / Deferred / Dropped outcomes
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct EveningRitualView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ritual: FocusRitual

    @State private var doneCount: Int = 0
    @State private var deferredCount: Int = 0
    @State private var droppedCount: Int = 0
    @State private var reflectionNotes: String = ""
    @State private var aiRecap: String?
    @State private var isGeneratingRecap = false
    @State private var completionState: CompletionState = .idle
    @State private var trendData: [(Date, Double)] = []

    private enum CompletionState: Equatable {
        case idle
        case saving
        case success
        case failure(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                progressSection
                reflectionSection
                recapSection
                completeButton
            }
            .padding(24)
        }
        .background(Color(.windowBackgroundColor))
        .task {
            await loadDailySummary()
            await loadTrend()
        }
        .animation(.easeInOut(duration: 0.2), value: completionState)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Evening Reflection")
                .font(.system(size: 28, weight: .bold))
            Text("Close the loop on today’s focus and reset for tomorrow")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                Label("\(ritual.streakCount) evening streak", systemImage: "moon.stars.fill")
                    .foregroundColor(.kosmicBlue)
                    .font(.system(size: 13, weight: .semibold))
                Text("Window ends at \(ritual.windowEnd.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var progressSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Outcome Summary", systemImage: "checkmark.circle")
                    .font(.system(size: 18, weight: .semibold))

                counterRow(title: "Done", value: $doneCount, color: .kosmicGreen)
                counterRow(title: "Deferred", value: $deferredCount, color: .orange)
                counterRow(title: "Dropped", value: $droppedCount, color: .red)

                Divider().padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Focus Consistency")
                        .font(.system(size: 15, weight: .semibold))
                    if trendData.isEmpty {
                        Text("Consistency trend will appear once Aurora has a few days of reflections.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    } else {
                        ConsistencyChart(data: trendData)
                            .frame(height: 140)
                    }
                }
            }
            .padding(20)
        }
    }

    private func counterRow(title: String, value: Binding<Int>, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            Stepper(value: value, in: 0...99) {
                Text("\(value.wrappedValue)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
            }
            .frame(width: 160)
        }
    }

    private var reflectionSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Reflection", systemImage: "text.quote")
                    .font(.system(size: 18, weight: .semibold))

                TextEditor(text: $reflectionNotes)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.1))
                    )

                Text("What felt clear? What resisted momentum?")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(20)
        }
    }

    private var recapSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Aurora Recap", systemImage: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    if isGeneratingRecap {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Button("Generate Recap") {
                            _Concurrency.Task {
                                await generateRecap()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                if let aiRecap {
                    Text(aiRecap)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                } else {
                    Text("Aurora can summarize your day once you generate a recap.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }

    private var completeButton: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                completeReflection()
            } label: {
                HStack {
                    if case .saving = completionState {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Log Reflection")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)

            switch completionState {
            case .success:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.kosmicGreen)
                    Text("Reflection saved. Aurora updated your momentum tracker.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            case let .failure(message):
                HStack {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundColor(.orange)
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            default:
                EmptyView()
            }
        }
    }

    private var isSaving: Bool {
        if case .saving = completionState { return true }
        return false
    }

    private func loadDailySummary() async {
        let descriptor = FetchDescriptor<Task>()
        let tasks = (try? modelContext.fetch(descriptor)) ?? []
        let calendar = Calendar.current

        let completedToday = tasks.filter { task in
            guard let completed = task.completedAt else { return false }
            return calendar.isDateInToday(completed)
        }

        await MainActor.run {
            doneCount = completedToday.count
            deferredCount = max(0, tasks.filter { $0.status == .inProgress }.count - doneCount)
            droppedCount = tasks.filter { $0.status == .cancelled }.count
        }
    }

    private func loadTrend() async {
        let data = RitualAnalytics.shared.completionTrend(days: 14, modelContext: modelContext)
        await MainActor.run {
            trendData = data
        }
    }

    private func generateRecap() async {
        isGeneratingRecap = true
        let summary = "Done: \(doneCount), Deferred: \(deferredCount), Dropped: \(droppedCount). Notes: \(reflectionNotes)"
        let prompt = "Summarize a creator's day in one sentence based on this reflection: \(summary). Emphasize focus momentum."

        do {
            let response = try await GeminiService.shared.generateResponse(for: prompt)
            await MainActor.run {
                aiRecap = response
                isGeneratingRecap = false
            }
        } catch {
            await MainActor.run {
                aiRecap = "Aurora couldn't generate a recap right now, but your reflection is saved."
                isGeneratingRecap = false
            }
        }
    }

    private func completeReflection() {
        guard !isSaving else { return }
        completionState = .saving

        _Concurrency.Task { @MainActor in
            let outcome: RitualCompletionOutcome = doneCount > 0 ? .completed : .deferred
            let taskCounts: [String: Int] = [
                "done": doneCount,
                "deferred": deferredCount,
                "dropped": droppedCount
            ]

            let highlights = [
                "Reflection captured with \(doneCount) done, \(deferredCount) deferred, \(droppedCount) dropped"
            ]

            let input = RitualCompletionInput(
                outcome: outcome,
                completedAt: Date(),
                duration: 0,
                userNotes: reflectionNotes.isEmpty ? nil : reflectionNotes,
                aiRecap: aiRecap,
                highlights: highlights,
                focusItemIds: [],
                taskStatusCounts: taskCounts,
                cpsBoostApplied: false,
                momentumDelta: Double(doneCount) * 0.05 - Double(droppedCount) * 0.03,
                metadata: ["source": "evening-ritual"]
            )

            _ = FocusRitualManager.shared.completeRitual(ritual, input: input, modelContext: modelContext)
            completionState = .success
        }
    }
}

// MARK: - Consistency Chart

private struct ConsistencyChart: View {
    let data: [(Date, Double)]

    var body: some View {
        Chart {
            ForEach(data, id: \.0) { point in
                LineMark(
                    x: .value("Date", point.0, unit: .day),
                    y: .value("Completion", point.1)
                )
                .interpolationMethod(.catmullRom)
                AreaMark(
                    x: .value("Date", point.0, unit: .day),
                    y: .value("Completion", point.1)
                )
                .foregroundStyle(LinearGradient(
                    colors: [KosmicPalette.violet.opacity(0.35), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                PointMark(
                    x: .value("Date", point.0, unit: .day),
                    y: .value("Completion", point.1)
                )
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, data.count / 5))) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel(date.formatted(.dateTime.month(.defaultDigits).day()))
                }
            }
        }
    }
}

#Preview {
    do {
        let container = try ModelContainer(
            for: FocusRitual.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ritual = FocusRitual(
            type: .evening,
            scheduledFor: Date(),
            windowEnd: Date().addingTimeInterval(5400)
        )
        container.mainContext.insert(ritual)
        return EveningRitualView(ritual: ritual)
            .modelContainer(container)
            .frame(width: 460, height: 720)
    } catch {
        return Text("Preview unavailable")
    }
}


