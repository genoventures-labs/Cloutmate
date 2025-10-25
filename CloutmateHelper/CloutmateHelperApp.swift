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
        Logger.xpc.info("CloutmateHelper launching...")
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
        
        Logger.xpc.info("XPC listener configured and resumed")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Logger.xpc.info("CloutmateHelper terminating...")
    }
}

