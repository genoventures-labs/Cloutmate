//
//  Logger.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import os.log

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    
    static let metaAPI = Logger(subsystem: subsystem, category: "MetaAPI")
    static let publishing = Logger(subsystem: subsystem, category: "Publishing")
    static let xpc = Logger(subsystem: subsystem, category: "XPC")
    static let keychain = Logger(subsystem: subsystem, category: "Keychain")
    static let insights = Logger(subsystem: subsystem, category: "Insights")
    static let accounts = Logger(subsystem: subsystem, category: "Accounts")
    static let notion = Logger(subsystem: subsystem, category: "Notion")
}

