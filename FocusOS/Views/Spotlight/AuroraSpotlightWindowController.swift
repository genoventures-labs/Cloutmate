//
//  AuroraSpotlightWindowController.swift
//  FocusOS
//
//  Window controller for Aurora Spotlight quick access overlay
//

import SwiftUI
import SwiftData
import AppKit
import Combine
import OSLog

/// Custom NSPanel that can become a key window for keyboard input
class AuroraSpotlightPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
}

class AuroraSpotlightWindowController: ObservableObject {
    static let shared = AuroraSpotlightWindowController()
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FocusOS", category: "AuroraSpotlight")
    
    @Published var isPresented = false
    
    private var contentWindow: NSWindow?
    private var backdropWindow: NSWindow?
    private var backdropGestureRecognizer: NSClickGestureRecognizer?
    private var isClosing = false
    
    private init() {}
    
    func show() {
        // Reset closing flag if needed
        isClosing = false
        
        guard contentWindow == nil else {
            contentWindow?.makeKeyAndOrderFront(nil)
            backdropWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create backdrop window (full screen, non-draggable, fixed position)
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let backdrop = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        backdrop.level = .floating
        backdrop.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backdrop.hidesOnDeactivate = false
        backdrop.backgroundColor = .black.withAlphaComponent(0.45)
        backdrop.isOpaque = false
        // Backdrop should receive clicks (for closing), but not interfere with content panel dragging
        backdrop.ignoresMouseEvents = false
        backdrop.isMovable = false
        
        // Backdrop view - just a clickable overlay
        let backdropView = NSView(frame: screenFrame)
        backdropView.wantsLayer = true
        backdropView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
        
        let tapGesture = NSClickGestureRecognizer(target: self, action: #selector(backdropTapped))
        tapGesture.delaysPrimaryMouseButtonEvents = false
        backdropView.addGestureRecognizer(tapGesture)
        self.backdropGestureRecognizer = tapGesture // Store reference for cleanup
        
        backdrop.contentView = backdropView
        
        // Create content panel (draggable, smaller)
        let panel = AuroraSpotlightPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        // Use a dark background to match the content and prevent backdrop showing through
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.9)
        panel.hasShadow = true
        panel.isOpaque = false
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false
        
        // Get the main app's model container
        let container = FocusOSApp.sharedModelContainer
        
        // Get GlassColorSystem from active instance or create new one
        // Ensure we retain a strong reference to prevent deallocation
        let glassColorSystem = GlassColorSystem.active ?? GlassColorSystem()
        
        // Host SwiftUI view with shared context and environment objects (content only, no backdrop)
        // Store strong reference to prevent deallocation
        let contentView = AuroraSpotlightContentView()
        let hostingView = NSHostingView(
            rootView: contentView
                .modelContainer(container)
                .environmentObject(glassColorSystem)
        )
        hostingView.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 600, height: 400)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.contentView?.wantsLayer = true
        
        // Add rounded corner mask to prevent backdrop showing through corners
        if let layer = panel.contentView?.layer {
            layer.cornerRadius = 16
            layer.masksToBounds = true
        }
        
        // Center content panel relative to the main window
        if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isMainWindow }) {
            let mainFrame = mainWindow.frame
            let panelSize = panel.frame.size
            let centerX = mainFrame.midX - panelSize.width / 2
            let centerY = mainFrame.midY - panelSize.height / 2
            panel.setFrameOrigin(NSPoint(x: centerX, y: centerY))
        } else {
            panel.center()
        }
        
        self.contentWindow = panel
        self.backdropWindow = backdrop
        isPresented = true
        
        // Show backdrop first (so it's behind), then content on top
        backdrop.orderFront(nil)  // Don't make key - only show
        panel.makeKeyAndOrderFront(nil)
        
        // Ensure content panel is always above backdrop (both floating, but panel ordered last)
        panel.level = .floating
        backdrop.level = .floating
        
        NSApp.activate(ignoringOtherApps: true)
        
        // Ensure the panel becomes key window for keyboard input
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let panel = self.contentWindow,
                  panel.isVisible else { return }
            panel.makeKey()
        }
    }
    
    @objc private func backdropTapped() {
        close()
    }
    
    func close() {
        // Prevent multiple simultaneous closes
        guard !isClosing else { return }
        isClosing = true
        
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.close()
            }
            return
        }
        
        // Remove gesture recognizer before closing to prevent retain cycles
        if let backdropView = backdropWindow?.contentView,
           let gesture = backdropGestureRecognizer {
            backdropView.removeGestureRecognizer(gesture)
        }
        backdropGestureRecognizer = nil
        
        // Resign key window status before closing to stop event monitoring
        if let panel = contentWindow as? AuroraSpotlightPanel {
            panel.resignKey()
        }
        contentWindow?.resignKey()
        
        // Close windows safely - this will trigger onDisappear in the view
        if let window = contentWindow {
            window.close()
        }
        if let window = backdropWindow {
            window.close()
        }
        
        // Clear references after a delay to ensure windows are fully closed
        // and all event monitors/observers have been cleaned up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.contentWindow = nil
            self?.backdropWindow = nil
            self?.isPresented = false
            self?.isClosing = false
        }
    }
    
    func toggle() {
        if contentWindow == nil || !isPresented {
            show()
        } else {
            close()
        }
    }
}

