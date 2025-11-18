//
//  PostDragInfo.swift
//  FocusOSShared
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// PostDragInfo struct for dragging posts
public struct PostDragInfo: Codable, Transferable {
    public let postID: UUID
    
    public init(postID: UUID) {
        self.postID = postID
    }
    
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .text)
    }
}

