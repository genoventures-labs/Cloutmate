//
//  ScreenshotService.swift
//  FocusOS
//
//  Handles window listing and screenshot capture for Aurora chat.
//

import AppKit
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation
import ScreenCaptureKit

@MainActor
class ScreenshotService {
    static let shared = ScreenshotService()
    
    private init() {}
    
    struct WindowInfo: Identifiable, Sendable {
        let id: CGWindowID
        let title: String
        let appName: String
        let appIcon: NSImage?
        let bounds: CGRect
    }
    
    enum ScreenshotError: LocalizedError {
        case noWindowsFound
        case windowNotFound
        case captureFailed
        case permissionDenied
        
        var errorDescription: String? {
            switch self {
            case .noWindowsFound:
                return "No windows available for screenshot."
            case .windowNotFound:
                return "The selected window could not be found."
            case .captureFailed:
                return "Failed to capture the window screenshot."
            case .permissionDenied:
                return "Screen recording permission is required to take screenshots. Please grant permission in System Settings → Privacy & Security → Screen Recording."
            }
        }
        
        var isPermissionError: Bool {
            switch self {
            case .permissionDenied:
                return true
            default:
                return false
            }
        }
    }
    
    /// Get list of available windows for screenshot
    func getAvailableWindows() async throws -> [WindowInfo] {
        // ScreenCaptureKit will handle authorization automatically when we try to use it
        // For now, we'll use CGWindowListCopyWindowInfo which requires screen recording permission
        guard hasScreenRecordingPermission() else {
            throw ScreenshotError.permissionDenied
        }
        
        // Get all windows
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            throw ScreenshotError.noWindowsFound
        }
        
        var windows: [WindowInfo] = []
        var seenWindowIDs = Set<CGWindowID>()
        
        for windowDict in windowList {
            // Get window ID
            guard let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }
            
            // Skip if we've already seen this window
            guard !seenWindowIDs.contains(windowID) else {
                continue
            }
            seenWindowIDs.insert(windowID)
            
            // Get window layer - skip desktop, dock, and system windows
            if let layer = windowDict[kCGWindowLayer as String] as? Int {
                // Layer 0 = normal windows, negative = desktop/dock
                if layer != 0 {
                    continue
                }
            }
            
            // Get window bounds
            var bounds = CGRect.zero
            if let boundsDict = windowDict[kCGWindowBounds as String] as? [String: Any],
               let x = boundsDict["X"] as? CGFloat,
               let y = boundsDict["Y"] as? CGFloat,
               let width = boundsDict["Width"] as? CGFloat,
               let height = boundsDict["Height"] as? CGFloat {
                bounds = CGRect(x: x, y: y, width: width, height: height)
            }
            
            // Skip windows that are too small or off-screen
            if bounds.width < 100 || bounds.height < 100 {
                continue
            }
            
            // Get window title
            let title = windowDict[kCGWindowName as String] as? String ?? "Untitled Window"
            
            // Skip windows with no meaningful title
            if title.isEmpty || title == "Untitled Window" {
                // Still include if we can identify the app
            }
            
            // Get owner name (app name)
            let ownerName = windowDict[kCGWindowOwnerName as String] as? String ?? "Unknown App"
            
            // Skip system processes
            if ownerName == "WindowServer" || ownerName == "loginwindow" {
                continue
            }
            
            // Get app icon
            let appIcon = getAppIcon(for: ownerName)
            
