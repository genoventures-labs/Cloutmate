//
//  AreaCadenceSettingsView.swift
//  FocusOS
//
//  Publishing rules and cadence settings for Areas
//

import SwiftUI
import SwiftData
import FocusOSShared

struct AreaCadenceSettingsView: View {
    @Bindable var area: Area
    @Environment(\.modelContext) private var modelContext
    @State private var postsPerWeek = 3
    @State private var quietHoursStart = 21
    @State private var quietHoursEnd = 8
    @State private var autoSchedule = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Image(systemName: "rectangle.stack.fill")
                        .foregroundStyle(Color.kosmicBlue)
                        .font(.largeTitle)
                    Text("Cadence Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding()
                .glassPanel(tier: .overlay, cornerRadius: 12)
                
                // Publishing Rules Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Publishing Rules")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Posts per week
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Posts per week")
                                .font(.subheadline)
                            Spacer()
                            Text("\(postsPerWeek)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                        
                        Slider(value: Binding(
                            get: { Double(postsPerWeek) },
                            set: { postsPerWeek = Int($0) }
                        ), in: 1...14, step: 1)
                        .padding(.horizontal)
                    }
                    .padding()
                    .glassPanel(tier: .contentCard, cornerRadius: 12)
                    .padding(.horizontal)
                    
                    // Quiet hours
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quiet Hours")
                            .font(.subheadline)
                            .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("Start Hour", selection: $quietHoursStart) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text("\(hour):00").tag(hour)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("End")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("End Hour", selection: $quietHoursEnd) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text("\(hour):00").tag(hour)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                    .padding()
                    .glassPanel(tier: .contentCard, cornerRadius: 12)
                    .padding(.horizontal)
                    
                    // Auto schedule
                    Toggle(isOn: $autoSchedule) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto Schedule")
                                .font(.subheadline)
                            Text("Automatically suggest posting times based on history")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .glassPanel(tier: .contentCard, cornerRadius: 12)
                    .padding(.horizontal)
                }
            }
        }
        .background(Color.clear)
        .navigationTitle("Area Settings")
        .onAppear {
            loadSettings()
        }
        .onDisappear {
            saveSettings()
        }
    }
    
    private func loadSettings() {
        guard let settingsJson = area.cadenceSetting else { return }
        
        do {
            if let data = settingsJson.data(using: .utf8),
               let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                postsPerWeek = settings["posts_per_week"] as? Int ?? 3
                
                if let quietHours = settings["quiet_hours"] as? String {
                    let parts = quietHours.split(separator: "-")
                    if parts.count == 2 {
                        quietHoursStart = Int(String(parts[0])) ?? 21
                        quietHoursEnd = Int(String(parts[1])) ?? 8
                    }
                }
                
                autoSchedule = settings["auto_schedule"] as? Bool ?? false
            }
        } catch {
            print("Failed to parse settings: \(error)")
        }
    }
    
    private func saveSettings() {
        var settings: [String: Any] = [:]
        settings["posts_per_week"] = postsPerWeek
        settings["quiet_hours"] = "\(quietHoursStart)-\(quietHoursEnd)"
        settings["auto_schedule"] = autoSchedule
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: settings)
            area.cadenceSetting = String(data: jsonData, encoding: .utf8)
            area.updatedAt = Date()
            try? modelContext.save()
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
}

#Preview {
    AreaCadenceSettingsView(area: Area(title: "Example Area"))
        .modelContainer(for: [Area.self])
}

