//
//  ProjectStatusBadge.swift
//  Cloutmate
//
//  Shared component for displaying project status badges
//

import SwiftUI
import CloutmateShared

struct ProjectStatusBadge: View {
    let status: ProjectStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(6)
    }
}