            windows.append(WindowInfo(
                id: windowID,
                title: title,
                appName: ownerName,
                appIcon: appIcon,
                bounds: bounds
            ))
        }
        
        // Sort by app name, then by window title
        windows.sort { first, second in
            if first.appName != second.appName {
                return first.appName < second.appName
            }
            return first.title < second.title
        }
        
        guard !windows.isEmpty else {
            throw ScreenshotError.noWindowsFound
        }
        
        return windows
    }
    
    /// Capture screenshot of a specific window
    func captureWindow(_ windowID: CGWindowID) async throws -> NSImage {
        // Request screen recording permission if needed
        guard hasScreenRecordingPermission() else {
            throw ScreenshotError.permissionDenied
        }
        
        // Get window bounds first
        guard let windowList = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]],
              let windowDict = windowList.first,
              let boundsDict = windowDict[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat else {
            throw ScreenshotError.windowNotFound
        }
        
        let windowRect = CGRect(x: x, y: y, width: width, height: height)
        
        // Prefer ScreenCaptureKit on macOS 13+
        if #available(macOS 13.0, *) {
            // Find the SCWindow for the provided windowID
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                throw ScreenshotError.windowNotFound
            }

            // Configure a stream to capture this single window
            let config = SCStreamConfiguration()
            config.capturesAudio = false
            config.width = Int(scWindow.frame.width)
            config.height = Int(scWindow.frame.height)
            config.showsCursor = false
            config.queueDepth = 1

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)

            // A helper to receive one frame
            final class SingleFrameReceiver: NSObject, SCStreamOutput {
                var image: CGImage?
                let semaphore = DispatchSemaphore(value: 0)
                func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
                    guard outputType == .screen, let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                    let ciImage = CIImage(cvImageBuffer: pb)
                    let context = CIContext(options: nil)
                    if let cg = context.createCGImage(ciImage, from: ciImage.extent) {
                        self.image = cg
                        semaphore.signal()
                    }
                }
                func stream(_ stream: SCStream, didStopWithError error: Error) { semaphore.signal() }
            }

            let receiver = SingleFrameReceiver()
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            try stream.addStreamOutput(receiver, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))
            try await stream.startCapture()

            // Wait briefly for a frame
            _ = receiver.semaphore.wait(timeout: .now() + 1.0)
            try await stream.stopCapture()

            guard let finalImage = receiver.image else {
                throw ScreenshotError.captureFailed
            }

            // Convert CGImage to NSImage
            let size = NSSize(width: finalImage.width, height: finalImage.height)
            let nsImage = NSImage(size: size)
            nsImage.lockFocus()
            defer { nsImage.unlockFocus() }

            let context = NSGraphicsContext.current!
            context.imageInterpolation = .high
            context.shouldAntialias = true

            let rect = NSRect(origin: .zero, size: size)
            let cgContext = context.cgContext
            cgContext.draw(finalImage, in: rect)

            return nsImage
        } else {
            // Fallback for older systems is not supported anymore
            throw ScreenshotError.captureFailed
        }
    }
    
    // MARK: - Private Helpers
    
    private func hasScreenRecordingPermission() -> Bool {
        // This method is called from @MainActor context, so it's fine to be MainActor-isolated
        if #available(macOS 13.0, *) {
            // ScreenCaptureKit handles authorization automatically
            // We can't check synchronously, so we'll try to use it and let it fail gracefully
            // For a synchronous check, we'll assume permission might be available
            // The actual permission check happens when SCShareableContent is called
            return true
        } else {
            // Older macOS: Try to check permission by attempting a minimal window list operation
            // This is a best-effort check - actual permission will be verified when capturing
            if let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
                return !windowList.isEmpty
            }
            return false
        }
    }
    
    private func getAppIcon(for appName: String) -> NSImage? {
        // This method is called from @MainActor context, so it's fine to be MainActor-isolated
        // Try to find the app bundle and get its icon
        let workspace = NSWorkspace.shared
        
        // Try to find app by name
        if let appURL = workspace.urlForApplication(withBundleIdentifier: appName) {
            return workspace.icon(forFile: appURL.path)
        }
        
        // Try searching running applications
        let runningApps = workspace.runningApplications
        for app in runningApps {
            if let bundleName = app.localizedName, bundleName == appName {
                return app.icon
            }
            if let bundleID = app.bundleIdentifier, bundleID == appName {
                return app.icon
            }
        }
        
        // Fallback to generic app icon
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil)
    }
}
