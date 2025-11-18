//
//  PermissionsPrivacySection.swift
//  FocusOS
//
//  Permissions & Privacy settings section
//

import SwiftUI
import AppKit
import Speech
import UserNotifications
import AVFoundation

struct PermissionsPrivacySection: View {
    @State private var microphoneStatus: PermissionStatus = .notDetermined
    @State private var speechStatus: PermissionStatus = .notDetermined
    @State private var notificationsStatus: PermissionStatus = .notDetermined
    @State private var showPermissionAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Microphone Permission
            PermissionRow(
                title: "Microphone",
                description: "Required for voice-to-text journaling",
                icon: "mic.fill",
                iconColor: .kosmicBlue,
                status: microphoneStatus,
                onToggle: { requestMicrophonePermission() }
            )
            
            Divider()
            
            // Speech Recognition Permission
            PermissionRow(
                title: "Speech Recognition",
                description: "Transcribes voice into journal entries",
                icon: "waveform",
                iconColor: .kosmicPurple,
                status: speechStatus,
                onToggle: { requestSpeechPermission() }
            )
            
            Divider()
            
            // Notifications Permission
            PermissionRow(
                title: "Notifications",
                description: "Get alerts for post publishing & failures",
                icon: "bell.fill",
                iconColor: .orange,
                status: notificationsStatus,
                onToggle: { requestNotificationsPermission() }
            )
            
            Divider()
            
            // Reset All Permissions
            Button(action: {
                resetAllPermissions()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    Text("Reset All Permissions")
                        .font(.body)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // System Settings Button
            Button(action: {
                openSystemSettings()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    Text("Open System Settings")
                        .font(.body)
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Text("Some permissions must be managed in System Settings → Privacy & Security. After resetting, you may need to restart the app.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .onAppear {
            checkAllPermissions()
        }
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("Open System Settings", role: .cancel) {
                openSystemSettings()
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Permission Checking
    private func checkAllPermissions() {
        checkMicrophonePermission()
        checkSpeechPermission()
        checkNotificationsPermission()
    }
    
    private func checkMicrophonePermission() {
        #if os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            microphoneStatus = .authorized
        case .denied, .restricted:
            microphoneStatus = .denied
        case .notDetermined:
            microphoneStatus = .notDetermined
        @unknown default:
            microphoneStatus = .notDetermined
        }
        #endif
    }
    
    private func checkSpeechPermission() {
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        speechStatus = PermissionStatus(from: authStatus)
    }
    
    private func checkNotificationsPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsStatus = PermissionStatus(from: settings.authorizationStatus)
            }
        }
    }
    
    // MARK: - Permission Requests
    private func requestMicrophonePermission() {
        // First, try to trigger the system permission dialog
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if granted {
                    microphoneStatus = .authorized
                } else {
                    microphoneStatus = .denied
                    alertMessage = "Microphone access denied.\n\nTo enable: System Settings → Privacy & Security → Microphone → Enable FocusOS"
                    showPermissionAlert = true
                }
                checkMicrophonePermission()
            }
        }
    }
    
    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                speechStatus = PermissionStatus(from: status)
                if status != .authorized {
                    alertMessage = "Speech Recognition access is required for voice journaling.\n\nGo to: System Settings → Privacy & Security → Speech Recognition"
                    showPermissionAlert = true
                }
            }
        }
    }
    
    private func requestNotificationsPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                notificationsStatus = granted ? .authorized : .denied
                checkNotificationsPermission()
                if !granted {
                    alertMessage = "Notification access is managed in System Settings.\n\nGo to: System Settings → Notifications → FocusOS"
                    showPermissionAlert = true
                }
            }
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func resetAllPermissions() {
        let alert = NSAlert()
        alert.messageText = "Reset All Permissions?"
        alert.informativeText = """
        This will reset the permission state for FocusOS. You'll need to:
        
        1. Go to System Settings → Privacy & Security
        2. Remove FocusOS from Microphone, Speech Recognition, and other permission lists
        3. Restart FocusOS
        4. Grant permissions again when prompted
        
        Would you like to open System Settings now?
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Open System Settings to Privacy & Security
            openSystemSettings()
            
            // Show instructions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                alertMessage = """
                To fully reset permissions:
                
                1. In System Settings → Privacy & Security
                2. Click on Microphone, Speech Recognition, and Notifications
                3. Find and remove FocusOS from each list (if present)
                4. Restart FocusOS
                5. Re-grant permissions when prompted
                
                The app will now ask for permissions again.
                """
                showPermissionAlert = true
            }
        }
    }
}

// MARK: - Permission Row Component
struct PermissionRow: View {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    let status: PermissionStatus
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                PermissionStatusBadge(status: status)
                
                if status != .authorized {
                    Button(action: onToggle) {
                        Text("Enable")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Status Badge
struct PermissionStatusBadge: View {
    let status: PermissionStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption)
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .cornerRadius(6)
    }
}

// MARK: - Permission Status Enum
enum PermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
    
    var displayName: String {
        switch self {
        case .notDetermined: return "Not Set"
        case .authorized: return "Granted"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        }
    }
    
    var icon: String {
        switch self {
        case .notDetermined: return "questionmark.circle.fill"
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .restricted: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .notDetermined: return .gray
        case .authorized: return .kosmicGreen
        case .denied: return .red
        case .restricted: return .orange
        }
    }
    
    init(from speechStatus: SFSpeechRecognizerAuthorizationStatus) {
        switch speechStatus {
        case .notDetermined: self = .notDetermined
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        @unknown default: self = .notDetermined
        }
    }
    
    init(from notificationStatus: UNAuthorizationStatus) {
        switch notificationStatus {
        case .notDetermined: self = .notDetermined
        case .authorized, .provisional, .ephemeral: self = .authorized
        case .denied: self = .denied
        @unknown default: self = .notDetermined
        }
    }
}

#Preview {
    PermissionsPrivacySection()
        .padding()
        .frame(width: 600)
}

