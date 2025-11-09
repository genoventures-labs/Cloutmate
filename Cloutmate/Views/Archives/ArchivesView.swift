//
//  ArchivesView.swift
//  Cloutmate
//
//  Unified view for all archived content - Now using UnifiedArchivesView
//

import SwiftUI
import SwiftData
import AppKit
import CloutmateShared

struct ArchivesView: View {
    var body: some View {
        UnifiedArchivesView()
    }
}

enum ArchiveCategory: String, CaseIterable {
    case all = "All"
    case projects = "Projects"
    case areas = "Areas"
    case resources = "Resources"
}

#Preview {
    ArchivesView()
        .modelContainer(for: [
            CloutmateShared.Project.self,
            Area.self,
            CloutmateShared.Note.self,
            CloutmateShared.Artifact.self,
            Draft.self,
            ArchiveReflection.self
        ])
}

