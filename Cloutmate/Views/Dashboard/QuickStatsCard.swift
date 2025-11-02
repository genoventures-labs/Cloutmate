//
//  QuickStatsCard.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI

struct QuickStatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    HStack {
        QuickStatsCard(
            title: "Posts Published",
            value: "12",
            icon: "doc.text.fill",
            color: .kosmicBlue
        )
        QuickStatsCard(
            title: "Avg Engagement",
            value: "4.2%",
            icon: "heart.fill",
            color: .pink
        )
    }
    .padding()
}

