//
//  QuickCaptureWindow.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import AppKit
import Combine
import CloutmateShared

class QuickCaptureWindowController: ObservableObject {
    static let shared = QuickCaptureWindowController()
    
    @Published var isPresented = false
    
    private var window: NSWindow?
    
    private init() {}
    
    func show() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.title = "Quick Capture"
        
        // Get the main app's model container
        let _ = NSApplication.shared.delegate as? NSObject
        guard let container = try? ModelContainer(for: Schema([CloutmateShared.InboxItem.self, CloutmateShared.Task.self, CloutmateShared.Note.self, CloutmateShared.Post.self])) else {
            print("Failed to create model container for quick capture")
            return
        }
        
        // Host SwiftUI view with shared context
        let hostingView = NSHostingView(rootView: QuickCaptureView().modelContainer(container))
        panel.contentView = hostingView
        panel.center()
        
        self.window = panel
        isPresented = true
        
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func close() {
        window?.close()
        window = nil
        isPresented = false
    }
}

