//
//  FocusModeCompletionDrawer.swift
//  Cloutmate
//
//  V2: Completion drawer for focus sessions
//

import SwiftUI
import SwiftData
import Charts
import CloutmateShared

struct FocusModeCompletionDrawer: View {
    @Binding var isPresented: Bool
    let session: FocusSession
    let metrics: FocusSessionMetrics
    let onAddReflection: (String) -> Void
    let onReturnHome: () -> Void
    let onStartAnother: () -> Void
    
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var reflectionText = ""
    @State private var auroraComment = ""
    @State private var isLoadingComment = true
    
    private var tone: AuroraTone {
        .reflective
    }
    
    var body: some View {
        Group {
            if isPresented {
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        // Backdrop
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                closeDrawer()
                            }
                            .transition(.opacity)
                        
                        // Drawer slides up from bottom
                        VStack(spacing: 0) {
                            V2DrawerScaffold(
                                accentGradient: AuroraToneKit.accentGradient(for: tone),
                                showsSidebar: false,
                                header: { headerContent },
                                content: { drawerContent },
                                sidebar: { EmptyView() }
                            )
                        }
                        .frame(maxHeight: geometry.size.height * 0.75)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .onAppear {
                    generateAuroraComment()
                }
            }
        }
    }
    
    private var headerContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Session Complete")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Focus session summary")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Spacer()
            
            GlassButton(
                nil,
                icon: "xmark",
                style: .iconOnly,
                role: .surface,
                tintColor: glassColorSystem.backgroundElevated()
            ) {
                closeDrawer()
            }
            .accessibilityLabel("Close")
        }
    }
    
    @ViewBuilder
    private var drawerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Summary Card
                summaryCard
                
                // Aurora Comment
                if !auroraComment.isEmpty {
                    auroraCommentCard
                }
                
                // Focus Gravity Trend (mini chart)
                if !metrics.focusGravityTrend.isEmpty {
                    focusGravityChart
                }
                
                // Reflection Prompt
                reflectionSection
                
                // Action Buttons
                actionButtons
            }
            .padding(.vertical, 8)
        }
    }
    
    private var summaryCard: some View {
        DashboardTile(accent: AuroraToneKit.accentColor(for: tone), padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AuroraToneKit.accentColor(for: tone))
                    
                    Text("Session Summary")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                }
                
                HStack(spacing: 24) {
                    statCard(
                        label: "Duration",
                        value: session.durationFormatted,
                        color: .kosmicBlue
                    )
                    
                    statCard(
                        label: "Stability",
                        value: "\(Int(metrics.stabilityIndex))%",
                        color: stabilityColor
                    )
                    
                    statCard(
                        label: "Focus",
                        value: "\(Int(metrics.focusStabilityPercentage * 100))%",
                        color: .kosmicGreen
                    )
                }
            }
        }
    }
    
    private var auroraCommentCard: some View {
        DashboardTile(accent: AuroraToneKit.accentColor(for: tone), padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AuroraToneKit.accentColor(for: tone))
                    
                    Text("Aurora's Reflection")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                }
                
                if isLoadingComment {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Aurora is reflecting...")
                            .font(.body)
                            .foregroundStyle(glassColorSystem.textSecondary())
                    }
                } else {
                    Text(auroraComment)
                        .font(.body)
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    private var focusGravityChart: some View {
        DashboardTile(accent: .kosmicBlue, padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.kosmicBlue)
                    Text("Focus Gravity Trend")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(glassColorSystem.textPrimary())
                }
                
                Chart {
                    ForEach(Array(metrics.focusGravityTrend.enumerated()), id: \.offset) { index, value in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("Focus", value)
                        )
                        .foregroundStyle(Color.kosmicBlue)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", index),
                            y: .value("Focus", value)
                        )
                        .foregroundStyle(Color.kosmicBlue.opacity(0.2))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 100)
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
            }
        }
    }
    
    private var reflectionSection: some View {
        DashboardTile(accent: AuroraToneKit.accentColor(for: tone), padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("What helped you stay focused today?")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                TextEditor(text: $reflectionText)
                    .font(.body)
                    .foregroundStyle(glassColorSystem.textPrimary())
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(glassColorSystem.borderColor().opacity(0.3), lineWidth: 1)
                            )
                    )
                    .scrollContentBackground(.hidden)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            GlassButton(
                "Add Reflection",
                icon: "text.bubble.fill",
                style: .pill,
                role: .accent
            ) {
                onAddReflection(reflectionText)
                closeDrawer()
            }
            .disabled(reflectionText.isEmpty)
            
            Spacer()
            
            GlassButton(
                "Return Home",
                icon: "house.fill",
                style: .pill,
                role: .surface
            ) {
                onReturnHome()
                closeDrawer()
            }
            
            GlassButton(
                "Start Another",
                icon: "arrow.clockwise",
                style: .pill,
                role: .primary
            ) {
                onStartAnother()
                closeDrawer()
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(glassColorSystem.textSecondary())
        }
    }
    
    private var stabilityColor: Color {
        if metrics.stabilityIndex >= 70 {
            return .kosmicGreen
        } else if metrics.stabilityIndex >= 40 {
            return .kosmicBlue
        } else {
            return .red
        }
    }
    
    // MARK: - Methods
    
    private func closeDrawer() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
    
    private func generateAuroraComment() {
        _Concurrency.Task {
            let prompt = """
            Generate a brief, encouraging comment about this focus session. Be reflective and supportive.
            
            Session details:
            - Objective: \(session.objective)
            - Duration: \(session.durationFormatted)
            - Stability Index: \(Int(metrics.stabilityIndex))%
            - Focus Stability: \(Int(metrics.focusStabilityPercentage * 100))%
            - Emotional Average: \(String(format: "%.2f", metrics.averageLF))
            
            Keep it to 1-2 sentences, like "You maintained stable focus for 82% of this session."
            """
            
            do {
                let comment = try await CoreResponseService.shared.generateResponse(
                    for: prompt,
                    context: "",
                    modelContext: modelContext,
                    toneContext: tone
                )
                await MainActor.run {
                    auroraComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
                    isLoadingComment = false
                }
            } catch {
                await MainActor.run {
                    auroraComment = "You completed a focused session. Well done!"
                    isLoadingComment = false
                }
            }
        }
    }
    
    // MARK: - Lifecycle
    
    func onAppear() {
        generateAuroraComment()
    }
}

#Preview {
    let session = FocusSession(objective: "Write blog post", plannedDuration: 1800)
    session.status = .completed
    session.endTime = Date()
    session.actualDuration = 1800
    
    let metrics = FocusSessionMetrics(
        averageLF: 0.4,
        stabilityIndex: 75.0,
        emotionalVariance: 0.15,
        focusGravityTrend: [0.7, 0.75, 0.8, 0.85, 0.9],
        focusStabilityPercentage: 0.82
    )
    
    return FocusModeCompletionDrawer(
        isPresented: .constant(true),
        session: session,
        metrics: metrics,
        onAddReflection: { _ in },
        onReturnHome: {},
        onStartAnother: {}
    )
    .environmentObject(GlassColorSystem())
    .modelContainer(for: [FocusSession.self])
}

