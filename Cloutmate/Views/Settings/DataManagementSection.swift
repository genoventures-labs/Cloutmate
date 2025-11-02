//
//  DataManagementSection.swift
//  Cloutmate
//
//  Data Management settings section
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import CloutmateShared

struct DataManagementSection: View {
    @Query private var allPosts: [CloutmateShared.Post]
    @Query private var drafts: [Draft]
    @Query private var templates: [Template]
    
    @State private var showClearCacheConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                showClearCacheConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                    Text("Clear Cache")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            Divider()
            
            Button(action: {
                exportAllData()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up.fill")
                        .foregroundColor(.kosmicBlue)
                    Text("Export All Data")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .alert("Clear Cache", isPresented: $showClearCacheConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will remove all cached media files and temporary data. This cannot be undone.")
        }
    }
    
    private func clearCache() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for file in contents {
                try? fileManager.removeItem(at: file)
            }
        } catch {
            print("Failed to clear cache: \(error)")
        }
        
        // Clear media cache if exists
        if let cacheDir = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            do {
                let cacheContents = try fileManager.contentsOfDirectory(at: cacheDir.appendingPathComponent("Cloutmate"), includingPropertiesForKeys: nil)
                for file in cacheContents {
                    try? fileManager.removeItem(at: file)
                }
            } catch {
                // Cache directory doesn't exist yet, that's fine
            }
        }
    }
    
    private func exportAllData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "cloutmate-export-\(Date().formatted(date: .numeric, time: .omitted)).csv"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            var csvString = "Type,ID,Caption,Platform,Status,Scheduled Date,Published Date,Tags,Media URLs\n"
            
            // Export posts
            for post in allPosts {
                let escapedCaption = post.caption.replacingOccurrences(of: "\"", with: "\"\"")
                let platforms = post.postPlatforms.map { $0.displayName }.joined(separator: "|")
                let scheduledDate = post.scheduledDate?.ISO8601Format() ?? ""
                let publishedDate = post.publishedDate?.ISO8601Format() ?? ""
                let tags = post.tags.joined(separator: "|")
                let mediaURLs = post.mediaURLs.joined(separator: "|")
                
                csvString += "Post,\(post.id.uuidString),\"\(escapedCaption)\",\(platforms),\(post.postStatus.displayName),\(scheduledDate),\(publishedDate),\(tags),\(mediaURLs)\n"
            }
            
            // Export drafts
            for draft in drafts {
                let escapedCaption = draft.caption.replacingOccurrences(of: "\"", with: "\"\"")
                let tags = draft.tags.joined(separator: "|")
                let mediaURLs = draft.mediaURLs.joined(separator: "|")
                let updatedAt = draft.updatedAt.ISO8601Format()
                
                csvString += "Draft,\(draft.id.uuidString),\"\(escapedCaption)\",-,Draft,-,\(updatedAt),\(tags),\(mediaURLs)\n"
            }
            
            // Export templates
            for template in templates {
                let escapedCaption = template.caption.replacingOccurrences(of: "\"", with: "\"\"")
                let platforms = template.templatePlatforms.map { $0.displayName }.joined(separator: "|")
                let tags = template.tags.joined(separator: "|")
                
                csvString += "Template,\(template.id.uuidString),\"\(escapedCaption)\",\(platforms),Template,-,-,\(tags),-\n"
            }
            
            do {
                try csvString.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Export error: \(error)")
            }
        }
    }
}

#Preview {
    DataManagementSection()
        .padding()
        .frame(width: 600)
}

