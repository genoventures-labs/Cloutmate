//
//  DocumentURLDrawer.swift
//  Cloutmate
//
//  AI Assistant V2 - Document URL Drawer
//  V2 drawer for entering document URL
//

import SwiftUI
import CloutmateShared

struct DocumentURLDrawer: View {
    @Binding var isPresented: Bool
    let onImport: (URL) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var glassColorSystem: GlassColorSystem
    
    @State private var urlString = ""
    @State private var isValidURL = false
    @FocusState private var isURLFocused: Bool
    
    private var accentGradient: LinearGradient {
        AuroraPalette.linearGradient(for: colorScheme)
    }
    
    var body: some View {
        Group {
            if isPresented {
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        // Backdrop
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                closeDrawer()
                            }
                            .transition(.opacity)
                        
                        // Drawer slides up from bottom
                        VStack(spacing: 0) {
                            V2DrawerScaffold(
                                accentGradient: accentGradient,
                                showsSidebar: false,
                                header: { headerContent },
                                content: { drawerContent },
                                sidebar: { EmptyView() }
                            )
                        }
                        .frame(maxHeight: geometry.size.height * 0.35)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isURLFocused = true
                    }
                }
            }
        }
    }
    
    private func closeDrawer() {
        withAnimation(GlassMotion.Easing.modalOpen) {
            isPresented = false
        }
    }
    
    private var headerContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import Document from URL")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(glassColorSystem.textPrimary())
                
                Text("Paste a link to a PDF, Markdown, or text file")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(glassColorSystem.textSecondary())
            }
            
            Spacer()
            
            GlassButton(
                nil,
                icon: "xmark",
                style: .iconOnly,
                role: .surface
            ) {
                closeDrawer()
            }
            .accessibilityLabel("Close")
        }
    }
    
    @ViewBuilder
    private var drawerContent: some View {
        VStack(spacing: 20) {
            DrawerSection(title: "URL", icon: "link") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("https://example.com/report.pdf", text: $urlString)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundStyle(glassColorSystem.textPrimary())
                        .focused($isURLFocused)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(glassColorSystem.backgroundSecondary().opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(
                                            isValidURL ? Color.kosmicBlue.opacity(0.5) : glassColorSystem.borderColor().opacity(0.3),
                                            lineWidth: isValidURL ? 2 : 1
                                        )
                                )
                        )
                        .onChange(of: urlString) { _, newValue in
                            validateURL(newValue)
                        }
                        .onSubmit {
                            if isValidURL, let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                importDocument(url: url)
                            }
                        }
                    
                    if !urlString.isEmpty && !isValidURL {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("Please enter a valid URL")
                                .font(.caption)
                                .foregroundStyle(glassColorSystem.textSecondary())
                        }
                    }
                }
            }
            
            HStack(spacing: 12) {
                Spacer()
                
                GlassButton(
                    "Cancel",
                    icon: nil,
                    style: .standard,
                    role: .surface
                ) {
                    closeDrawer()
                }
                
                GlassButton(
                    "Import",
                    icon: "square.and.arrow.down",
                    style: .standard,
                    role: .primary,
                    tintColor: .kosmicBlue
                ) {
                    if isValidURL, let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        importDocument(url: url)
                    }
                }
                .disabled(!isValidURL)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func validateURL(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        isValidURL = !trimmed.isEmpty && URL(string: trimmed) != nil
    }
    
    private func importDocument(url: URL) {
        closeDrawer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onImport(url)
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    DocumentURLDrawer(
        isPresented: $isPresented,
        onImport: { _ in }
    )
    .environmentObject(GlassColorSystem())
}

