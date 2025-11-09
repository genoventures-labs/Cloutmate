//
//  WebSearchService.swift
//  Cloutmate
//
//  Web search service using DuckDuckGo HTML search results
//

import Foundation

actor WebSearchService {
    static let shared = WebSearchService()
    
    private init() {}
    
    /// Search the web using DuckDuckGo HTML search
    /// This performs actual web searches and returns real results
    func searchWeb(query: String) async throws -> WebSearchResult {
        // Use DuckDuckGo HTML search endpoint
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)") else {
            throw WebSearchError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0 // 10 second timeout
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WebSearchError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw WebSearchError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            // Parse HTML response
            guard let html = String(data: data, encoding: .utf8) else {
                throw WebSearchError.invalidResponse
            }
            
            // Extract search results from HTML
            let results = parseDuckDuckGoResults(html: html)
            
            // If no results found, return empty result instead of throwing error
            // This allows Aurora to continue responding even if search returns nothing
            if results.isEmpty {
                return WebSearchResult(
                    query: query,
                    results: [],
                    summary: nil
                )
            }
            
            // Generate summary from results
            let summary = generateSummary(from: results, query: query)
            
            return WebSearchResult(
                query: query,
                results: results,
                summary: summary
            )
        } catch {
            // If search fails, throw error but don't crash
            if error is WebSearchError {
                throw error
            } else {
                throw WebSearchError.apiError(error.localizedDescription)
            }
        }
    }
    
    /// Parse DuckDuckGo HTML search results
    private func parseDuckDuckGoResults(html: String) -> [WebSearchItem] {
        var results: [WebSearchItem] = []
        
        // DuckDuckGo HTML structure can vary, so we'll use multiple patterns
        // Try to find result containers - they typically have links with class containing "result"
        
        // Pattern 1: Look for links with result classes
        let linkPattern = #"<a[^>]*class="[^"]*result[^"]*"[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#
        
        if let regex = try? NSRegularExpression(pattern: linkPattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            
            var seenURLs = Set<String>()
            
            for match in matches.prefix(10) { // Get more matches, then filter
                let url = (html as NSString).substring(with: match.range(at: 1))
                let titleHTML = (html as NSString).substring(with: match.range(at: 2))
                let title = stripHTML(from: titleHTML)
                
                // Skip if we've seen this URL or if it's not a valid web URL
                guard !seenURLs.contains(url),
                      url.hasPrefix("http"),
                      !title.isEmpty else {
                    continue
                }
                
                seenURLs.insert(url)
                
                // Try to find snippet near this result
                let snippet = findSnippetNearMatch(match: match, html: html)
                
                results.append(WebSearchItem(
                    title: title,
                    url: url,
                    snippet: snippet.isEmpty ? nil : snippet
                ))
                
                if results.count >= 5 {
                    break
                }
            }
        }
        
        // If we didn't get results, try alternative pattern
        if results.isEmpty {
            // Pattern 2: Look for any links with href containing http/https
            let fallbackPattern = #"<a[^>]*href="(https?://[^"]+)"[^>]*>(.*?)</a>"#
            
            if let regex = try? NSRegularExpression(pattern: fallbackPattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(html.startIndex..<html.endIndex, in: html)
                let matches = regex.matches(in: html, options: [], range: range)
                
                var seenURLs = Set<String>()
                
                for match in matches.prefix(10) {
                    let url = (html as NSString).substring(with: match.range(at: 1))
                    let titleHTML = (html as NSString).substring(with: match.range(at: 2))
                    let title = stripHTML(from: titleHTML)
                    
                    // Skip DuckDuckGo internal links and duplicates
                    guard !seenURLs.contains(url),
                          !url.contains("duckduckgo.com"),
                          url.hasPrefix("http"),
                          title.count > 5, // Filter out very short titles
                          title.count < 200 else { // Filter out very long titles
                        continue
                    }
                    
                    seenURLs.insert(url)
                    
                    results.append(WebSearchItem(
                        title: title,
                        url: url,
                        snippet: nil
                    ))
                    
                    if results.count >= 5 {
                        break
                    }
                }
            }
        }
        
        return results
    }
    
    /// Find snippet text near a match
    private func findSnippetNearMatch(match: NSTextCheckingResult, html: String) -> String {
        // Look for snippet patterns near the match
        let matchEnd = match.range.upperBound
        let searchStart = min(matchEnd, html.count)
        let searchEnd = min(searchStart + 500, html.count) // Search 500 chars after match
        
        guard searchStart < html.count else { return "" }
        
        let searchRange = NSRange(location: searchStart, length: searchEnd - searchStart)
        guard searchRange.location + searchRange.length <= html.count else { return "" }
        
        let searchText = (html as NSString).substring(with: searchRange)
        
        // Look for snippet patterns
        let snippetPatterns = [
            #"<a[^>]*class="[^"]*snippet[^"]*"[^>]*>(.*?)</a>"#,
            #"<span[^>]*class="[^"]*snippet[^"]*"[^>]*>(.*?)</span>"#,
            #"<p[^>]*class="[^"]*snippet[^"]*"[^>]*>(.*?)</p>"#
        ]
        
        for pattern in snippetPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(searchText.startIndex..<searchText.endIndex, in: searchText)
                if let snippetMatch = regex.firstMatch(in: searchText, options: [], range: range) {
                    let snippetHTML = (searchText as NSString).substring(with: snippetMatch.range(at: 1))
                    let snippet = stripHTML(from: snippetHTML)
                    if snippet.count > 20 && snippet.count < 300 {
                        return snippet
                    }
                }
            }
        }
        
        return ""
    }
    
    /// Strip HTML tags from string
    private func stripHTML(from html: String) -> String {
        var text = html
        // Remove HTML tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }
        // Decode HTML entities
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Generate a summary from search results
    private func generateSummary(from results: [WebSearchItem], query: String) -> String? {
        guard !results.isEmpty else { return nil }
        
        // Create a summary from the top results
        let topResults = results.prefix(3)
        var summaryParts: [String] = []
        
        for result in topResults {
            if let snippet = result.snippet, !snippet.isEmpty {
                summaryParts.append(snippet)
            } else {
                summaryParts.append(result.title)
            }
        }
        
        return summaryParts.joined(separator: " ")
    }
}

