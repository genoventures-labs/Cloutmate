//
//  NotionService.swift
//  FocusOS
//
//  Notion OAuth 2.0 authentication and NotionSwift API client wrapper
//

import Foundation
import os.log
import AuthenticationServices
import NotionSwift
import Combine

enum NotionAPIError: Error {
    case authenticationFailed
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case tokenExpired
    case rateLimitExceeded
}
    
struct NotionTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let botId: String?
    let workspaceName: String?
    let workspaceIcon: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case botId = "bot_id"
        case workspaceName = "workspace_name"
        case workspaceIcon = "workspace_icon"
    }
}

final class NotionService {
    static let shared = NotionService()
    
    private let baseURL = "https://api.notion.com/v1"
    private let oauthBaseURL = "https://api.notion.com/v1/oauth"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Configuration
    
    var oauthClientId: String {
        // Check environment first (for development)
        if let envID = ProcessInfo.processInfo.environment["NotionOAuthClientId"], !envID.isEmpty {
            os_log("Using NotionOAuthClientId from environment variable", log: .default, type: .info)
            return envID
        }
        
        // Load from Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let id = plist["NotionOAuthClientId"] as? String, !id.isEmpty {
            os_log("NotionOAuthClientId loaded from Config.plist", log: .default, type: .info)
            return id
        }
        
