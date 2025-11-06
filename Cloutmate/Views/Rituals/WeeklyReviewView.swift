//
//  WeeklyReviewView.swift
//  Cloutmate
//
//  Phase 8: Cognitive Loop Completion
//  Guided five-step weekly review ritual
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct WeeklyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var review: WeeklyReview

    @State private var step: ReviewStep = .clearInbox
    @State private var inboxItems: [InboxItem] = []
    @State private var topCPSItems: [PriorityItem] = []
    @State private var insightsDraft: String = ""
    @State private var recommendationsDraft: String = ""
    @State private var nextFocusInputs: [String] = ["", "", ""]
    @State private var isGeneratingInsights = false
    @State private var completionState: CompletionState = .idle
    @State private var focusGravityTrend: [(Date, Double)] = []

    private enum CompletionState: Equatable {
        case idle
        case saving
        case success
        case failure(String)
    }

    enum ReviewStep: Int, CaseIterable, Identifiable {
        case clearInbox
        case reviewCPS
        case distillInsights
        case recommendations
        case nextFocus

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .clearInbox: return "1. Clear Inbox"
            case .reviewCPS: return "2. CPS Shifts"
            case .distillInsights: return "3. Distill Insights"
            case .recommendations: return "4. Recommendations"
            case .nextFocus: return "5. Next Week"
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            header
            stepSelector
            stepContent
            metricsPanel
            finalizeSection
        }
        .padding(24)
        .background(Color(.windowBackgroundColor))
        .task {
            await loadData()
        }
        .animation(.easeInOut(duration: 0.2), value: step)
        .animation(.easeInOut(duration: 0.2), value: completionState)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Review")
                .font(.system(size: 32, weight: .bold))
            Text("Reveal your patterns and set the next focus orbit")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stepSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ReviewStep.allCases) { current in
                    Button {
                        step = current
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(current.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(step == current ? .white : .primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(step == current ? KosmicPalette.violet : Color.secondary.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .clearInbox:
            inboxStep
        case .reviewCPS:
            cpsStep
        case .distillInsights:
            insightsStep
        case .recommendations:
            recommendationsStep
        case .nextFocus:
            nextFocusStep
        }
    }

    private var inboxStep: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Clear Inbox of Stale Items", systemImage: "tray.fill")
                    .font(.system(size: 18, weight: .semibold))

                if inboxItems.isEmpty {
                    Text("Your inbox is clear. Capture velocity is healthy.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                } else {
                    Text("Review these inbox items and mark the ones you resolved or archived.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    ForEach(inboxItems, id: \.id) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(KosmicPalette.cyan)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.content)
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Captured \(item.createdAt.formatted(.dateTime.month().day()))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(12)
                    }

                    Button("Mark Inbox Cleared") {
                        review.inboxItemsCleared = inboxItems.count
                        inboxItems.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(22)
        }
    }

    private var cpsStep: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Review Top CPS Shifts", systemImage: "chart.bar.doc.horizontal")
                    .font(.system(size: 18, weight: .semibold))

                if topCPSItems.isEmpty {
                    Text("Aurora is still calibrating your CPS scores. Keep capturing and completing work.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(topCPSItems.prefix(5), id: \.objectId) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.system(size: 15, weight: .semibold))
                            Text(item.detail)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(String(format: "Score: %.2f", item.score))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(KosmicPalette.violet)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(22)
        }
    }

    private var insightsStep: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Distill Insights", systemImage: "brain.head.profile")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    if isGeneratingInsights {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Button("AI Summary") {
                            _Concurrency.Task {
                                await generateInsightsSummary()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                TextEditor(text: $insightsDraft)
                    .frame(minHeight: 180)
                    .padding(12)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.1))
                    )

                Text("Capture the patterns Aurora surfaced this week: what pulled focus, what accelerated momentum, and what you learned.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(22)
        }
    }

    private var recommendationsStep: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Recommendations", systemImage: "paperplane")
                    .font(.system(size: 18, weight: .semibold))

                TextEditor(text: $recommendationsDraft)
                    .frame(minHeight: 140)
                    .padding(12)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)

                Text("Consider who should know about these insights. Would you share them with your team, community, or future self?")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(22)
        }
    }

    private var nextFocusStep: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Next Week’s Focuses", systemImage: "target")
                    .font(.system(size: 18, weight: .semibold))

                ForEach(0..<nextFocusInputs.count, id: \.self) { index in
                    TextField("Focus #\(index + 1)", text: $nextFocusInputs[index])
                        .textFieldStyle(.roundedBorder)
                }

                Text("Aurora will surface these during morning rituals to keep your orbit aligned.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(22)
        }
    }

    private var metricsPanel: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Weekly Metrics")
                    .font(.system(size: 18, weight: .semibold))

                HStack(spacing: 18) {
                    metricTile(title: "Focus Gravity", value: review.focusGravityScore, format: "%.2f", icon: "globe")
                    metricTile(title: "Capture Velocity", value: review.captureVelocity, format: "%.1f", icon: "tray.and.arrow.down")
                    metricTile(title: "Output Velocity", value: review.outputVelocity, format: "%.1f", icon: "bolt.fill")
                    metricTile(title: "Clarity Index", value: review.clarityIndex, format: "%.0f%%", icon: "sparkles")
                }

                if !focusGravityTrend.isEmpty {
                    Chart {
                        ForEach(focusGravityTrend, id: \.0) { point in
                            LineMark(
                                x: .value("Date", point.0, unit: .day),
                                y: .value("Gravity", point.1)
                            )
                            .foregroundStyle(KosmicPalette.violet)
                        }
                    }
                    .frame(height: 150)
                }
            }
            .padding(22)
        }
    }

    private func metricTile(title: String, value: Double, format: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(KosmicPalette.violet)
                .font(.system(size: 20))
            Text(String(format: format, value))
                .font(.system(size: 20, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }

    private var finalizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                finalizeReview()
            } label: {
                HStack {
                    if case .saving = completionState {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Complete Weekly Review")
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
                    Text("Weekly review saved. Aurora updated your Clarity Index.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            case let .failure(message):
                HStack {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundColor(.orange)
                    Text(message)
                        .font(.system(size: 13))
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

    // MARK: - Data Loading

    private func loadData() async {
        await loadInbox()
        await loadCPS()
        await loadMetrics()
    }

    private func loadInbox() async {
        let descriptor = FetchDescriptor<InboxItem>(
            predicate: #Predicate { $0.convertedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let items = (try? modelContext.fetch(descriptor)) ?? []
        await MainActor.run {
            inboxItems = items
        }
    }

    private func loadCPS() async {
        let items = PriorityEngine.shared.getTopObjects(limit: 5, modelContext: modelContext)
        await MainActor.run {
            topCPSItems = items
        }
    }

    private func loadMetrics() async {
        let snapshot = AnalyticsEngine.shared.generateSnapshot(for: .thisWeek, modelContext: modelContext)
        await MainActor.run {
            review.focusGravityScore = snapshot.avgPriorityScore
            review.captureVelocity = Double(snapshot.tasksCreated)
            review.outputVelocity = Double(snapshot.tasksCompleted)
            review.clarityIndex = snapshot.learningScore * 100
            focusGravityTrend = RitualAnalytics.shared.completionTrend(days: 14, modelContext: modelContext)
        }
    }

    // MARK: - Actions

    private func generateInsightsSummary() async {
        isGeneratingInsights = true
        let cpsSummary = topCPSItems.map { "- \($0.title) (score \(String(format: "%.2f", $0.score)))" }.joined(separator: "\n")
        let prompt = "Summarize weekly focus shifts based on these priority items:\n\(cpsSummary). Provide 2-3 concise insights."
        do {
            let response = try await CoreResponseService.shared.generateResponse(for: prompt)
            await MainActor.run {
                insightsDraft = response
                isGeneratingInsights = false
            }
        } catch {
            await MainActor.run {
                insightsDraft = "Aurora couldn't generate insights right now. Capture your own takeaways."
                isGeneratingInsights = false
            }
        }
    }

    private func finalizeReview() {
        guard !isSaving else { return }
        completionState = .saving

        _Concurrency.Task { @MainActor in
            review.summary = buildSummary()
            review.insights = insightsDraft
            review.recommendations = recommendationsDraft
            review.nextFocuses = nextFocusInputs.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            review.markStarted()
            review.markCompleted()
            review.metadata["completedAt"] = Date().description

            RitualAnalytics.shared.recordWeeklyReview(review, modelContext: modelContext)
            completionState = .success
        }
    }

    private func buildSummary() -> String {
        let focuses = review.nextFocuses.joined(separator: ", ")
        return "Inbox cleared: \(review.inboxItemsCleared). Focus gravity: \(String(format: "%.2f", review.focusGravityScore)). Next focuses: \(focuses)."
    }
}

#Preview {
    do {
        let container = try ModelContainer(
            for: WeeklyReview.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let review = WeeklyReview(scheduledFor: Date())
        container.mainContext.insert(review)
        return WeeklyReviewView(review: review)
            .modelContainer(container)
            .frame(width: 880, height: 760)
    } catch {
        return Text("Preview unavailable")
    }
}
