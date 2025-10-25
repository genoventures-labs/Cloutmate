//
//  Sidebar.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI

struct Sidebar: View {
    @Binding var selectedTab: TabIdentifier
    var composerViewModel: ComposerViewModel
    
    var body: some View {
        List(selection: $selectedTab) {
            ForEach(TabIdentifier.allCases, id: \.self) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .navigationTitle("Cloutmate")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    composerViewModel.present()
                }) {
                    Label("New Post", systemImage: "plus.circle.fill")
                }
            }
        }
    }
}

#Preview {
    Sidebar(selectedTab: .constant(.dashboard), composerViewModel: ComposerViewModel())
}

