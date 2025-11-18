//
//  ArchivesView.swift
//  FocusOS
//
//  Unified view for all archived content - Now using UnifiedArchivesView
//

import SwiftUI
import SwiftData
import AppKit
import FocusOSShared

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
            FocusOSShared.Project.self,
            Area.self,
            FocusOSShared.Note.self,
            FocusOSShared.Artifact.self,
            Draft.self,
            ArchiveReflection.self
        ])
}

