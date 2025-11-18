//
//  SettingsCard.swift
//  FocusOS
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.title3)
                Text(title)
                    .font(.headline)
            }
            
            Divider()
            
            content
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    SettingsCard(title: "Test Section", icon: "gear") {
        Text("Content here")
    }
    .padding()
}

