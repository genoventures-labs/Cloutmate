//
//  ProjectStatusBadge.swift
//  FocusOS
//
//  Shared component for displaying project status badges
//

import SwiftUI
import FocusOSShared

struct ProjectStatusBadge: View {
    let status: ProjectStatus
    
    private var statusColor: Color {
        switch status {
        case .active:
            return .kosmicBlue
        case .paused:
            return .orange
        case .completed:
            return .kosmicGreen
        }
    }
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
}

