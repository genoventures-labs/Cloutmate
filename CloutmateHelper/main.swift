//
//  main.swift
//  CloutmateHelper
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import AppKit

// Create and configure the helper app
let app = NSApplication.shared
let delegate = CloutmateHelperApp()
app.delegate = delegate

// Run the application
app.run()

