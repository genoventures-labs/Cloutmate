//
//  AuroraSpotlightWindowController.swift
//  Cloutmate
//
//  Window controller for Aurora Spotlight quick access overlay
//

import SwiftUI
import SwiftData
import AppKit
import Combine

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
    
    @Published var isPresented = false
    
    private var window: NSWindow?
    
    private init() {}
    
    func show() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let panel = AuroraSpotlightPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Keep it on top - use floating level which keeps it above normal windows
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Ensure it stays on top even when other windows are activated
        panel.hidesOnDeactivate = false
        
        // Make it draggable
        panel.isMovableByWindowBackground = true
        
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false
        
        // Get the main app's model container
        let container = CloutmateApp.sharedModelContainer
        
        // Host SwiftUI view with shared context
        let hostingView = NSHostingView(rootView: AuroraSpotlightView().modelContainer(container))
        hostingView.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 600, height: 500)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.contentView?.wantsLayer = true
        
        // Center relative to the main window instead of screen
        if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isMainWindow }) {
            let mainFrame = mainWindow.frame
            let panelSize = panel.frame.size
            let centerX = mainFrame.midX - panelSize.width / 2
            let centerY = mainFrame.midY - panelSize.height / 2
            panel.setFrameOrigin(NSPoint(x: centerX, y: centerY))
        } else {
            // Fallback to screen center if no main window
            panel.center()
        }
        
        self.window = panel
        isPresented = true
        
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Ensure the panel becomes key window for keyboard input
        DispatchQueue.main.async {
            panel.makeKey()
        }
    }
    
    func close() {
        window?.close()
        window = nil
        isPresented = false
    }
    
    func toggle() {
        if window == nil || !isPresented {
            show()
        } else {
            close()
        }
    }
}

