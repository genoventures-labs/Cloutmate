//
//  PostDropDelegate.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation

struct PostDropDelegate: DropDelegate {
    let targetDate: Date
    let posts: [Post]
    let modelContext: ModelContext
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else {
            return false
        }
        
        let targetDate = self.targetDate
        let posts = self.posts
        let modelContext = self.modelContext
        
        _ = itemProvider.loadTransferable(type: PostDragInfo.self) { result in
            guard case .success(let dragInfo) = result else {
                return
            }
            
            Task { @MainActor in
                guard let post = posts.first(where: { $0.id == dragInfo.postID }) else {
                    return
                }
                
                post.scheduledDate = targetDate
                post.updatedAt = Date()
            }
        }
        
        return true
    }
}

// PostDragInfo struct for dragging posts
struct PostDragInfo: Codable, Transferable {
    let postID: UUID
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .text)
    }
}

// Extension to make Post draggable
extension Post {
    var dragInfo: PostDragInfo {
        PostDragInfo(postID: self.id)
    }
}

