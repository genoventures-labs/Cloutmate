//
//  AccountsSection.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import AuthenticationServices
import os.log

struct AccountsSection: View {
    @Environment(\.modelContext) private var modelContext
    let accounts: [PlatformAccount]
    
    @State private var isAuthenticating = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Existing accounts
            if accounts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No accounts connected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(accounts) { account in
                    HStack(spacing: 12) {
                        if let platform = account.accountPlatform {
                            Circle()
                                .fill(platform == .threads ? Color.purple : Color.blue)
                                .frame(width: 12, height: 12)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.displayName ?? account.username)
                                .font(.body)
                            Text("@\(account.username)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            removeAccount(account)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Divider()
            
            // Add account buttons
            VStack(spacing: 8) {
                Button(action: {
                    authenticatePlatform(.threads)
                }) {
                    Label("Connect Threads", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAuthenticating)
                
                Button(action: {
                    authenticatePlatform(.facebook)
                }) {
                    Label("Connect Facebook Page", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAuthenticating)
            }
        }
    }
    
    private func authenticatePlatform(_ platform: Platform) {
        isAuthenticating = true
        
        Task {
            do {
                // Get OAuth URL
                guard let oauthURL = MetaAPIService.shared.getOAuthURL(platform: platform) else {
                    Logger.accounts.error("Failed to generate OAuth URL. Check Meta API credentials.")
                    isAuthenticating = false
                    return
                }
                
                // Use ASWebAuthenticationSession with custom URL scheme
                // The OAuth server at https://oauth.cloutmate.app will redirect to cloutmate://oauth/callback
                print("Starting OAuth flow with ASWebAuthenticationSession...")
                let callbackURL = try await ASWebAuthenticationSession.start(
                    url: oauthURL,
                    callbackURLScheme: "cloutmate"
                )
                print("Received callback URL: \(callbackURL)")
                
                // DEBUG: Comprehensive logging of callback URL
                print("🔍 DEBUG: Full callback URL string: '\(callbackURL.absoluteString)'")
                
                if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) {
                    print("🔍 DEBUG: URLComponents breakdown:")
                    print("  - Scheme: '\(components.scheme ?? "nil")'")
                    print("  - Host: '\(components.host ?? "nil")'")
                    print("  - Path: '\(components.path)'")
                    print("  - Query: '\(components.query ?? "nil")'")
                    print("  - Fragment: '\(components.fragment ?? "nil")'")
                    
                    // Log all query items
                    if let queryItems = components.queryItems {
                        print("🔍 DEBUG: Query items:")
                        for item in queryItems {
                            print("  - \(item.name): '\(item.value ?? "nil")'")
                        }
                        
                        // Check state parameter for debugging
                        if let state = queryItems.first(where: { $0.name == "state" })?.value {
                            print("🔍 DEBUG: State parameter: '\(state)'")
                        }
                    } else {
                        print("🔍 DEBUG: No query items found")
                    }
                }
                
                // Extract code from callback
                // Handle both custom scheme and HTTPS localhost redirects
                var code: String?
                
                if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) {
                    // Try to get code from query parameters
                    code = components.queryItems?.first(where: { $0.name == "code" })?.value
                    print("🔍 DEBUG: Code from query parameters: '\(code ?? "nil")'")
                    
                    // If using HTTPS redirect, check for code in fragment or query
                    if code == nil || code?.isEmpty == true {
                        print("🔍 DEBUG: Code is nil or empty, checking fragment...")
                        // Parse from fragment (common in OAuth flows)
                        if let fragment = components.fragment,
                           let fragmentComponents = URLComponents(string: "?\(fragment)"),
                           let fragmentCode = fragmentComponents.queryItems?.first(where: { $0.name == "code" })?.value {
                            code = fragmentCode
                            print("🔍 DEBUG: Code found in fragment: '\(fragmentCode)'")
                        } else {
                            print("🔍 DEBUG: No code found in fragment either")
                        }
                    }
                    
                    // Check if code exists but is empty
                    if let extractedCode = code {
                        if extractedCode.isEmpty {
                            print("⚠️ WARNING: Code parameter exists but is empty!")
                        } else {
                            print("✅ SUCCESS: Code extracted successfully: '\(extractedCode.prefix(10))...'")
                        }
                    } else {
                        print("❌ ERROR: No code parameter found at all")
                    }
                }
                
                guard let extractedCode = code, !extractedCode.isEmpty else {
                    Logger.accounts.error("No authorization code found in callback URL or code is empty")
                    print("❌ ERROR: Cannot proceed without valid authorization code")
                    isAuthenticating = false
                    return
                }
                
                // Exchange code for token
                let tokenResponse = try await MetaAPIService.shared.exchangeCodeForToken(extractedCode, platform: platform)
                
                if platform == .facebook {
                    // For Facebook, fetch pages and store the page token
                    let pagesResponse = try await MetaAPIService.shared.getFacebookPages(accessToken: tokenResponse.accessToken)
                    
                    guard let firstPage = pagesResponse.data.first else {
                        throw MetaAPIError.authenticationFailed
                    }
                    
                    // Store the page access token (long-lived)
                    try KeychainService.shared.storeToken(
                        firstPage.accessToken,
                        forAccount: "\(platform.rawValue)_access_token"
                    )
                    
                    // Save account to SwiftData with page info
                    let account = PlatformAccount(
                        platform: platform.rawValue,
                        accountID: firstPage.id,
                        username: firstPage.name,
                        displayName: firstPage.name,
                        profileImageURL: firstPage.picture?.data.url
                    )
                    modelContext.insert(account)
                } else {
                    // For Threads, use regular account info
                    let accountInfo = try await MetaAPIService.shared.getAccountInfo(accessToken: tokenResponse.accessToken)
                    
                    // Store token in Keychain
                    try KeychainService.shared.storeToken(
                        tokenResponse.accessToken,
                        forAccount: "\(platform.rawValue)_access_token"
                    )
                    
                    // Save account to SwiftData
                    let account = PlatformAccount(
                        platform: platform.rawValue,
                        accountID: accountInfo.id,
                        username: accountInfo.username ?? "",
                        displayName: accountInfo.name,
                        profileImageURL: accountInfo.picture?.data.url
                    )
                    modelContext.insert(account)
                }
                
                isAuthenticating = false
            } catch {
                Logger.accounts.error("Authentication error: \(error.localizedDescription)")
                
                // Show user-friendly error
                if let nsError = error as NSError? {
                    if nsError.code == 1 {
                        // User cancelled - don't show error
                        print("User cancelled authentication")
                    } else {
                        print("Authentication failed: \(error.localizedDescription)")
                        print("Error details: \(nsError)")
                    }
                } else {
                    print("Authentication error: \(error)")
                    
                    // Log specific MetaAPIError details
                    if let metaError = error as? MetaAPIError {
                        switch metaError {
                        case .authenticationFailed:
                            print("Meta authentication failed")
                        case .invalidResponse:
                            print("Invalid response from Meta API")
                        case .networkError(let underlyingError):
                            print("Network error: \(underlyingError)")
                        case .apiError(let detail):
                            print("Meta API error: \(detail.message) (code: \(detail.code))")
                        }
                    }
                }
                
                isAuthenticating = false
            }
        }
    }
    
    private func removeAccount(_ account: PlatformAccount) {
        // Remove token from Keychain
        try? KeychainService.shared.deleteToken(forAccount: "\(account.platform)_access_token")
        
        // Remove account from SwiftData
        modelContext.delete(account)
    }
}

// Helper function for timeout
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "OAuth authentication timed out after \(seconds) seconds"])
        }
        
        guard let result = try await group.next() else {
            throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected timeout"])
        }
        
        group.cancelAll()
        return result
    }
}

#Preview {
    AccountsSection(accounts: [])
}

