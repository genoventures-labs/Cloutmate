import Foundation
import AVFoundation
import Speech
import Accelerate

final class VoiceTranscriptionService: NSObject {
    static let shared = VoiceTranscriptionService()

    // Callbacks
    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    var onLevelUpdate: ((Float) -> Void)? // 0.0...1.0

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var accumulatedText: String = ""
    #if os(iOS)
    private let audioSession = AVAudioSession.sharedInstance()
    #endif

    private override init() {
        // English, on-device requirement
        let locale = Locale(identifier: "en_US")
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        super.init()
    }

    // MARK: - Permissions
    func requestPermissions() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            SFSpeechRecognizer.requestAuthorization { auth in
                switch auth {
                case .authorized:
                    #if os(iOS)
                    do {
                        try self.audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                        try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                        cont.resume()
                    } catch {
                        cont.resume(throwing: error)
                    }
                    #else
                    cont.resume()
                    #endif
                case .denied:
                    cont.resume(throwing: NSError(domain: "VoiceTranscription", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech permission denied"]))
                case .restricted, .notDetermined:
                    cont.resume(throwing: NSError(domain: "VoiceTranscription", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech permission not available"]))
                @unknown default:
                    cont.resume(throwing: NSError(domain: "VoiceTranscription", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unknown speech permission state"]))
                }
            }
        }
    }

    // MARK: - Recording & Recognition
    func startTranscribing() throws {
        guard recognitionTask == nil else { return }
        guard let speechRecognizer else {
            throw NSError(domain: "VoiceTranscription", code: 10, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable for en_US"])
        }

        if !speechRecognizer.isAvailable {
            throw NSError(domain: "VoiceTranscription", code: 11, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
        }

        // Reset accumulated text for new session
        accumulatedText = ""

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw NSError(domain: "VoiceTranscription", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to create recognition request"])
        }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate the format
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw NSError(domain: "VoiceTranscription", code: 13, userInfo: [NSLocalizedDescriptionKey: "Invalid audio format from input node"])
        }

        // Create a compatible format for speech recognition
        // Speech recognition prefers mono, 16kHz sample rate
        guard let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            // If we can't create the recording format, use input format directly
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
                guard let self else { return }
                self.recognitionRequest?.append(buffer)
                self.updateLevel(from: buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        if !self.accumulatedText.isEmpty {
                            self.accumulatedText += " "
                        }
                        self.accumulatedText += text
                        self.onFinal?(self.accumulatedText)
                    } else {
                        let combined = self.accumulatedText.isEmpty ? text : "\(self.accumulatedText) \(text)"
                        self.onPartial?(combined)
                    }
                }
                if let error {
                    self.onError?(error)
                    self.stopTranscribing()
                }
            }
            return
        }
        
        // Create a converter if needed
        var converter: AVAudioConverter?
        if inputFormat != recordingFormat {
            converter = AVAudioConverter(from: inputFormat, to: recordingFormat)
        }

        inputNode.removeTap(onBus: 0)
        // Use the recording format (or input format if converter not needed)
        let tapFormat = converter != nil ? recordingFormat : inputFormat
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
            guard let self else { return }
            
            // Convert buffer if needed
            if let converter = converter {
                let capacity = AVAudioFrameCount(Double(buffer.frameLength) * recordingFormat.sampleRate / inputFormat.sampleRate)
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: recordingFormat, frameCapacity: capacity) else {
                    return
                }
                
                var error: NSError?
                converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                if error == nil {
                    self.recognitionRequest?.append(convertedBuffer)
                    self.updateLevel(from: convertedBuffer)
                }
            } else {
                self.recognitionRequest?.append(buffer)
                self.updateLevel(from: buffer)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    // Append to accumulated text with proper spacing
                    if !self.accumulatedText.isEmpty {
                        self.accumulatedText += " "
                    }
                    self.accumulatedText += text
                    self.onFinal?(self.accumulatedText)
                } else {
                    // Show accumulated text + current partial
                    let combined = self.accumulatedText.isEmpty ? text : "\(self.accumulatedText) \(text)"
                    self.onPartial?(combined)
                }
            }
            if let error {
                self.onError?(error)
                self.stopTranscribing()
            }
        }
    }

    func stopTranscribing() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        #if os(iOS)
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    func pause() {
        audioEngine.pause()
    }

    func resume() throws {
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
    }

    // MARK: - Level Metering
    private func updateLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        var sum: Float = 0
        vDSP_meamgv(channelDataArray, 1, &sum, vDSP_Length(buffer.frameLength))
        var avgPower: Float = 0
        var one: Float = 1
        vDSP_vdbcon(&sum, 1, &one, &avgPower, 1, 1, 0)
        // map dB (-80..0) to 0..1
        let clamped = max(-80, min(0, avgPower))
        let normalized = (clamped + 80) / 80
        onLevelUpdate?(normalized)
    }
}


