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
import CloutmateShared

struct AccountsSection: View {
    @Environment(\.modelContext) private var modelContext
    let accounts: [PlatformAccount]
    
    @State private var isAuthenticating = false
    @State private var pendingFacebookPages: [FacebookPagesResponse.FacebookPage]? = nil
    @State private var userAccessToken: String = ""
    @State private var showingAllConnectedMessage = false
    
    // Token caching helper
    private func cacheUserAccessToken(_ token: String) {
        let cached = CachedToken(token: token, timestamp: Date())
        if let data = try? JSONEncoder().encode(cached) {
            try? KeychainService.shared.storeToken(String(data: data, encoding: .utf8) ?? "", forAccount: "facebook_user_token_data")
        }
    }
    
    private func getCachedUserAccessToken() -> String? {
        guard let dataString = try? KeychainService.shared.getToken(forAccount: "facebook_user_token_data"),
              let data = dataString.data(using: .utf8),
              let cached = try? JSONDecoder().decode(CachedToken.self, from: data),
              !cached.isExpired else {
            return nil
        }
        return cached.token
    }
    
    private func getConnectedFacebookPageIDs() -> Set<String> {
        let descriptor = FetchDescriptor<PlatformAccount>(
            predicate: #Predicate { $0.platform == "facebook" }
        )
        let accounts = (try? modelContext.fetch(descriptor)) ?? []
        return Set(accounts.map { $0.accountID })
    }
    
    private func hasValidToken(for platform: Platform) -> Bool {
        let key = "\(platform.rawValue)_access_token"
        if let _ = try? KeychainService.shared.getToken(forAccount: key) {
            return true
        }
        return false
    }
    
    private struct CachedToken: Codable {
        let token: String
        let timestamp: Date
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > (60 * 24 * 60 * 60)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Existing accounts
            if accounts.isEmpty {
                // Empty state placeholder
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        )
                    
                    Text("No accounts connected")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(8)
            } else {
                // Group accounts by platform
                let facebookAccounts = accounts.filter { $0.platform == "facebook" }
                let threadsAccounts = accounts.filter { $0.platform == "threads" }
                
                VStack(spacing: 16) {
                    // Facebook accounts
                    if !facebookAccounts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                    .foregroundColor(.kosmicBlue)
                                Text("Facebook")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            ForEach(facebookAccounts) { account in
                                facebookAccountCard(account)
                            }
                        }
                    }
                    
