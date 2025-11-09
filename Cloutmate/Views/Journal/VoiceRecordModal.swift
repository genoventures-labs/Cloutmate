import SwiftUI
import SwiftData

enum VoiceRecordMode {
    case newEntry
    case append(existing: Journal)
}

struct VoiceRecordModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: VoiceRecordMode
    var onTranscript: ((String) -> Void)? = nil

    @State private var isRecording = false
    @State private var isPaused = false
    @State private var transcript: String = ""
    @State private var errorMessage: String? = nil
    @State private var level: CGFloat = 0
    @State private var startDate: Date? = nil
    @State private var showInfo = false
    @State private var showConfirm = false

    private var elapsed: String {
        guard let startDate, isRecording else { return "00:00" }
        let interval = Date().timeIntervalSince(startDate)
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            WaveformView(level: level)
                .frame(height: 48)
                .glassPanel(tier: .contentCard, cornerRadius: 10)

            HStack {
                Label(elapsed, systemImage: "timer")
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    showInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .popover(isPresented: $showInfo, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy")
                            .font(.headline)
                        Text("For privacy, audio isn’t stored. Only the transcript is kept.")
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(width: 320)
                }
            }

            ScrollView {
                Text(transcript.isEmpty ? "Your transcript will appear here…" : transcript)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(8)
            }
            .frame(minHeight: 160, maxHeight: 260)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            controls
        }
        .padding(20)
        .frame(width: 560, height: 460)
        .onAppear { authorizeAndStart() }
        .onDisappear { VoiceTranscriptionService.shared.stopTranscribing() }
        .confirmationDialog("Use transcript?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Save") { handleSave() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use the captured transcript for this journal?")
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.accentColor)
                Text(titleText)
                    .font(.headline)
            }
            Spacer()
            Button("Close") { dismiss() }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                toggleRecording()
            } label: {
                Label(isRecording && !isPaused ? "Pause" : "Record", systemImage: isRecording && !isPaused ? "pause.circle.fill" : "mic.circle.fill")
            }
            .buttonStyle(.borderedProminent)

            Button {
                stopAndConfirm()
            } label: {
                Label("Stop & Save", systemImage: "stop.circle")
            }
            .buttonStyle(.bordered)
            .disabled(!isRecording && transcript.isEmpty)

            Spacer()

            Button(role: .cancel) {
                cancelAll()
            } label: { Text("Cancel") }
        }
    }

    private var titleText: String {
        switch mode {
        case .newEntry: return "Record New Journal"
        case .append: return "Record to Append"
        }
    }

    // MARK: - Actions
    private func authorizeAndStart() {
        errorMessage = nil
        _Concurrency.Task { @MainActor in
            do {
                try await VoiceTranscriptionService.shared.requestPermissions()
                bindCallbacks()
                try VoiceTranscriptionService.shared.startTranscribing()
                isRecording = true
                isPaused = false
                startDate = Date()
            } catch {
                errorMessage = "⚠️ \(error.localizedDescription)\n\nTip: Check System Settings → Privacy & Security → Microphone and Speech Recognition"
                isRecording = false
            }
        }
    }

    private func bindCallbacks() {
        VoiceTranscriptionService.shared.onPartial = { text in
            self.transcript = text
        }
        VoiceTranscriptionService.shared.onFinal = { text in
            self.transcript = text
        }
        VoiceTranscriptionService.shared.onError = { error in
            self.errorMessage = error.localizedDescription
        }
        VoiceTranscriptionService.shared.onLevelUpdate = { value in
            // Smooth animate to reduce jitter
            let clamped = max(0, min(1, value))
            withAnimation(.linear(duration: 0.08)) {
                self.level = CGFloat(clamped)
            }
        }
    }

    private func toggleRecording() {
        guard isRecording else {
            // restart
            do {
                try VoiceTranscriptionService.shared.startTranscribing()
                isRecording = true
                isPaused = false
                if startDate == nil { startDate = Date() }
            } catch { errorMessage = error.localizedDescription }
            return
        }
        if isPaused {
            do { try VoiceTranscriptionService.shared.resume(); isPaused = false } catch { errorMessage = error.localizedDescription }
        } else {
            VoiceTranscriptionService.shared.pause(); isPaused = true
        }
    }

    private func stopAndConfirm() {
        VoiceTranscriptionService.shared.stopTranscribing()
        isRecording = false
        isPaused = false
        showConfirm = true
    }

    private func handleSave() {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { dismiss(); return }
        if let onTranscript { onTranscript(text) }
        switch mode {
        case .newEntry:
            let journal = Journal(
                title: "Voice Journal \(Date().formatted())",
                content: text,
                entryDate: Date(),
                entryType: .reflection,
                mood: .none,
                tags: []
            )
            journal.author = .user
            modelContext.insert(journal)
            try? modelContext.save()
        case .append(let existing):
            let divider = "\n\n— Voice note on \(Date().formatted()) —\n"
            existing.content += divider + text
            existing.updatedAt = Date()
            try? modelContext.save()
        }
        dismiss()
    }

    private func cancelAll() {
        VoiceTranscriptionService.shared.stopTranscribing()
        dismiss()
    }
}

#Preview {
    VoiceRecordModal(mode: .newEntry)
        .frame(width: 560, height: 460)
}


