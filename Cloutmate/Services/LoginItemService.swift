//
//  LoginItemService.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import ServiceManagement
import os.log

final class LoginItemService {
    static let shared = LoginItemService()
    
    private let helperID = "com.kosmicapps.Cloutmate.Helper"
    
    private init() {}
    
    func enableLoginItem() -> Bool {
        Logger.xpc.debug("Enabling login item: \(self.helperID)")
        
        if #available(macOS 13.0, *) {
            do {
                let service = SMAppService.loginItem(identifier: helperID)
                
                // Check if already registered
                if service.status == .enabled {
                    Logger.xpc.debug("Login item already enabled")
                    return true
                }
                
                try service.register()
                Logger.xpc.info("Successfully registered login item")
                return true
            } catch {
                // Note: Helper app may not be built yet in development
                // This is expected and will work once the app is properly built
                Logger.xpc.debug("Could not register login item (likely helper not built): \(error.localizedDescription)")
                return false
            }
        } else {
            let result = SMLoginItemSetEnabled(helperID as CFString, true)
            if result {
                Logger.xpc.info("Successfully enabled login item (legacy)")
            } else {
                Logger.xpc.debug("Could not enable login item (legacy)")
            }
            return result
        }
    }
    
    func disableLoginItem() -> Bool {
        Logger.xpc.debug("Disabling login item: \(self.helperID)")
        
        if #available(macOS 13.0, *) {
            do {
                let service = SMAppService.loginItem(identifier: helperID)
                
                // Check if not registered
                if service.status != .enabled {
                    Logger.xpc.debug("Login item not registered")
                    return true
                }
                
                try service.unregister()
                Logger.xpc.info("Successfully unregistered login item")
                return true
            } catch {
                // This may fail if the helper was never registered
                Logger.xpc.debug("Could not unregister login item: \(error.localizedDescription)")
                return false
            }
        } else {
            let result = SMLoginItemSetEnabled(helperID as CFString, false)
            if result {
                Logger.xpc.info("Successfully disabled login item (legacy)")
            } else {
                Logger.xpc.debug("Could not disable login item (legacy)")
            }
            return result
        }
    }
    
    func isLoginItemEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            let service = SMAppService.loginItem(identifier: helperID)
            let status = service.status
            
            // Status can be: .notFound (when not registered), .enabled, or .notApproved
            // Only return true if explicitly enabled
            return status == .enabled
        } else {
            guard let loginItems = SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: Any]] else {
                return false
            }
            
            return loginItems.contains { item in
                guard let label = item["Label"] as? String else { return false }
                return label == helperID
            }
        }
    }
}

