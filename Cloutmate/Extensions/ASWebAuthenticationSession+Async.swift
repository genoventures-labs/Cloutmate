//
//  ASWebAuthenticationSession+Async.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import AuthenticationServices

extension ASWebAuthenticationSession {
    /// Presents an authentication session and returns the callback URL
    static func start(url: URL, callbackURLScheme: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackURLScheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "ASWebAuthenticationSession",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No callback URL received"]
                    ))
                }
            }
            
            session.presentationContextProvider = AuthenticationContextProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            
            if !session.start() {
                continuation.resume(throwing: NSError(
                    domain: "ASWebAuthenticationSession",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to start authentication session"]
                ))
            }
        }
    }
}

// Presentation context provider for macOS
final class AuthenticationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthenticationContextProvider()
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Find the key window (frontmost window)
        if let keyWindow = NSApplication.shared.keyWindow {
            return keyWindow
        }
        
        // Fall back to any window
        if let anyWindow = NSApplication.shared.windows.first {
            return anyWindow
        }
        
        // Last resort: find any window including dock status
        return NSApplication.shared.windows.first ?? NSApplication.shared.mainWindow ?? NSWindow()
    }
}

