//
//  PredictiveCognitionSettingsView.swift
//  Cloutmate
//
//  Phase 9: Predictive Reflection Engine
//  Settings control panel for predictive cognition features
//

import SwiftUI
import SwiftData

struct PredictiveCognitionSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("predictiveModeEnabled") private var predictiveModeEnabled = true
    @AppStorage("predictionConfidence") private var predictionConfidence = 0.75
    @AppStorage("toneAdaptationEnabled") private var toneAdaptationEnabled = true
    @AppStorage("forecastInterval") private var forecastInterval = 2
    @AppStorage("driftDetectionThreshold") private var driftDetectionThreshold = 0.10

    @State private var showResetConfirmation = false
    @State private var resetComplete = false

    private let confidenceRange: ClosedRange<Double> = 0.5...0.95
    private let driftRange: ClosedRange<Double> = 0.05...0.20

    var body: some View {
        Form {
            Section(header: Text("Predictive Mode")) {
                Toggle("Enable Predictive Cognition", isOn: $predictiveModeEnabled)
                    .onChange(of: predictiveModeEnabled) { newValue in
                        if !newValue {
                            CognitionPredictor.shared.stop()
                            DriftMonitor.shared.stop()
                        }
                    }

                Picker("Forecast Interval", selection: $forecastInterval) {
                    Text("Every 1 hour").tag(1)
                    Text("Every 2 hours").tag(2)
                    Text("Every 4 hours").tag(4)
                }
                .pickerStyle(.segmented)
                .onChange(of: forecastInterval) { _ in
                    Task { @MainActor in
                        if let context = modelContextIfAvailable {
                            await CognitionPredictor.shared.start(modelContext: context)
                            await DriftMonitor.shared.start(modelContext: context)
                        }
                    }
                }
            }

            Section(header: Text("Confidence Settings")) {
                Toggle("Adapt Tone Automatically", isOn: $toneAdaptationEnabled)
                    .onChange(of: toneAdaptationEnabled) { enabled in
                        ToneProfileCache.shared.setSuppressionFlag(!enabled, for: "tone_adaptation_disabled")
                    }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Confidence Threshold")
                        Spacer()
                        Text(String(format: "%.0f%%", predictionConfidence * 100))
                    }
                    Slider(value: $predictionConfidence, in: confidenceRange, step: 0.01)
                        .onChange(of: predictionConfidence) { newValue in
                            ToneProfileCache.shared.confidenceThreshold = newValue
                        }
                }
            }

            Section(header: Text("Drift Detection")) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Text(String(format: "%.0f%%", driftDetectionThreshold * 100))
                    }
                    Slider(value: $driftDetectionThreshold, in: driftRange, step: 0.01)
                        .onChange(of: driftDetectionThreshold) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "driftDetectionThreshold")
                        }
                    Text("Lower values trigger drift nudges sooner; higher values allow more variance before alerting.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("History")) {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Text("Reset Prediction History")
                }
                if resetComplete {
                    Text("Prediction history cleared")
                        .font(.footnote)
                        .foregroundColor(.kosmicGreen)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Predictive Cognition")
        .confirmationDialog(
            "Reset Prediction History?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive, action: resetHistory)
            Button("Cancel", role: .cancel) { showResetConfirmation = false }
        } message: {
            Text("This removes all saved forecasts and drift events. Aurora will need a few cycles to recalibrate.")
        }
    }

    private var modelContextIfAvailable: ModelContext? {
        modelContext
    }

    private func resetHistory() {
        let forecastDescriptor = FetchDescriptor<FocusForecast>()
        let driftDescriptor = FetchDescriptor<DriftEvent>()

        let forecasts = (try? modelContext.fetch(forecastDescriptor)) ?? []
        let driftEvents = (try? modelContext.fetch(driftDescriptor)) ?? []

        for forecast in forecasts { modelContext.delete(forecast) }
        for event in driftEvents { modelContext.delete(event) }

        do {
            try modelContext.save()
            ToneProfileCache.shared.reset()
            resetComplete = true
            showResetConfirmation = false
        } catch {
            resetComplete = false
        }
    }
}

#Preview {
    NavigationStack {
        PredictiveCognitionSettingsView()
    }
}


