//
//  CloutmateHelperApp.swift
//  CloutmateHelper
//
//  Helper app entry point (publishing functionality removed)
//

import Foundation
import AppKit
import os.log

final class CloutmateHelperApp: NSObject, NSApplicationDelegate {
    private var listener: NSXPCListener?
    private var xpcDelegate: HelperXPCService?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        os_log("CloutmateHelper launching...", log: .default, type: .info)
        setupXPCListener()
        // BackgroundScheduler and InsightsPoller removed - no longer publishing to social media
    }
    
    private func setupXPCListener() {
        let listener = NSXPCListener.service()
        let delegate = HelperXPCService()
        listener.delegate = delegate
        listener.resume()
        
        self.listener = listener
        self.xpcDelegate = delegate
        
        os_log("XPC listener configured and resumed", log: .default, type: .info)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        os_log("CloutmateHelper terminating...", log: .default, type: .info)
    }
}