                    // Threads accounts
                    if !threadsAccounts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .foregroundColor(.kosmicPurple)
                                Text("Threads")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            ForEach(threadsAccounts) { account in
                                threadsAccountCard(account)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Add account buttons
            HStack(spacing: 12) {
                PlatformConnectButton(
                    platform: .threads,
                    action: { 
                        // Check if already has a valid token
                        if let _ = try? KeychainService.shared.getToken(forAccount: "threads_access_token") {
                            // Token exists, skip OAuth
                            print("Threads token found, skipping OAuth")
                            return
                        }
                        authenticatePlatform(.threads)
                    },
                    isDisabled: isAuthenticating || hasValidToken(for: .threads)
                )
                
                PlatformConnectButton(
                    platform: .facebook,
                    action: { 
                        // Check if already has a valid user token
                        if let cachedToken = getCachedUserAccessToken() {
                            // User token exists, show pages directly
				_Concurrency.Task {
                                do {
                                    let pages = try await MetaAPIService.shared.getFacebookPages(accessToken: cachedToken)
                                    let connectedPageIDs = getConnectedFacebookPageIDs()
                                    let availablePages = pages.data.filter { !connectedPageIDs.contains($0.id) }
                                    
                                    await MainActor.run {
                                        if availablePages.isEmpty {
                                            print("All Facebook pages already connected")
                                        } else {
                                            pendingFacebookPages = availablePages
                                        }
                                    }
                                } catch {
                                    // Fall through to OAuth
                                    authenticatePlatform(.facebook)
                                }
                            }
                            return
                        }
                        authenticatePlatform(.facebook)
                    },
                    isDisabled: isAuthenticating
                )
            }
            
            // Inline page selection
            if let pages = pendingFacebookPages {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Select a Facebook Page")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Cancel") {
                            pendingFacebookPages = nil
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    if pages.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.secondary)
                            Text("All pages already connected — nothing to add.")
                                .foregroundColor(.secondary)
                                .font(.body)
                        }
                        .padding()
                        .transition(.opacity)
                    }
                    
                    ForEach(pages, id: \.id) { page in
                        Button(action: {
				_Concurrency.Task {
                                await connectSelectedPage(page)
                            }
                        }) {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: page.picture?.data.url ?? "")) { phase in
                                    switch phase {
                                    case .empty:
                                        Circle()
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Image(systemName: "person.circle.fill")
                                                    .foregroundColor(.secondary)
                                            )
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    case .failure:
                                        Circle()
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Image(systemName: "person.circle.fill")
                                                    .foregroundColor(.secondary)
                                            )
                                    @unknown default:
                                        Circle()
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(width: 40, height: 40)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(page.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    if let category = page.category {
                                        Text(category)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: pendingFacebookPages != nil)
    }
    
    // MARK: - Account Card Views
    
    private func facebookAccountCard(_ account: PlatformAccount) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: account.profileImageURL ?? "")) { phase in
                switch phase {
                case .empty:
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.secondary)
                        )
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                case .failure:
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.secondary)
                        )
                @unknown default:
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 40, height: 40)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.kosmicGreen)
                        .font(.caption)
                    Text(account.displayName ?? account.username)
                        .font(.body)
                    Spacer()
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Button("Change") {
                        // Use cached token if available
                        if let cachedToken = getCachedUserAccessToken() {
				_Concurrency.Task {
                                do {
                                    let pages = try await MetaAPIService.shared.getFacebookPages(accessToken: cachedToken)
                                    let connectedIDs = getConnectedFacebookPageIDs()
                                    let availablePages = pages.data.filter { !connectedIDs.contains($0.id) }
                                    
                                    await MainActor.run {
                                        if availablePages.isEmpty && !pages.data.isEmpty {
                                            showingAllConnectedMessage = true
				_Concurrency.Task {
                                                try? await _Concurrency.Task.sleep(for: .seconds(3))
                                                showingAllConnectedMessage = false
                                            }
                                        } else {
                                            pendingFacebookPages = availablePages
                                        }
                                    }
                                } catch {
                                    // Token expired, do OAuth
                                    authenticatePlatform(.facebook)
                                }
                            }
                        } else {
                            // No cached token, do OAuth
                            authenticatePlatform(.facebook)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(Color.accentColor.opacity(0.8))
                    
                    Button("Disconnect") {
                        removeAccount(account)
                    }
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: account.accountID)
    }
    
    private func threadsAccountCard(_ account: PlatformAccount) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.kosmicPurple)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.kosmicGreen)
                        .font(.caption)
                    Text(account.displayName ?? account.username)
                        .font(.body)
                    Spacer()
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("@\(account.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Disconnect") {
                    removeAccount(account)
                }
                .font(.caption)
                .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: account.accountID)
    }
    
    private func authenticatePlatform(_ platform: Platform) {
        isAuthenticating = true
        
				_Concurrency.Task {
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
                    // For Facebook, fetch pages and show selection UI
                    let pagesResponse = try await MetaAPIService.shared.getFacebookPages(accessToken: tokenResponse.accessToken)
                    
                    guard !pagesResponse.data.isEmpty else {
                        throw MetaAPIError.authenticationFailed
                    }
                    
                    // Set pending pages for inline selection
                    userAccessToken = tokenResponse.accessToken
                    
                    // Cache the user access token
                    cacheUserAccessToken(tokenResponse.accessToken)
                    
                    // Filter out already-connected pages
                    let connectedPageIDs = getConnectedFacebookPageIDs()
                    let availablePages = pagesResponse.data.filter { page in
                        !connectedPageIDs.contains(page.id)
                    }
                    
                    print("🔍 DEBUG: About to show page selection with \(availablePages.count) available pages (out of \(pagesResponse.data.count) total)")
                    print("🔍 DEBUG: Connected page IDs: \(connectedPageIDs)")
                    
                    DispatchQueue.main.async {
                        if availablePages.isEmpty && !pagesResponse.data.isEmpty {
                            showingAllConnectedMessage = true
                            // Hide message after 3 seconds
				_Concurrency.Task {
                                try? await _Concurrency.Task.sleep(for: .seconds(3))
                                showingAllConnectedMessage = false
                            }
                        } else {
                            pendingFacebookPages = availablePages
                        }
                    }
                    
                    isAuthenticating = false
                    return
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
                        case .metricsUnavailable(let message):
                            print("Meta metrics unavailable: \(message)")
                        }
                    }
                }
                
                isAuthenticating = false
            }
        }
    }
    
    private func connectSelectedPage(_ page: FacebookPagesResponse.FacebookPage) async {
        do {
            // Check if already connected
            let descriptor = FetchDescriptor<PlatformAccount>(
                predicate: #Predicate { $0.platform == "facebook" && $0.accountID == page.id }
            )
            
            if (try? modelContext.fetch(descriptor).first) != nil {
                Logger.accounts.info("Page already connected: \(page.name)")
                DispatchQueue.main.async {
                    pendingFacebookPages = nil
                }
                return
            }
            
            // Store the page access token (long-lived) with page-specific key
            try KeychainService.shared.storeToken(
                page.accessToken,
                forAccount: "facebook_page_\(page.id)_access_token"
            )
            
            // Save account to SwiftData with page info
            let account = PlatformAccount(
                platform: "facebook",
                accountID: page.id,
                username: page.name,
                displayName: page.name,
                profileImageURL: page.picture?.data.url
            )
            modelContext.insert(account)
            
            // Clear pending pages
            DispatchQueue.main.async {
                pendingFacebookPages = nil
            }
            
            Logger.accounts.info("Successfully connected Facebook page: \(page.name)")
        } catch {
            Logger.accounts.error("Failed to connect selected page: \(error.localizedDescription)")
        }
    }
    
    private func removeAccount(_ account: PlatformAccount) {
        // Remove token from Keychain
        if account.platform == "facebook" {
            // For Facebook, use page-specific key
            try? KeychainService.shared.deleteToken(forAccount: "facebook_page_\(account.accountID)_access_token")
        } else {
            try? KeychainService.shared.deleteToken(forAccount: "\(account.platform)_access_token")
        }
        
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
            try await _Concurrency.Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
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

