//
//  PlatformConnectButton.swift
//  Cloutmate
//
//  Created by Mike Letts on 10/23/25.
//

import SwiftUI
import CloutmateShared

struct PlatformConnectButton: View {
    let platform: Platform
    let action: () -> Void
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Platform Icon
                Image(systemName: platform.iconName)
                    .font(.title2)
                    .foregroundColor(platform.brandColor)
                    .frame(width: 32, height: 32)
                
                // Platform Name
                Text(platform.buttonLabel)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Connect Arrow
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(platform.lightColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(platform.brandColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .scaleEffect(isDisabled ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
}

#Preview {
    VStack(spacing: 16) {
        PlatformConnectButton(platform: .threads, action: {})
        PlatformConnectButton(platform: .facebook, action: {})
    }
    .padding()
}

