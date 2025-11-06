//
//  MorningRitualView.swift
//  Cloutmate
//
//  Phase 8: Cognitive Loop Completion
//  Morning focus ritual highlighting top CPS priorities
//

import SwiftUI
import SwiftData

struct MorningRitualView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ritual: FocusRitual

    @State private var topItems: [PriorityItem] = []
    @State private var isLoading = false
    @State private var isRequestingSuggestion = false
    @State private var suggestionText: String?
    @State private var suggestionError: String?
    @State private var commitState: CommitState = .idle

    private enum CommitState: Equatable {
        case idle
        case committing
        case completed
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            prioritiesSection

            if let suggestionText {
                suggestionCard(text: suggestionText)
            } else if let suggestionError {
                suggestionErrorCard(message: suggestionError)
            }

            Spacer()
        }
        .padding(24)
        .task {
            await loadTopPriorities()
        }
        .animation(.easeInOut(duration: 0.2), value: suggestionText)
        .animation(.easeInOut(duration: 0.2), value: commitState)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Morning Focus Ritual")
                .font(.system(size: 28, weight: .bold))

            Text("Clarify today’s focus and commit to one priority")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Label("\(ritual.streakCount) day streak", systemImage: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 13, weight: .semibold))

                Text("Next window closes at \(ritual.windowEnd.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var prioritiesSection: some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Deserve Focus", systemImage: "target")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                if topItems.isEmpty {
                    Text("Aurora is learning what matters. Capture a few tasks or projects to get started.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(topItems.prefix(3), id: \.objectId) { item in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(item.detail)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    commit(to: item)
                                } label: {
                                    if case .committing = commitState {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Text("Commit to Focus")
                                            .font(.system(size: 13, weight: .semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(KosmicPalette.violet.opacity(0.15))
                                            .foregroundColor(KosmicPalette.violet)
                                            .cornerRadius(8)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isCommitDisabled)
                            }

                            if item.objectId == topItems.first?.objectId {
                                suggestionButton(for: item)
                            }
                        }
                        .padding(16)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(12)
                    }
                }

                if case .completed = commitState {
                    successBanner
                } else if case let .failed(message) = commitState {
                    failureBanner(message: message)
                }
            }
            .padding(20)
        }
    }

    private func suggestionButton(for item: PriorityItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundColor(KosmicPalette.cyan)
            if isRequestingSuggestion {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Would you like me to break this into steps?") {
                    _Concurrency.Task {
                        await requestSuggestion(for: item)
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    private var successBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.kosmicGreen)
            Text("Committed. Aurora will track your focus momentum for the next 12 hours.")
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .padding(12)
        .background(Color.kosmicGreen.opacity(0.1))
        .cornerRadius(10)
    }

    private func failureBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }

    private func suggestionCard(text: String) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Aurora’s Focus Steps", systemImage: "list.bullet.rectangle.portrait")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(20)
        }
    }

    private func suggestionErrorCard(message: String) -> some View {
        GlassPanel(tier: .contentCard, cornerRadius: 18) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "icloud.slash")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(18)
        }
    }

    private var isCommitDisabled: Bool {
        switch commitState {
        case .committing: return true
        default: return false
        }
    }

    private func commit(to item: PriorityItem) {
        guard !isCommitDisabled else { return }
        commitState = .committing

        _Concurrency.Task { @MainActor in
            do {
                let session = try FocusSessionService.shared.startSession(
                    objective: item.title,
                    plannedDuration: 3600,
                    targetObjectId: item.objectId,
                    targetObjectType: item.objectType.lowercased(),
                    modelContext: modelContext
                )

                PriorityEngine.shared.boostScore(
                    for: [item.objectId],
                    amount: 0.35,
                    modelContext: modelContext
                )

                let highlights = ["Committed to focus session: \(item.title)"]
                let completionInput = RitualCompletionInput(
                    outcome: .completed,
                    completedAt: Date(),
                    duration: session.plannedDuration,
                    userNotes: nil,
                    aiRecap: nil,
                    highlights: highlights,
                    focusItemIds: [item.objectId],
                    taskStatusCounts: [:],
                    cpsBoostApplied: true,
                    momentumDelta: 0.15,
                    metadata: ["source": "morning-ritual"]
                )

                _ = FocusRitualManager.shared.completeRitual(ritual, input: completionInput, modelContext: modelContext)
                commitState = .completed
            } catch {
                commitState = .failed("Unable to start focus session. Please try again.")
            }
        }
    }

    private func loadTopPriorities() async {
        await MainActor.run { isLoading = true }
        let items = PriorityEngine.shared.getTopObjects(limit: 3, modelContext: modelContext)
        await MainActor.run {
            topItems = items
            isLoading = false
        }
    }

    private func requestSuggestion(for item: PriorityItem) async {
        suggestionError = nil
        suggestionText = nil
        isRequestingSuggestion = true

        let prompt = "Break the goal \"\(item.title)\" into 3 focused steps I can take today. Keep it concise."

        do {
            let response = try await CoreResponseService.shared.generateResponse(for: prompt)
            await MainActor.run {
                suggestionText = response
                isRequestingSuggestion = false
            }
        } catch {
            await MainActor.run {
                suggestionError = "Aurora couldn't craft steps right now. Try again shortly."
                isRequestingSuggestion = false
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
        let context = container.mainContext
        let ritual = FocusRitual(
            type: .morning,
            scheduledFor: Date(),
            windowEnd: Date().addingTimeInterval(3600)
        )
        context.insert(ritual)
        return MorningRitualView(ritual: ritual)
            .modelContainer(container)
            .frame(width: 420, height: 520)
    } catch {
        return Text("Preview unavailable")
    }
}


