//
//  EnergyRequirement.swift
//  Cloutmate
//
//  Energy requirement types for tasks/projects
//

import Foundation

enum EnergyRequirement: String, Codable, CaseIterable {
    case deep        // Requires deep focus
    case shallow     // Can be done with minimal focus
    case creative    // Requires creative energy
    case admin       // Administrative/mechanical tasks
    
    var displayName: String {
        switch self {
        case .deep: return "Deep Work"
        case .shallow: return "Shallow Work"
        case .creative: return "Creative"
        case .admin: return "Admin"
        }
    }
}

