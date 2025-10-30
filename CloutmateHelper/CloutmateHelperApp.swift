//
//  CloutmateHelperApp.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
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
        BackgroundScheduler.shared.start()
        InsightsPoller.shared.start()
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

