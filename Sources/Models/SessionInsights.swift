import Foundation

struct ToolCall: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let timestamp: Date?
    let input: [String: AnyCodable]?
    
    var toolCategory: ToolCategory {
        ToolCategory.from(toolName: name)
    }
    
    var displayName: String {
        if name.hasPrefix("mcp__") {
            let parts = name.components(separatedBy: "__")
            if parts.count >= 3 {
                return parts.last ?? name
            }
        }
        return name
    }
}

enum ToolCategory: String, CaseIterable, Codable {
    case fileSystem = "File System"
    case codeEdit = "Code Edit"
    case search = "Search"
    case execution = "Execution"
    case web = "Web"
    case task = "Task Management"
    case mcp = "MCP Plugin"
    case other = "Other"
    
    static func from(toolName: String) -> ToolCategory {
        let name = toolName.lowercased()
        
        if name.hasPrefix("mcp__") {
            return .mcp
        }
        
        switch name {
        case "read", "write", "glob":
            return .fileSystem
        case "edit":
            return .codeEdit
        case "grep", "search":
            return .search
        case "bash", "execute":
            return .execution
        case "webfetch", "webbrowse":
            return .web
        case "todowrite", "todoread", "task":
            return .task
        default:
            return .other
        }
    }
    
    var icon: String {
        switch self {
        case .fileSystem: return "folder"
        case .codeEdit: return "pencil"
        case .search: return "magnifyingglass"
        case .execution: return "terminal"
        case .web: return "globe"
        case .task: return "checklist"
        case .mcp: return "puzzlepiece"
        case .other: return "questionmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .fileSystem: return "blue"
        case .codeEdit: return "orange"
        case .search: return "purple"
        case .execution: return "green"
        case .web: return "cyan"
        case .task: return "yellow"
        case .mcp: return "pink"
        case .other: return "gray"
        }
    }
}

struct ToolStatistics: Codable, Hashable {
    let toolName: String
    let count: Int
    let category: ToolCategory
    
    var percentage: Double {
        0
    }
}

struct HookEvent: Identifiable, Codable, Hashable {
    let id: String
    let timestamp: Date
    let hookCount: Int
    let hookInfos: [HookInfo]
    let hookErrors: [String]
    let preventedContinuation: Bool
    
    struct HookInfo: Codable, Hashable {
        let command: String
    }
}

struct TokenUsage: Codable, Hashable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int
    
    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationInputTokens
    }
    
    static var zero: TokenUsage {
        TokenUsage(inputTokens: 0, outputTokens: 0, cacheCreationInputTokens: 0, cacheReadInputTokens: 0)
    }
    
    static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            cacheCreationInputTokens: lhs.cacheCreationInputTokens + rhs.cacheCreationInputTokens,
            cacheReadInputTokens: lhs.cacheReadInputTokens + rhs.cacheReadInputTokens
        )
    }
}

struct ModelUsage: Codable, Hashable {
    let model: String
    let messageCount: Int
    let tokenUsage: TokenUsage
    
    var displayName: String {
        if model.contains("opus") { return "Opus" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("haiku") { return "Haiku" }
        return model.components(separatedBy: "-").first ?? model
    }
}

struct FileChange: Identifiable, Codable, Hashable {
    let id: String
    let filePath: String
    let changeType: FileChangeType
    let timestamp: Date?
    let lineCount: Int?
    
    var fileName: String {
        (filePath as NSString).lastPathComponent
    }
    
    var directory: String {
        (filePath as NSString).deletingLastPathComponent
    }
}

enum FileChangeType: String, Codable {
    case created = "Created"
    case modified = "Modified"
    case read = "Read"
    case deleted = "Deleted"
}

struct ErrorEvent: Identifiable, Codable, Hashable {
    let id: String
    let message: String
    let timestamp: Date?
    let toolName: String?
    let count: Int
    
