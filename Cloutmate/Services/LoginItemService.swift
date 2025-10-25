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
        Logger.xpc.info("Enabling login item: \(self.helperID)")
        
        if #available(macOS 13.0, *) {
            do {
                let service = SMAppService.loginItem(identifier: helperID)
                try service.register()
                return true
            } catch {
                Logger.xpc.error("Failed to register login item: \(error.localizedDescription)")
                return false
            }
        } else {
            return SMLoginItemSetEnabled(helperID as CFString, true)
        }
    }
    
    func disableLoginItem() -> Bool {
        Logger.xpc.info("Disabling login item: \(self.helperID)")
        
        if #available(macOS 13.0, *) {
            do {
                let service = SMAppService.loginItem(identifier: helperID)
                try service.unregister()
                return true
            } catch {
                Logger.xpc.error("Failed to unregister login item: \(error.localizedDescription)")
                return false
            }
        } else {
            return SMLoginItemSetEnabled(helperID as CFString, false)
        }
    }
    
    func isLoginItemEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            let service = SMAppService.loginItem(identifier: helperID)
            let status = service.status
            // Error 22 means the service isn't registered yet, which means it's disabled
            if status == .enabled {
                return true
            } else {
                // Not enabled or not found
                return false
            }
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

