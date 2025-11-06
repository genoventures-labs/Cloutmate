//
//  ReflectionPanel.swift
//  Cloutmate
//
//  AI Reflection Panel for Cross-Conversation Insights
//

import SwiftUI
import SwiftData

struct ReflectionPanel: View {
    let conversations: [AIConversation]
    
    @State private var insights: String?
    @State private var isLoading = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
                if isExpanded && insights == nil {
                    _Concurrency.Task {
                        await loadInsights()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.kosmicBlue)
                        .font(.caption)
                    Text("AI Insights")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else if let insights = insights {
                    Text(insights)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                } else {
                    Text("Tap to generate insights from your conversations")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(Color.kosmicBlue.opacity(0.05))
        .cornerRadius(10)
    }
    
    private func loadInsights() async {
        isLoading = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let conversationContexts = conversations.map { conversation in
            ConversationSummaryContext(
                conversationId: conversation.id,
                title: conversation.title ?? "Untitled",
                date: dateFormatter.string(from: conversation.createdAt ?? Date()),
                summary: conversation.summary ?? "",
                keyTopics: conversation.tags,
                messageCount: conversation.messages?.count ?? 0,
                emotionalTone: "neutral",
                emotionWeight: 0.0
            )
        }
        
        do {
            let result = try await CoreResponseService.shared.generateInsights(conversations: conversationContexts)
            await MainActor.run {
                insights = result
                isLoading = false
            }
        } catch {
            await MainActor.run {
                insights = "Unable to generate insights at this time."
                isLoading = false
            }
        }
    }
}

#Preview {
    ReflectionPanel(conversations: [])
        .frame(width: 280)
}