struct WebSearchResult {
    let query: String
    let results: [WebSearchItem]
    let summary: String?
    
    /// Calculate confidence score based on result quality
    var confidence: Double {
        guard !results.isEmpty else { return 0.0 }
        
        var score: Double = 0.0
        
        // Base score from number of results (more results = higher confidence)
        score += min(Double(results.count) / 5.0, 1.0) * 0.4
        
        // Quality score from snippets (results with snippets are better)
        let resultsWithSnippets = Double(results.filter { $0.snippet != nil && !$0.snippet!.isEmpty }.count)
        score += (resultsWithSnippets / Double(results.count)) * 0.3
        
        // URL quality (https URLs are better)
        let httpsResults = Double(results.filter { $0.url.hasPrefix("https://") }.count)
        score += (httpsResults / Double(results.count)) * 0.2
        
        // Title quality (longer, more descriptive titles are better)
        let avgTitleLength = results.map { Double($0.title.count) }.reduce(0, +) / Double(results.count)
        score += min(avgTitleLength / 50.0, 1.0) * 0.1
        
        return min(score, 1.0)
    }
}

// Struct for storing web search results in AIMessage
struct WebSearchResults: Codable {
    let query: String
    let results: [WebSearchItem]
    let summary: String?
    let confidence: Double
    let timestamp: Date
    
    init(from searchResult: WebSearchResult) {
        self.query = searchResult.query
        self.results = searchResult.results
        self.summary = searchResult.summary
        self.confidence = searchResult.confidence
        self.timestamp = Date()
    }
}

struct WebSearchItem: Codable {
    let title: String
    let url: String
    let snippet: String?
}

enum WebSearchError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid search URL"
        case .invalidResponse:
            return "Invalid response from search service"
        case .apiError(let message):
            return "Search API error: \(message)"
        case .noResults:
            return "No search results found"
        }
    }
}
