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

    /// Parse tool calls from content for rich display
    private var toolCalls: [ToolCallInfo] {
        guard message.isToolUse else { return [] }
        return ToolCallInfo.parse(from: message.content)
    }

    /// Text content without tool call markers
    private var textContent: String {
        guard message.isToolUse else { return message.content }
        var text = message.content
        for call in toolCalls {
            text = text.replacingOccurrences(of: call.raw, with: "")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Header: agent name, model, timestamp, copy button
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

                // Content area
                if message.isToolUse && !toolCalls.isEmpty {
                    // Rich tool call display
                    VStack(alignment: .leading, spacing: 6) {
                        // Text content (if any alongside tool calls)
                        if !textContent.isEmpty {
                            if appState.settings.renderMarkdown {
                                MarkdownText(textContent)
                                    .textSelection(.enabled)
                            } else {
                                Text(textContent)
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                        }

                        // Tool call cards
                        ForEach(toolCalls) { call in
                            ToolCallCard(call: call)
                        }
                    }
                    .padding(12)
                    .background(bubbleColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if appState.settings.renderMarkdown {
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

// MARK: - Tool Call Info (parsed from content)

struct ToolCallInfo: Identifiable {
    let id = UUID()
    let raw: String          // Original "[Tool: ...]" or "[MCP: ...]" string
    let toolName: String     // "Read", "Write", "Bash", etc.
    let detail: String       // File path, command, etc.
    let isMCP: Bool

    var icon: String {
        if isMCP { return "puzzlepiece.extension" }
        switch toolName {
        case "Read": return "doc.text"
        case "Write": return "doc.badge.plus"
        case "Edit": return "pencil.line"
        case "Grep": return "magnifyingglass"
        case "Glob": return "folder.badge.magnifyingglass"
        case "Bash": return "terminal"
        case "WebFetch": return "globe"
        case "WebSearch": return "magnifyingglass.circle"
        case "Agent": return "person.2.circle"
        case "Skill": return "sparkles"
        case "TaskCreate", "TodoWrite": return "checklist"
        case "ToolSearch": return "wrench.and.screwdriver"
        case "AskUserQuestion": return "questionmark.bubble"
        default: return "wrench"
        }
    }

    var color: Color {
        if isMCP { return .pink }
        switch toolName {
        case "Read": return .blue
        case "Write": return .green
        case "Edit": return .orange
        case "Grep", "Glob": return .purple
        case "Bash": return .green
        case "WebFetch", "WebSearch": return .cyan
        case "Agent": return .indigo
        case "Skill": return .yellow
        case "TaskCreate", "TodoWrite": return .teal
        case "AskUserQuestion": return .mint
        default: return .gray
        }
    }

    static func parse(from content: String) -> [ToolCallInfo] {
        var calls: [ToolCallInfo] = []

        // Match [Tool: Name] detail... or [MCP: server] tool...
        let pattern = #"\[(Tool|MCP): ([^\]]+)\]([^\[]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return calls }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        for match in matches {
            guard match.numberOfRanges >= 4 else { continue }
            let rawRange = match.range(at: 0)
            let typeRange = match.range(at: 1)
            let nameRange = match.range(at: 2)
            let detailRange = match.range(at: 3)

            let rawStr = nsContent.substring(with: rawRange)
            let typeStr = nsContent.substring(with: typeRange)
            let nameStr = nsContent.substring(with: nameRange)
            let detailStr = nsContent.substring(with: detailRange).trimmingCharacters(in: .whitespacesAndNewlines)

            let isMCP = typeStr == "MCP"
            // For [Tool: Read] dir/file.swift → toolName="Read", detail="dir/file.swift"
            // For [Tool: Bash] $ command → toolName="Bash", detail="$ command"
            calls.append(ToolCallInfo(
                raw: rawStr + detailStr,
                toolName: isMCP ? nameStr : nameStr,
                detail: detailStr,
                isMCP: isMCP
            ))
        }

        // Fallback: if no regex match, try simple [Tool: Name] pattern
        if calls.isEmpty {
            let simplePattern = #"\[Tool: (\w+)\]"#
            if let simpleRegex = try? NSRegularExpression(pattern: simplePattern) {
                let simpleMatches = simpleRegex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
                for match in simpleMatches {
                    guard match.numberOfRanges >= 2 else { continue }
                    let rawRange = match.range(at: 0)
                    let nameRange = match.range(at: 1)
                    calls.append(ToolCallInfo(
                        raw: nsContent.substring(with: rawRange),
                        toolName: nsContent.substring(with: nameRange),
                        detail: "",
                        isMCP: false
                    ))
                }
            }
        }

        return calls
    }
}

// MARK: - Tool Call Card

struct ToolCallCard: View {
    let call: ToolCallInfo
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: call.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(call.color)
                .frame(width: 20, height: 20)

            // Tool name
            Text(call.isMCP ? "MCP: \(call.toolName)" : call.toolName)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(call.color)

            // Detail
            if !call.detail.isEmpty {
                Text(call.detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(call.color.opacity(isHovered ? 0.12 : 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(call.color.opacity(0.2), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}
