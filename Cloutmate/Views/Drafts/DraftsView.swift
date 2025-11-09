//
//  DraftsView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData

struct DraftsView: View {
    var body: some View {
        UnifiedDraftsView()
            .navigationTitle("Drafts")
    }
}

#Preview {
    DraftsView()
        .modelContainer(for: [Draft.self])
        .environmentObject(GlassColorSystem())
}

