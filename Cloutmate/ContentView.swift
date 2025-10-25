//
//  ContentView.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MainWindowView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Post.self, Draft.self, Template.self])
}
