//
//  ResearchSource.swift
//  Cloutmate
//
//  Research source data model for research mode
//

import Foundation

struct ResearchSource: Codable, Identifiable, Hashable {
    let id: UUID
    let url: String
    let title: String?
    let domain: String?
    
    init(url: String, title: String? = nil, domain: String? = nil) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.domain = domain
    }
    
    static func from(urlString: String, title: String? = nil) -> ResearchSource {
        let domain = URL(string: urlString)?.host
        return ResearchSource(url: urlString, title: title, domain: domain)
    }
}

