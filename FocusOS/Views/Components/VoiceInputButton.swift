//
//  VoiceInputButton.swift
//  FocusOS
//
//  Reusable voice-to-text input button for text fields
//

import SwiftUI

struct VoiceInputButton: View {
    @Binding var text: String
    @State private var isRecording = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var audioLevel: CGFloat = 0
    
    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red.opacity(0.2) : Color.kosmicBlue.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                if isRecording {
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 32 + audioLevel * 8, height: 32 + audioLevel * 8)
                        .animation(.easeInOut(duration: 0.1), value: audioLevel)
                }
                
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isRecording ? .red : .kosmicBlue)
            }
        }
        .buttonStyle(.plain)
        .help(isRecording ? "Stop recording" : "Start voice input")
        .alert("Voice Input Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func startRecording() {
        errorMessage = ""
        showError = false
        
        _Concurrency.Task { @MainActor in
            do {
                try await VoiceTranscriptionService.shared.requestPermissions()
                bindCallbacks()
                try VoiceTranscriptionService.shared.startTranscribing()
                isRecording = true
            } catch {
                errorMessage = "⚠️ \(error.localizedDescription)\n\nCheck System Settings → Privacy & Security → Microphone and Speech Recognition"
                showError = true
            }
        }
    }
    
    private func stopRecording() {
        // Give a moment for final transcription to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let finalText = self.text
            VoiceTranscriptionService.shared.stopTranscribing()
            self.isRecording = false
            self.audioLevel = 0
            // Ensure text is preserved after stopping
            self.text = finalText
        }
    }
    
    private func bindCallbacks() {
        VoiceTranscriptionService.shared.onPartial = { [self] transcribedText in
            self.text = transcribedText
        }
        VoiceTranscriptionService.shared.onFinal = { [self] transcribedText in
            self.text = transcribedText
        }
        VoiceTranscriptionService.shared.onError = { [self] error in
            self.errorMessage = error.localizedDescription
            self.showError = true
            self.isRecording = false
        }
        VoiceTranscriptionService.shared.onLevelUpdate = { [self] level in
            withAnimation(.linear(duration: 0.08)) {
                self.audioLevel = CGFloat(level)
            }
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    VStack {
        Text("Text: \(text)")
        VoiceInputButton(text: $text)
    }
    .padding()
}

