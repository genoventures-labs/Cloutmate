//
//  MenuBarApp.swift
//  CloutmateMenuBar
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

@main
struct CloutmateMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        SharedDataManager.createSharedModelContainer()
    }()
    
    var body: some Scene {
        Settings {
            MenuBarPopoverView()
                .modelContainer(sharedModelContainer)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarItem: NSStatusItem!
    private var popover: NSPopover!
    private var currentIconState: IconState = .idle
    private var menu: NSMenu!
    
    enum IconState {
        case idle
        case posting
        case error
        
        var symbolName: String {
            switch self {
            case .idle: return "message.fill"
            case .posting: return "arrow.up.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create right-click menu
        setupMenu()
        
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon(.idle)
        
        if let button = statusBarItem.button {
            // Left click shows popover
            button.action = #selector(togglePopover)
            button.target = self
            // Right click shows menu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create popover with shared model container
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        
        let sharedModelContainer = SharedDataManager.createSharedModelContainer()
        let contentView = MenuBarPopoverView()
            .modelContainer(sharedModelContainer)
        
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        // Listen for notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePostingStatus(_:)),
            name: NSNotification.Name("PostStatusChanged"),
            object: nil
        )
        
        NSApp.setActivationPolicy(.accessory)
        
        // Request notification permissions
        Task {
            _ = await NotificationService.shared.requestPermission()
        }
    }
    
    func updateIcon(_ state: IconState) {
        currentIconState = state
        statusBarItem.button?.image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: "Cloutmate")
        
        // Add visual feedback for posting state
        if case .posting = state {
            // Animate the posting icon
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.updateIcon(.posting)
            }
        }
    }
    
    @objc func handlePostingStatus(_ notification: Notification) {
        guard let status = notification.userInfo?["status"] as? String else { return }
        
        switch status {
        case "publishing":
            updateIcon(.posting)
        case "published":
            updateIcon(.idle)
        case "failed":
            updateIcon(.error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.updateIcon(.idle)
            }
        default:
            updateIcon(.idle)
        }
    }
    
    @objc func togglePopover() {
        // Check if right-click event
        if let event = NSApplication.shared.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
            return
        }
        
        guard let button = statusBarItem.button else { return }
        
        if popover.isShown {
            popover.performClose(button)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    func setupMenu() {
        menu = NSMenu()
        
        // Open Main App
        let openAppItem = NSMenuItem(title: "Open Main App", action: #selector(openMainApp), keyEquivalent: "")
        openAppItem.target = self
        menu.addItem(openAppItem)
        
        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // Quit Cloutmate
        let quitItem = NSMenuItem(title: "Quit Cloutmate", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    func showMenu() {
        guard let button = statusBarItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 6), in: button)
    }
    
    @objc func openMainApp() {
        // Open main app using bundle identifier
        let bundleID = "com.kosmicapps.Cloutmate"
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