        os_log("NotionOAuthClientId not found in Config.plist or environment variable", log: .default, type: .error)
        return ""
    }
    
    var oauthClientSecret: String {
        // Check environment first (for development)
        if let envSecret = ProcessInfo.processInfo.environment["NotionOAuthClientSecret"], !envSecret.isEmpty {
            os_log("Using NotionOAuthClientSecret from environment variable", log: .default, type: .info)
            return envSecret
        }
        
        // Load from Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let secret = plist["NotionOAuthClientSecret"] as? String, !secret.isEmpty {
            os_log("NotionOAuthClientSecret loaded from Config.plist", log: .default, type: .info)
            return secret
        }
        
        os_log("NotionOAuthClientSecret not found in Config.plist or environment variable", log: .default, type: .error)
        return ""
    }
    
    var redirectURI: String {
        return "https://oauth.kosmicapps.com/auth/callback"
    }
    
    // MARK: - OAuth Flow
    
    func getOAuthURL() -> URL? {
        guard !oauthClientId.isEmpty else {
            Logger(subsystem: "com.kosmicapps.FocusOS", category: "NotionService").error("NotionOAuthClientId is empty. Add NotionOAuthClientId to Config.plist or set NotionOAuthClientId environment variable.")
            return nil
        }
        
        guard !oauthClientSecret.isEmpty else {
            Logger(subsystem: "com.kosmicapps.FocusOS", category: "NotionService").error("NotionOAuthClientSecret is empty. Add NotionOAuthClientSecret to Config.plist or set NotionOAuthClientSecret environment variable.")
            return nil
        }
        
        let scopes = "read"
        let state = "notion:focusos_notion_\(UUID().uuidString.prefix(8))"
        
        // URL encode the redirect URI
        let encodedRedirectURI = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI
        
        let urlString = "https://api.notion.com/v1/oauth/authorize?" +
            "client_id=\(oauthClientId)&" +
            "redirect_uri=\(encodedRedirectURI)&" +
            "response_type=code&" +
            "owner=user&" +
            "state=\(state)"
        
        Logger(subsystem: "com.kosmicapps.FocusOS", category: "NotionService").info("Notion OAuth URL generated")
        
        return URL(string: urlString)
    }
    
    func exchangeCodeForToken(_ code: String) async throws -> NotionTokenResponse {
        let urlString = "https://api.notion.com/v1/oauth/token"
        
        guard let url = URL(string: urlString) else {
            throw NotionAPIError.invalidResponse
        }
        
        // URL encode the redirect URI
        let encodedRedirectURI = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI
        
        let body: [String: Any] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": encodedRedirectURI
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Basic auth with client_id:client_secret
        let credentials = "\(oauthClientId):\(oauthClientSecret)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw NotionAPIError.authenticationFailed
        }
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
        let (data, response) = try await session.data(for: request)
        
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NotionAPIError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 429 {
                    throw NotionAPIError.rateLimitExceeded
                }
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NotionAPIError.apiError(errorMessage)
        }
        
        let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(NotionTokenResponse.self, from: data)
            
            Logger(subsystem: "com.kosmicapps.FocusOS", category: "NotionService").info("Token exchange successful")
            return tokenResponse
        } catch {
            if error is NotionAPIError {
                throw error
            }
            throw NotionAPIError.networkError(error)
        }
    }
    
    // MARK: - NotionSwift Client
    
    /// Create a NotionSwift client instance
    func getClient(accessToken: String) -> NotionClient {
        let accessKeyProvider = StringAccessKeyProvider(accessKey: accessToken)
        return NotionClient(accessKeyProvider: accessKeyProvider)
    }
    
    /// Convert a Publisher to async/await
    @available(iOS 13.0, macOS 10.15, *)
    private func awaitPublisher<T>(_ publisher: AnyPublisher<T, NotionClientError>) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = publisher
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
    
    // MARK: - API Client Methods (using NotionSwift)
    
    /// Fetch all databases using NotionSwift
    @available(iOS 13.0, macOS 10.15, *)
    func getDatabases(accessToken: String) async throws -> [Database] {
        let client = getClient(accessToken: accessToken)
        
        // Search for all databases
        let searchRequest = SearchRequest(
            query: nil,
            sort: nil,
            filter: .database
        )
        
        let response = try await awaitPublisher(client.search(request: searchRequest))
        
        // Extract databases from results
        var databases: [Database] = []
        for result in response.results {
            if case .database(let database) = result {
                databases.append(database)
            }
        }
        
        return databases
    }
    
    /// Fetch pages from a database using NotionSwift
    @available(iOS 13.0, macOS 10.15, *)
    func getPages(databaseId: String, accessToken: String) async throws -> [Page] {
        let client = getClient(accessToken: accessToken)
        
        // Convert string ID to Database.Identifier (UUIDv4 is String)
        let dbIdentifier = Database.Identifier(databaseId)
        
        var allPages: [Page] = []
        var nextCursor: String? = nil
        
        repeat {
            // Create query params with pagination
            let params = DatabaseQueryParams(
                filter: nil,
                sorts: nil,
                startCursor: nextCursor,
                pageSize: Int32(100)
            )
            
            let response = try await awaitPublisher(client.databaseQuery(
                databaseId: dbIdentifier,
                params: params
            ))
            
            allPages.append(contentsOf: response.results)
            nextCursor = response.nextCursor
        } while nextCursor != nil
        
        return allPages
    }
    
    /// Fetch a single page using NotionSwift
    @available(iOS 13.0, macOS 10.15, *)
    func getPage(pageId: String, accessToken: String) async throws -> Page {
        let client = getClient(accessToken: accessToken)
        
        // Convert string ID to Page.Identifier (UUIDv4 is String)
        let pageIdentifier = Page.Identifier(pageId)
        
        return try await awaitPublisher(client.page(pageId: pageIdentifier))
    }
    
    /// Fetch blocks from a page using NotionSwift
    @available(iOS 13.0, macOS 10.15, *)
    func getBlocks(pageId: String, accessToken: String) async throws -> [ReadBlock] {
        let client = getClient(accessToken: accessToken)
        
        // Convert string ID to Block.Identifier (UUIDv4 is String)
        let blockIdentifier = Block.Identifier(pageId)
        
        var allBlocks: [ReadBlock] = []
        var nextCursor: String? = nil
        
        repeat {
            // Create query params with pagination
            let params = BaseQueryParams(
                startCursor: nextCursor,
                pageSize: Int32(100)
            )
        
            let response = try await awaitPublisher(client.blockChildren(
                blockId: blockIdentifier,
                params: params
            ))
            
            allBlocks.append(contentsOf: response.results)
            nextCursor = response.nextCursor
        } while nextCursor != nil
        
        return allBlocks
    }
}

