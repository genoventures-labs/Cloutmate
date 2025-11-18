//
//  WindowSelectionView.swift
//  FocusOS
//
//  Window selection UI for screenshot capture.
//

import SwiftUI
import CoreGraphics

struct WindowSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var windows: [ScreenshotService.WindowInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isCapturing = false
    
    let onWindowSelected: (CGWindowID) async throws -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Window to Screenshot")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    onDismiss()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading windows...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if let error = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Permission Required")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if error.contains("permission") || error.contains("TCC") || error.contains("declined") {
                        VStack(spacing: 12) {
                            Text("To enable screenshots:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text("1.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Open System Settings")
                                        .font(.caption)
                                }
                                HStack(spacing: 8) {
                                    Text("2.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Go to Privacy & Security → Screen Recording")
                                        .font(.caption)
                                }
                                HStack(spacing: 8) {
                                    Text("3.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Enable FocusOS")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal)
                            
                            Button("Open System Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Retry") {
                                loadWindows()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button("Retry") {
                            loadWindows()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if windows.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "window.shade.open")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Windows Available")
                        .font(.headline)
                    Text("No windowed applications are currently open.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(windows) { window in
                            WindowRow(
                                window: window,
                                isCapturing: isCapturing,
                                onSelect: {
                                    selectWindow(window.id)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadWindows()
        }
    }
    
    private func loadWindows() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let availableWindows = try await ScreenshotService.shared.getAvailableWindows()
                await MainActor.run {
                    windows = availableWindows
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    // Check if it's a permission error (TCC or ScreenCaptureKit errors)
                    let errorDesc = error.localizedDescription
                    if errorDesc.contains("TCC") || 
                       errorDesc.contains("declined") || 
                       errorDesc.contains("permission") ||
                       errorDesc.contains("Screen Recording") {
                        errorMessage = "Screen recording permission is required. Please grant permission in System Settings → Privacy & Security → Screen Recording."
                    } else {
                        errorMessage = errorDesc
                    }
                    isLoading = false
                }
            }
        }
    }
    
    private func selectWindow(_ windowID: CGWindowID) {
        guard !isCapturing else { return }
        
        isCapturing = true
        
        Task {
            do {
                try await onWindowSelected(windowID)
                await MainActor.run {
                    isCapturing = false
                    onDismiss()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCapturing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct WindowRow: View {
    let window: ScreenshotService.WindowInfo
    let isCapturing: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // App Icon
                if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .cornerRadius(6)
                } else {
                    Image(systemName: "app")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(6)
                }
                
                // Window Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(window.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(window.appName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection indicator
                if isCapturing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
    }
}

#Preview {
    WindowSelectionView(
        onWindowSelected: { _ in },
        onDismiss: {}
    )
}

