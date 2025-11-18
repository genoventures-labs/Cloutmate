//
//  OAuthCallbackServer.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import Network

/// Server that listens for OAuth callbacks on localhost:8080
/// and returns an HTTP 302 redirect to our custom URL scheme
final class OAuthCallbackServer {
    static let shared = OAuthCallbackServer()
    
    private var listener: NWListener?
    private var continuation: CheckedContinuation<URL, Error>?
    
    private init() {}
    
    /// Start listening for OAuth callback and return the callback URL
    func startListening() async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            let port: NWEndpoint.Port = 8080
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            do {
                let listener = try NWListener(using: parameters, on: port)
                self.listener = listener
                
                listener.newConnectionHandler = { [weak self] connection in
                    guard let self = self else { return }
                    _Concurrency.Task {
                        await self.handleConnection(connection)
                    }
                }
                
                listener.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        print("✅ OAuth callback server started and ready on port 8080")
                    case .waiting(let error):
                        print("⚠️ Server waiting: \(error)")
                    case .failed(let error):
                        print("❌ Server failed: \(error)")
                        continuation.resume(throwing: error)
                    case .cancelled:
                        print("⏹️ Server cancelled")
                    default:
                        print("Server state: \(state)")
                    }
                }
                
                listener.start(queue: .global())
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func handleConnection(_ connection: NWConnection) async {
        connection.start(queue: .global())
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                self.continuation?.resume(throwing: error)
                self.stopListening()
                return
            }
            
            if let data = data, isComplete {
                if let httpString = String(data: data, encoding: .utf8) {
                    self.processHTTPRequest(httpString, connection: connection)
                }
            }
        }
    }
    
    private func processHTTPRequest(_ request: String, connection: NWConnection) {
        print("Received HTTP request:\n\(request)")
        
        // Parse the request to get the callback URL with code
        var callbackURL: URL?
        
        if let urlStart = request.range(of: "GET /oauth/callback") {
            // Extract query parameters
            let queryStart = request[urlStart.upperBound...].firstIndex(of: "?")
            if let queryStart = queryStart {
                let queryString = String(request[queryStart...].dropFirst())
                if let url = URL(string: "focusos://oauth/callback?\(queryString)") {
                    callbackURL = url
                    print("Parsed callback URL: \(url)")
                }
            }
        }
        
        // Send HTTP 200 response with message
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head><title>OAuth Success</title></head>
        <body>
            <h1>Authentication Successful!</h1>
            <p>You can close this window.</p>
            <script>window.close();</script>
        </body>
        </html>
        """
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: \(htmlContent.utf8.count)\r\nConnection: close\r\n\r\n\(htmlContent)"
        
        if let responseData = response.data(using: .utf8) {
            connection.send(content: responseData, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
        
        // Resume continuation with the callback URL
        if let callbackURL = callbackURL {
            continuation?.resume(returning: callbackURL)
        } else {
            continuation?.resume(throwing: NSError(
                domain: "OAuthCallbackServer",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse callback URL"]
            ))
        }
        
        stopListening()
    }
    
    func stopListening() {
        listener?.cancel()
        listener = nil
        continuation = nil
    }
}

