import SwiftUI
import AppKit

struct HighlightedText: View {
    let text: String
    let searchTerm: String?
    let highlightColor: Color
    
    init(_ text: String, searchTerm: String? = nil, highlightColor: Color = .yellow.opacity(0.4)) {
        self.text = text
        self.searchTerm = searchTerm
        self.highlightColor = highlightColor
    }
    
    var body: some View {
        if let searchTerm = searchTerm, !searchTerm.isEmpty {
            highlightedTextView
        } else {
            Text(text)
        }
    }
    
    private var highlightedTextView: some View {
        let searchLower = searchTerm!.lowercased()
        let textLower = text.lowercased()
        
        if let range = textLower.range(of: searchLower) {
            let beforeIndex = text.index(text.startIndex, offsetBy: textLower.distance(from: textLower.startIndex, to: range.lowerBound))
            let afterIndex = text.index(text.startIndex, offsetBy: textLower.distance(from: textLower.startIndex, to: range.upperBound))
            
            let before = String(text[..<beforeIndex])
            let match = String(text[beforeIndex..<afterIndex])
            let after = String(text[afterIndex...])
            
            var attributed = AttributedString(before)
            var highlight = AttributedString(match)
            highlight.backgroundColor = highlightColor
            highlight.foregroundColor = .black
            attributed.append(highlight)
            attributed.append(AttributedString(after))
            return Text(attributed)
        } else {
            return Text(text)
        }
    }
}

struct MessageBubble: View {
    let message: Message
    @Environment(AppState.self) private var appState
    @State private var showCopied = false
    
    var isUser: Bool { message.role == .user }
    
    var agentName: String {
        if isUser { return "You" }
        return appState.selectedCLI.rawValue
    }
    
    var modelInfo: String? {
        guard !isUser else { return nil }
        var info: [String] = []
        if let agent = message.agentDisplayName { info.append(agent) }
        if let model = message.modelDisplayName { info.append(model) }
        return info.isEmpty ? nil : info.joined(separator: " · ")
    }
    
    var bubbleColor: Color {
        if isUser { return .blue.opacity(0.15) }
        if message.isToolUse { return .orange.opacity(0.1) }
        return .secondary.opacity(0.1)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 60) }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !isUser {
                        Image(systemName: message.isToolUse ? "wrench.and.screwdriver" : "sparkles")
                            .font(.caption)
                            .foregroundStyle(message.isToolUse ? .orange : .purple)
                    }
                    
                    Text(agentName)
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    if let info = modelInfo {
                        Text("(\(info))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let timestamp = message.timestamp {
                        Text(timestamp, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopied = false
                        }
                    } label: {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(showCopied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    if isUser {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                
                if appState.settings.renderMarkdown {
                    if let searchTerm = appState.currentSearchTerm, !searchTerm.isEmpty {
                        HighlightedText(message.content, searchTerm: searchTerm)
                            .textSelection(.enabled)
                            .padding(12)
                            .background(bubbleColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        MarkdownText(message.content)
                            .textSelection(.enabled)
                            .padding(12)
                            .background(bubbleColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    HighlightedText(message.content, searchTerm: appState.currentSearchTerm)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(bubbleColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
}
