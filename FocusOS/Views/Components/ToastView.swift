//
//  ToastView.swift
//  FocusOS
//
//  Toast Notification Component
//

import SwiftUI

struct ToastView: View {
    let message: String
    let systemImage: String
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(.white)
                .font(.title3)
            
            Text(message)
                .foregroundColor(.white)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
        )
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
            
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isVisible = false
                }
            }
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toastMessage: String?
    let systemImage: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if let message = toastMessage {
                VStack {
                    Spacer()
                    ToastView(message: message, systemImage: systemImage)
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    toastMessage = nil
                                }
                            }
                        }
                }
            }
        }
    }
}

extension View {
    func toast(message: Binding<String?>, systemImage: String = "checkmark.circle.fill") -> some View {
        modifier(ToastModifier(toastMessage: message, systemImage: systemImage))
    }
}

#Preview {
    VStack {
        Text("Test Toast")
    }
    .toast(message: .constant("Successfully exported to Drafts!"))
}
