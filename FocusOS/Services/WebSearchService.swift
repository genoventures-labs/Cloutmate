//
//  WebSearchService.swift
//  FocusOS
//
//  Web search service using Ollama Cloud API
//

import Foundation

actor WebSearchService {
    static let shared = WebSearchService()
    
    private let ollamaWebSearchURL = "https://ollama.com/api/web_search"
    
    private init() {}
    
    /// Perform deep research with multiple related searches
    /// Generates multiple search queries from the original and aggregates results
    /// - Parameters:
    ///   - query: The original search query
    ///   - apiKey: Ollama Cloud API key
    ///   - maxResultsPerQuery: Maximum results per query (default 10, max 10)
    ///   - onProgressUpdate: Optional callback for progress updates (query, resultCount)
    func deepResearch(query: String, apiKey: String, maxResultsPerQuery: Int = 10, onProgressUpdate: ((String, Int) -> Void)? = nil) async throws -> WebSearchResult {
        // Generate multiple related search queries for comprehensive research
        let searchQueries = generateResearchQueries(from: query)
        print("[WebSearchService] Deep research: Generated \(searchQueries.count) search queries for: \(query)")
        
        var allResults: [WebSearchItem] = []
        var seenURLs = Set<String>()
        var querySummaries: [String: String?] = [:]
        
        // Perform searches for each query
        for (index, searchQuery) in searchQueries.enumerated() {
            do {
                // Update progress
                await MainActor.run {
                    onProgressUpdate?("Searched for: \(searchQuery)", allResults.count)
                }
                
                print("[WebSearchService] Deep research: Executing search \(index + 1)/\(searchQueries.count): \(searchQuery)")
                
                let searchResult = try await searchWeb(
                    query: searchQuery,
                    apiKey: apiKey,
                    maxResults: maxResultsPerQuery
                )
                
                // Aggregate results, deduplicating by URL
                for item in searchResult.results {
                    if !seenURLs.contains(item.url) {
                        seenURLs.insert(item.url)
                        allResults.append(item)
                    }
                }
                
                querySummaries[searchQuery] = searchResult.summary
                
                // Update progress with new total
                await MainActor.run {
                    onProgressUpdate?("Searched for: \(searchQuery)", allResults.count)
                }
                
                // Small delay between searches to avoid rate limiting
                if index < searchQueries.count - 1 {
                    try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
            } catch {
                // If one search fails, log and continue with others
                print("[WebSearchService] Deep research: Search failed for '\(searchQuery)': \(error.localizedDescription)")
                await MainActor.run {
                    onProgressUpdate?("Search failed: \(searchQuery)", allResults.count)
                }
                continue
            }
        }
        
        // Generate comprehensive summary from all results
        let combinedSummary = generateDeepResearchSummary(from: allResults, originalQuery: query, querySummaries: querySummaries)
        
        print("[WebSearchService] Deep research: Completed with \(allResults.count) unique results")
        
        return WebSearchResult(
            query: query,
            results: allResults,
            summary: combinedSummary
        )
    }
    
    /// Generate multiple research queries from the original query
    /// Creates variations that cover different angles and aspects
    private func generateResearchQueries(from originalQuery: String) -> [String] {
        var queries: [String] = [originalQuery] // Always include original
        
        // Extract key terms from the original query
        let words = originalQuery.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.count > 2 }
            .filter { !["the", "a", "an", "and", "or", "but", "for", "with", "about", "what", "how", "why", "when", "where"].contains($0) }
        
        guard !words.isEmpty else { return queries }
        
        let keyTerms = Array(words.prefix(5)).joined(separator: " ")
        
        // Generate related queries
        var relatedQueries: [String] = []
        
        // 1. "How to" perspective
        if !originalQuery.lowercased().contains("how to") && !originalQuery.lowercased().hasPrefix("how ") {
            relatedQueries.append("how to \(keyTerms)")
        }
        
        // 2. "What is" perspective (for concepts/definitions)
        if !originalQuery.lowercased().contains("what is") && !originalQuery.lowercased().hasPrefix("what ") {
            relatedQueries.append("what is \(keyTerms)")
        }
        
        // 3. "Best practices" or "guide" perspective
        relatedQueries.append("\(keyTerms) best practices")
        relatedQueries.append("\(keyTerms) guide")
        
        // 4. "Latest" or "recent" perspective for current information
        relatedQueries.append("latest \(keyTerms)")
        relatedQueries.append("recent \(keyTerms)")
        
        // 5. "Examples" or "case studies" perspective
        relatedQueries.append("\(keyTerms) examples")
        
        // 6. "Comparison" or "vs" if it seems like a comparison topic
        if words.count >= 2 && !originalQuery.lowercased().contains("vs") && !originalQuery.lowercased().contains("versus") && !originalQuery.lowercased().contains("compare") {
            // Only add if it seems like it could be a comparison (has "and" or multiple key terms)
            if originalQuery.lowercased().contains(" and ") || words.count >= 3 {
                relatedQueries.append("\(keyTerms) comparison")
            }
        }
        
        // 7. "Benefits" or "advantages" perspective
        relatedQueries.append("\(keyTerms) benefits")
        
        // Limit to reasonable number of queries (original + up to 8 related = max 9 total)
        queries.append(contentsOf: Array(relatedQueries.prefix(8)))
        
        return queries
    }
    
    /// Generate a comprehensive summary from deep research results
    private func generateDeepResearchSummary(from results: [WebSearchItem], originalQuery: String, querySummaries: [String: String?]) -> String? {
        guard !results.isEmpty else { return nil }
        
        // Combine summaries from different queries
        var summaryParts: [String] = []
        
        // Add original query summary if available
        if let originalSummary = querySummaries[originalQuery] ?? nil, !originalSummary.isEmpty {
            summaryParts.append(originalSummary)
        }
        
        // Add summaries from top results across all queries
        let topResults = results.prefix(10) // Use more results for deep research
        for result in topResults {
            if let snippet = result.snippet, !snippet.isEmpty {
                // Use snippet but limit length
                let truncatedSnippet = snippet.count > 200 ? String(snippet.prefix(200)) + "..." : snippet
                summaryParts.append(truncatedSnippet)
            } else {
                summaryParts.append(result.title)
            }
        }
        
        // If we have many results, create a more comprehensive summary
        if results.count > 10 {
            summaryParts.append("Found \(results.count) relevant sources covering various aspects of the topic.")
        }
        
        return summaryParts.joined(separator: " ")
    }
    
    /// Search the web using Ollama Cloud API
    /// This performs actual web searches and returns real results
    /// - Parameters:
    ///   - query: The search query string
    ///   - apiKey: Ollama Cloud API key (optional, will fetch from AISettings if not provided)
    ///   - maxResults: Maximum number of results to return (default 5, max 10)
    func searchWeb(query: String, apiKey: String? = nil, maxResults: Int = 5) async throws -> WebSearchResult {
        // Get API key from parameter or AISettings
        let resolvedAPIKey: String?
        if let providedKey = apiKey {
            resolvedAPIKey = providedKey
        } else {
            resolvedAPIKey = await MainActor.run {
                AISettings.shared.ollamaCloudAPIKey
            }
        }
        
        guard let apiKey = resolvedAPIKey, !apiKey.isEmpty else {
            throw WebSearchError.apiError("Ollama Cloud API key is required for web search")
        }
        
        guard let url = URL(string: ollamaWebSearchURL) else {
            throw WebSearchError.invalidURL
        }
        
        // Prepare request body
        struct WebSearchRequest: Codable {
            let query: String
            let max_results: Int?
        }
        
        let requestBody = WebSearchRequest(
            query: query,
            max_results: min(max(maxResults, 1), 10) // Clamp between 1 and 10
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 30.0 // 30 second timeout for web search
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw WebSearchError.apiError("Failed to encode request: \(error.localizedDescription)")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WebSearchError.invalidResponse
            }
            
            if httpResponse.statusCode == 401 {
                throw WebSearchError.apiError("Authentication failed. Please check your Ollama Cloud API key.")
            }
            
            guard httpResponse.statusCode == 200 else {
                let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                throw WebSearchError.apiError("HTTP \(httpResponse.statusCode): \(responseBody)")
            }
            
            // Parse JSON response
            struct OllamaWebSearchResponse: Codable {
                let results: [OllamaSearchResult]
            }
            
            struct OllamaSearchResult: Codable {
                let title: String
                let url: String
                let content: String
            }
            
            let decoder = JSONDecoder()
            let ollamaResponse = try decoder.decode(OllamaWebSearchResponse.self, from: data)
            
            // Convert Ollama format to our WebSearchItem format
            // Ollama uses "content" but we use "snippet"
            let results = ollamaResponse.results.map { ollamaResult in
                WebSearchItem(
                    title: ollamaResult.title,
                    url: ollamaResult.url,
                    snippet: ollamaResult.content.isEmpty ? nil : ollamaResult.content
                )
            }
            
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
        } catch let decodingError as DecodingError {
            let errorMessage = "Failed to decode response: \(decodingError.localizedDescription)"
            print("[WebSearchService] Decoding error: \(errorMessage)")
            throw WebSearchError.apiError(errorMessage)
        } catch {
            // If search fails, throw error but don't crash
            if error is WebSearchError {
                throw error
            } else {
                throw WebSearchError.apiError(error.localizedDescription)
            }
        }
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
