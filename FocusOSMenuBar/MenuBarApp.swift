//
//  MenuBarApp.swift
//  FocusOSMenuBar
//

import SwiftUI
import SwiftData
import AppKit
import FocusOSShared

@main
struct FocusOSMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var glassColorSystem = GlassColorSystem()
    
    var sharedModelContainer: ModelContainer = {
        SharedDataManager.createSharedModelContainer()
    }()
    
    var body: some Scene {
        Settings {
            MenuBarPopoverView()
                .modelContainer(sharedModelContainer)
                .environmentObject(glassColorSystem)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarItem: NSStatusItem!
    private var popover: NSPopover!
    private var menu: NSMenu!
    private let glassColorSystem = GlassColorSystem()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create right-click menu
        setupMenu()
        
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        
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
            .environmentObject(glassColorSystem)
        
        let hostingController = NSHostingController(rootView: contentView)
        popover.contentViewController = hostingController
        
        NSApp.setActivationPolicy(.accessory)
        
        // Request notification permissions
        _Concurrency.Task {
            _ = await NotificationService.shared.requestPermission()
        }
    }
    
    func updateIcon() {
        statusBarItem.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "FocusOS")
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
        
        // Quit FocusOS
        let quitItem = NSMenuItem(title: "Quit FocusOS", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    func showMenu() {
        guard let button = statusBarItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 6), in: button)
    }
    
    @objc func openMainApp() {
        // Open main app using bundle identifier
        let bundleID = "com.kosmicapps.FocusOS"
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

