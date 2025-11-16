//
//  SourceExtractor.swift
//  Cloutmate
//
//  Service to extract sources (URLs) from responses and web search results
//

import Foundation

struct SourceExtractor {
    /// Extracts unique sources from web search results
    static func extractFromWebSearch(_ webSearchResults: WebSearchResults?) -> [ResearchSource] {
        guard let results = webSearchResults else { return [] }
        
        var sources: [ResearchSource] = []
        var seenURLs = Set<String>()
        
        for item in results.results {
            let url = item.url
            guard !seenURLs.contains(url) else { continue }
            seenURLs.insert(url)
            
            let source = ResearchSource.from(
                urlString: url,
                title: item.title
            )
            sources.append(source)
        }
        
        return sources
    }
    
    /// Extracts URLs from text content using regex
    static func extractFromText(_ text: String) -> [ResearchSource] {
        guard !text.isEmpty else { return [] }
        
        // URL regex pattern
        let urlPattern = #"https?://(?:[-\w.])+(?:[:\d]+)?(?:/(?:[\w/_.])*(?:\?(?:[\w&=%.])*)?(?:#(?:[\w.])*)?)?"#
        let regex = try? NSRegularExpression(pattern: urlPattern, options: [])
        let nsString = text as NSString
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        var sources: [ResearchSource] = []
        var seenURLs = Set<String>()
        
        for match in matches {
            let urlString = nsString.substring(with: match.range)
            
            guard let url = URL(string: urlString),
                  !seenURLs.contains(urlString) else { continue }
            
            seenURLs.insert(urlString)
            
            // Try to extract title from context (text before URL, up to 100 chars)
            let startIndex = max(0, match.range.location - 100)
            let contextRange = NSRange(location: startIndex, length: match.range.location - startIndex)
            let context = nsString.substring(with: contextRange)
            
            // Look for title-like patterns before URL
            let title = extractTitleFromContext(context)
            
            let source = ResearchSource.from(
                urlString: urlString,
                title: title
            )
            sources.append(source)
        }
        
        return sources
    }
    
    /// Extracts title from context text (simple heuristic)
    private static func extractTitleFromContext(_ context: String) -> String? {
        // Look for patterns like "from [title]", "[title] - ", etc.
        let patterns = [
            #"from\s+([^.]{1,60})(?:\s|$)"#,
            #"([^.]{1,60})\s*[-–—]\s*(?:source|link|url)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: context, options: [], range: NSRange(location: 0, length: context.count)),
               match.numberOfRanges > 1 {
                let titleRange = match.range(at: 1)
                if titleRange.location != NSNotFound {
                    let title = (context as NSString).substring(with: titleRange)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty && title.count > 5 {
                        return title
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Combines sources from multiple sources, removing duplicates
    static func combineSources(_ sourceArrays: [[ResearchSource]]) -> [ResearchSource] {
        var allSources: [ResearchSource] = []
        var seenURLs = Set<String>()
        
        for sources in sourceArrays {
            for source in sources {
                if !seenURLs.contains(source.url) {
                    seenURLs.insert(source.url)
                    allSources.append(source)
                }
            }
        }
        
        return allSources
    }
}