    var shortMessage: String {
        let lines = message.components(separatedBy: .newlines)
        return lines.first ?? message
    }
}

struct TimelineEvent: Identifiable {
    let id: String
    let timestamp: Date
    let eventType: TimelineEventType
    let title: String
    let detail: String?
    let category: ToolCategory?
}

enum TimelineEventType {
    case toolCall
    case hookTrigger
    case error
    case fileChange
    
    var icon: String {
        switch self {
        case .toolCall: return "wrench.and.screwdriver"
        case .hookTrigger: return "link"
        case .error: return "exclamationmark.triangle"
        case .fileChange: return "doc"
        }
    }
    
    var color: String {
        switch self {
        case .toolCall: return "blue"
        case .hookTrigger: return "orange"
        case .error: return "red"
        case .fileChange: return "green"
        }
    }
}

struct SessionInsights: Codable {
    let sessionId: String
    let toolCalls: [ToolCall]
    let toolStatistics: [ToolStatistics]
    let hookEvents: [HookEvent]
    let totalTokenUsage: TokenUsage
    let modelUsage: [ModelUsage]
    let totalDurationMs: Int
    let generatedAt: Date
    let fileChanges: [FileChange]
    let errorEvents: [ErrorEvent]
    
    var totalToolCalls: Int {
        toolCalls.count
    }
    
    var uniqueToolsUsed: Int {
        Set(toolCalls.map { $0.name }).count
    }
    
    var mostUsedTool: String? {
        toolStatistics.max(by: { $0.count < $1.count })?.toolName
    }
    
    var estimatedCost: Double {
        let inputCost = Double(totalTokenUsage.inputTokens) * 0.000003
        let outputCost = Double(totalTokenUsage.outputTokens) * 0.000015
        let cacheCost = Double(totalTokenUsage.cacheCreationInputTokens) * 0.00000375
        return inputCost + outputCost + cacheCost
    }
    
    var formattedDuration: String {
        let seconds = totalDurationMs / 1000
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds / 60)m \(seconds % 60)s"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return "\(hours)h \(mins)m"
        }
    }
    
    var timelineEvents: [TimelineEvent] {
        var events: [TimelineEvent] = []
        
        for call in toolCalls {
            if let ts = call.timestamp {
                events.append(TimelineEvent(
                    id: call.id,
                    timestamp: ts,
                    eventType: .toolCall,
                    title: call.displayName,
                    detail: nil,
                    category: call.toolCategory
                ))
            }
        }
        
        for hook in hookEvents {
            events.append(TimelineEvent(
                id: hook.id,
                timestamp: hook.timestamp,
                eventType: .hookTrigger,
                title: "Hook triggered",
                detail: "\(hook.hookCount) hooks",
                category: nil
            ))
        }
        
        for error in errorEvents where error.timestamp != nil {
            events.append(TimelineEvent(
                id: error.id,
                timestamp: error.timestamp!,
                eventType: .error,
                title: error.shortMessage,
                detail: error.toolName,
                category: nil
            ))
        }
        
        for change in fileChanges where change.timestamp != nil {
            events.append(TimelineEvent(
                id: change.id,
                timestamp: change.timestamp!,
                eventType: .fileChange,
                title: change.fileName,
                detail: change.changeType.rawValue,
                category: nil
            ))
        }
        
        return events.sorted { $0.timestamp < $1.timestamp }
    }
    
    var uniqueFilesModified: Int {
        Set(fileChanges.filter { $0.changeType == .modified || $0.changeType == .created }.map { $0.filePath }).count
    }
    
    var errorCount: Int {
        errorEvents.reduce(0) { $0 + $1.count }
    }
    
    static var empty: SessionInsights {
        SessionInsights(
            sessionId: "",
            toolCalls: [],
            toolStatistics: [],
            hookEvents: [],
            totalTokenUsage: .zero,
            modelUsage: [],
            totalDurationMs: 0,
            generatedAt: Date(),
            fileChanges: [],
            errorEvents: []
        )
    }
}
