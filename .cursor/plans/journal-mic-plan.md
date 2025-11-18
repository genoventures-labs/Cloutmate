<!-- 17a3393b-0abd-4695-80b6-34495940758b f7a2a83e-c18b-434d-98a3-8e0743cf89d3 -->
# In-App Voice Journaling (On-Device, No Audio Storage)

## Scope

Add a fully in-app voice recording + live transcription experience using Apple’s on-device Speech (English). Includes a custom recording modal with animated waveform, privacy info button, and two entry points: create new entry or append inside the editor.

## Key Decisions

- Speech: Apple `SFSpeechRecognizer(locale: en_US)` with `requiresOnDeviceRecognition = true`.
- Privacy: Do not persist audio files; show an Info button explaining this.
- UI: Custom modal with mic icon, animated waveform, elapsed time, live transcript, start/pause/stop.

## Files to Add

- `FocusOS/Services/VoiceTranscriptionService.swift`
  - Manages `AVAudioEngine`, `SFSpeechRecognizer`, authorization, start/stop, partial/final results, errors.
  - Exposes callbacks: `onPartial(String)`, `onFinal(String)`, `onError(Error)`, `onLevelUpdate(Float)`.
- `FocusOS/Views/Journal/VoiceRecordModal.swift`
  - SwiftUI modal with: custom mic icon, animated waveform, live text, timer, start/pause/stop, Info popover.
  - Presents in two modes: `.newEntry` and `.append(existing: Journal)`.
- `FocusOS/Views/Journal/WaveformView.swift`
  - Lightweight animated waveform using audio level updates.
- Assets: add `FocusOSMic` symbol in `FocusOS/Assets.xcassets` (vector PDF / SF Symbol override).

## Files to Update

- `FocusOS/Info.plist`
  - Add `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` strings.
- `FocusOS/Views/Journal/JournalView.swift`
  - Toolbar: add "Record Entry" button → presents `VoiceRecordModal(mode: .newEntry)`. On completion, create a new `Journal` with the transcript, type `.reflection`, mood `.none` by default.
- `FocusOS/Views/Journal/JournalView.swift` (detail sheet section already present)
  - Inside `JournalDetailView` toolbar: add mic button to present `VoiceRecordModal(mode: .append(existing: journal))`. On completion, append transcript to `journal.content` (with timestamp divider).

## UX Details

- Recording Modal
  - Header: mic icon (app asset), title, close button.
  - Body: waveform, elapsed time, scrolling live transcript.
  - Footer: Record/Pause, Stop & Save, Cancel.
  - Info: small button with popover text: “For privacy, audio isn’t stored. Only the transcript is kept.”
- Behavior
  - Live transcript updates with partial results; final result captured on stop.
  - If no speech detected, show a friendly prompt to try again.
  - On `.newEntry`: after stop → confirmation sheet to review transcript → Create Journal.
  - On `.append`: after stop → confirmation (Append / Replace selection, default Append) → update `journal.content`.

## Error/Permissions Handling

- Request mic + speech permission upfront when opening modal; show inline errors and retry.
- Force on-device recognition; if unavailable, show an instruction: “On‑device speech not available on this Mac.”
- Handle interruptions (phone call, audio session) by auto-pausing and notifying the user.

## Essential Integration Snippets

- Presenting from `JournalView` toolbar:
```12:24:FocusOS/Views/Journal/JournalView.swift
.toolbar {
    ToolbarItemGroup(placement: .primaryAction) {
        Button {
            showRecordingModal = true
        } label: {
            Label("Record Entry", systemImage: "mic")
        }
    }
}
.sheet(isPresented: $showRecordingModal) {
    VoiceRecordModal(mode: .newEntry) { transcript in
        createJournalFromTranscript(transcript)
    }
}
```

- Appending from `JournalDetailView` toolbar:
```498:506:FocusOS/Views/Journal/JournalView.swift
.toolbar {
    ToolbarItemGroup(placement: .automatic) {
        Button {
            showRecordToAppend.toggle()
        } label: { Label("Voice", systemImage: "mic") }
    }
}
.sheet(isPresented: $showRecordToAppend) {
    VoiceRecordModal(mode: .append(existing: journal)) { transcript in
        appendTranscriptToJournal(transcript)
    }
}
```


## Data Model

- No schema changes. We only write to existing `Journal.content`. Optionally set `journal.journalEntryType = .reflection` for new entries.

## Testing

- Manual: verify permissions, live transcript, stop/save flow, new entry creation, append flow.
- Unit-light: a small service test to ensure recognizer locale/on-device flag configuration (behind `@testable import`).

## Out of Scope

- Cloud/offline model downloads, multi-language auto-detect, audio file storage.

### To-dos

- [ ] Create VoiceTranscriptionService with on-device Apple Speech and level metering
- [ ] Add WaveformView for animated mic levels
- [ ] Build VoiceRecordModal with live transcript and privacy info
- [ ] Integrate Record Entry button in JournalView to create new entry
- [ ] Integrate mic in JournalDetailView to append transcript
- [ ] Add mic and speech usage descriptions in Info.plist
- [ ] Add custom FocusOSMic asset for mic icon
- [ ] Run manual QA for permissions, new entry, append, errors