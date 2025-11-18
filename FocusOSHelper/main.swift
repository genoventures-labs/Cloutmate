//
//  main.swift
//  FocusOSHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import AppKit

Task { @MainActor in
    // Create and configure the helper app
    let app = NSApplication.shared
    let delegate = FocusOSHelperApp()
    app.delegate = delegate
    
    // Run the application
    app.run()
}

// Keep the process alive
RunLoop.main.run()
