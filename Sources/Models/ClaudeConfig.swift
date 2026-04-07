import Foundation
import SwiftUI

// MARK: - Config Scope
enum ClaudeConfigScope: String, Codable, CaseIterable {
    case global = "Global"
    case project = "Project"
    case plugin = "Plugin"

    var icon: String {
        switch self {
        case .global: return "globe"
        case .project: return "folder"
        case .plugin: return "puzzlepiece.extension"
        }
    }

    var color: Color {
        switch self {
        case .global: return .blue
        case .project: return .orange
        case .plugin: return .purple
        }
    }
}

// MARK: - Commands
struct ClaudeCommand: Identifiable, Hashable {
    let id: String
    let name: String
    let filename: String
    let content: String
    let scope: ClaudeConfigScope
    let projectPath: String?
    let argNames: [String]
    let model: String?

    init(id: String, name: String, filename: String, content: String, scope: ClaudeConfigScope, projectPath: String? = nil, argNames: [String] = [], model: String? = nil) {
        self.id = id
        self.name = name
        self.filename = filename
        self.content = content
        self.scope = scope
        self.projectPath = projectPath
        self.argNames = argNames
        self.model = model
    }

    var displayName: String {
        name.isEmpty ? filename.replacingOccurrences(of: ".md", with: "") : name
    }

    var shortDescription: String {
        let lines = content.components(separatedBy: .newlines)
        return lines.first(where: { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("---") }) ?? ""
    }
}

// MARK: - Skills
struct ClaudeSkill: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let directory: String
    let scope: ClaudeConfigScope
    let projectPath: String?
    let pluginName: String?

    init(id: String, name: String, description: String, directory: String, scope: ClaudeConfigScope, projectPath: String? = nil, pluginName: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.directory = directory
        self.scope = scope
        self.projectPath = projectPath
        self.pluginName = pluginName
    }

    var displayName: String {
        name.isEmpty ? directory : name
    }
}

// MARK: - Hook Event Types (from Claude Code source)
enum ClaudeHookEvent: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case postToolUseFailure = "PostToolUseFailure"
    case notification = "Notification"
    case userPromptSubmit = "UserPromptSubmit"
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case stop = "Stop"
    case stopFailure = "StopFailure"
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"
    case preCompact = "PreCompact"
    case postCompact = "PostCompact"
    case permissionRequest = "PermissionRequest"
    case permissionDenied = "PermissionDenied"
    case setup = "Setup"
    case teammateIdle = "TeammateIdle"
    case taskCreated = "TaskCreated"
    case taskCompleted = "TaskCompleted"
    case elicitation = "Elicitation"
    case elicitationResult = "ElicitationResult"
    case configChange = "ConfigChange"
    case worktreeCreate = "WorktreeCreate"
    case worktreeRemove = "WorktreeRemove"
    case instructionsLoaded = "InstructionsLoaded"
    case cwdChanged = "CwdChanged"
    case fileChanged = "FileChanged"

    var icon: String {
        switch self {
        case .preToolUse, .postToolUse, .postToolUseFailure: return "wrench.and.screwdriver"
        case .notification: return "bell"
        case .userPromptSubmit: return "text.cursor"
        case .sessionStart, .sessionEnd: return "play.circle"
        case .stop, .stopFailure: return "stop.circle"
        case .subagentStart, .subagentStop: return "person.2"
        case .preCompact, .postCompact: return "arrow.triangle.2.circlepath"
        case .permissionRequest, .permissionDenied: return "lock.shield"
        case .setup: return "gear"
        case .teammateIdle: return "person.crop.circle.badge.clock"
        case .taskCreated, .taskCompleted: return "checklist"
        case .elicitation, .elicitationResult: return "questionmark.circle"
        case .configChange: return "slider.horizontal.3"
        case .worktreeCreate, .worktreeRemove: return "arrow.triangle.branch"
        case .instructionsLoaded: return "doc.text"
        case .cwdChanged: return "folder.badge.gearshape"
        case .fileChanged: return "doc.badge.arrow.up"
        }
    }

    var color: Color {
        switch self {
        case .preToolUse, .postToolUse: return .blue
        case .postToolUseFailure, .stopFailure, .permissionDenied: return .red
        case .notification: return .yellow
        case .userPromptSubmit: return .green
        case .sessionStart, .sessionEnd: return .cyan
        case .stop: return .orange
        case .subagentStart, .subagentStop, .teammateIdle: return .purple
        case .preCompact, .postCompact: return .indigo
        case .permissionRequest: return .mint
        case .setup, .configChange: return .gray
        case .taskCreated, .taskCompleted: return .teal
        case .elicitation, .elicitationResult: return .pink
        case .worktreeCreate, .worktreeRemove: return .brown
        case .instructionsLoaded, .cwdChanged, .fileChanged: return .secondary
        }
    }

    var category: String {
        switch self {
        case .preToolUse, .postToolUse, .postToolUseFailure: return "Tool"
        case .sessionStart, .sessionEnd, .stop, .stopFailure: return "Session"
        case .subagentStart, .subagentStop, .teammateIdle: return "Agent"
        case .permissionRequest, .permissionDenied: return "Permission"
        case .taskCreated, .taskCompleted: return "Task"
        case .preCompact, .postCompact: return "Context"
        case .worktreeCreate, .worktreeRemove: return "Worktree"
        default: return "System"
        }
    }
}

// MARK: - Hook Command Types
enum ClaudeHookType: String, Codable, CaseIterable {
    case command = "command"
    case prompt = "prompt"
    case http = "http"
    case agent = "agent"

    var icon: String {
        switch self {
        case .command: return "terminal"
        case .prompt: return "text.bubble"
        case .http: return "network"
        case .agent: return "person.crop.circle"
        }
    }

    var displayName: String {
        switch self {
        case .command: return "Bash Command"
        case .prompt: return "Prompt"
        case .http: return "HTTP"
        case .agent: return "Agent"
        }
    }
}

// MARK: - Hook Rule (modern settings.json format)
struct ClaudeHookRule: Identifiable, Hashable {
    let id: String
    let event: ClaudeHookEvent
    let matcher: String?
    let hookType: ClaudeHookType
    let command: String?      // for command type
    let prompt: String?       // for prompt/agent type
    let url: String?          // for http type
    let model: String?
    let timeout: Int?
    let isAsync: Bool
    let once: Bool
    let scope: ClaudeConfigScope
    let statusMessage: String?

    var displayName: String {
        if let matcher = matcher, !matcher.isEmpty {
            return "\(event.rawValue) [\(matcher)]"
        }
        return event.rawValue
    }

    var shortCommand: String {
        if let cmd = command {
            let first = cmd.components(separatedBy: "\n").first ?? cmd
            return first.count > 60 ? String(first.prefix(57)) + "..." : first
        }
        if let p = prompt { return String(p.prefix(60)) }
        if let u = url { return u }
        return hookType.displayName
    }
}

// MARK: - Legacy Hook (file-based)
struct ClaudeHook: Identifiable, Hashable {
    let id: String
    let name: String
    let filename: String
    let scriptContent: String
    let scope: ClaudeConfigScope
    let projectPath: String?

    var displayName: String {
        filename.replacingOccurrences(of: ".sh", with: "")
    }

    var hookType: String {
        if filename.contains("pre") { return "Pre-hook" }
        if filename.contains("post") { return "Post-hook" }
        if filename.contains("stop") { return "Stop-hook" }
        return "Hook"
    }
}

// MARK: - Agent
struct ClaudeAgent: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let model: String?
    let color: String?
    let filename: String
    let scope: ClaudeConfigScope
    let projectPath: String?
    let tools: [String]
    let maxTurns: Int?
    let permissionMode: String?
    let isBackground: Bool
    let isolation: String?

    init(id: String, name: String, description: String, model: String? = nil, color: String? = nil, filename: String, scope: ClaudeConfigScope, projectPath: String? = nil, tools: [String] = [], maxTurns: Int? = nil, permissionMode: String? = nil, isBackground: Bool = false, isolation: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.model = model
        self.color = color
        self.filename = filename
        self.scope = scope
        self.projectPath = projectPath
        self.tools = tools
        self.maxTurns = maxTurns
        self.permissionMode = permissionMode
        self.isBackground = isBackground
        self.isolation = isolation
    }

    var displayName: String {
        name.isEmpty ? filename.replacingOccurrences(of: ".md", with: "") : name
    }

    var agentColor: Color {
        guard let hex = color else { return .blue }
        return Color(hex: hex) ?? .blue
    }

    var modelBadge: String {
        guard let m = model else { return "" }
        if m.contains("opus") { return "Opus" }
        if m.contains("sonnet") { return "Sonnet" }
        if m.contains("haiku") { return "Haiku" }
        return m
    }
}

// MARK: - Agent Team (Teammate Identity)
struct ClaudeAgentTeam: Identifiable, Hashable {
    let id: String
    let teamName: String
    let agents: [ClaudeTeamMember]

    var displayName: String { teamName }
    var agentCount: Int { agents.count }
}

struct ClaudeTeamMember: Identifiable, Hashable {
    let id: String
    let agentId: String   // e.g. "researcher@my-team"
    let agentName: String
    let teamName: String
    let color: String?
    let model: String?

    var displayName: String { agentName }

    var memberColor: Color {
        guard let hex = color else { return .blue }
        return Color(hex: hex) ?? .blue
    }
}

// MARK: - MCP Server
enum MCPTransportType: String, Codable, CaseIterable {
    case stdio = "stdio"
    case sse = "sse"
    case http = "http"
    case ws = "ws"
    case sdk = "sdk"

    var icon: String {
        switch self {
        case .stdio: return "terminal"
        case .sse: return "antenna.radiowaves.left.and.right"
        case .http: return "network"
        case .ws: return "bolt.horizontal"
        case .sdk: return "shippingbox"
        }
    }
}

enum MCPConnectionStatus: String, Codable {
    case connected = "connected"
    case failed = "failed"
    case needsAuth = "needs-auth"
    case pending = "pending"
    case disabled = "disabled"

    var icon: String {
        switch self {
        case .connected: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .needsAuth: return "lock.circle.fill"
        case .pending: return "clock.circle.fill"
        case .disabled: return "minus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .connected: return .green
        case .failed: return .red
        case .needsAuth: return .orange
        case .pending: return .yellow
        case .disabled: return .gray
        }
    }
}

struct ClaudeMCPServer: Identifiable, Hashable {
    let id: String
    let name: String
    let transportType: MCPTransportType
    let command: String?
    let args: [String]
    let url: String?
    let scope: ClaudeConfigScope
    let status: MCPConnectionStatus
    let pluginSource: String?
    let env: [String: String]

    init(id: String, name: String, transportType: MCPTransportType = .stdio, command: String? = nil, args: [String] = [], url: String? = nil, scope: ClaudeConfigScope = .global, status: MCPConnectionStatus = .pending, pluginSource: String? = nil, env: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.transportType = transportType
        self.command = command
        self.args = args
        self.url = url
        self.scope = scope
        self.status = status
        self.pluginSource = pluginSource
        self.env = env
    }

    var displayName: String { name }

    var connectionInfo: String {
        switch transportType {
        case .stdio: return command ?? "stdio"
        case .sse, .http, .ws: return url ?? transportType.rawValue
        case .sdk: return "SDK: \(name)"
        }
    }
}

// MARK: - Plugin
struct ClaudePlugin: Identifiable, Hashable {
    let id: String
    let name: String
    let source: String
    let isEnabled: Bool
    let version: String?
    let description: String?
    let skillCount: Int
    let agentCount: Int
    let hookCount: Int
    let mcpServerCount: Int

    init(id: String, name: String, source: String, isEnabled: Bool, version: String? = nil, description: String? = nil, skillCount: Int = 0, agentCount: Int = 0, hookCount: Int = 0, mcpServerCount: Int = 0) {
        self.id = id
        self.name = name
        self.source = source
        self.isEnabled = isEnabled
        self.version = version
        self.description = description
        self.skillCount = skillCount
        self.agentCount = agentCount
        self.hookCount = hookCount
        self.mcpServerCount = mcpServerCount
    }

    var hasComponents: Bool {
        skillCount + agentCount + hookCount + mcpServerCount > 0
    }
}

// MARK: - Configuration (aggregated)
struct ClaudeConfiguration {
    var commands: [ClaudeCommand] = []
    var skills: [ClaudeSkill] = []
    var hooks: [ClaudeHook] = []          // legacy file-based hooks
    var hookRules: [ClaudeHookRule] = []   // modern settings.json hooks
    var agents: [ClaudeAgent] = []
    var agentTeams: [ClaudeAgentTeam] = []
    var plugins: [ClaudePlugin] = []
    var mcpServers: [ClaudeMCPServer] = []

    // Filtered accessors
    var globalCommands: [ClaudeCommand] { commands.filter { $0.scope == .global } }
    var projectCommands: [ClaudeCommand] { commands.filter { $0.scope == .project } }

    var globalSkills: [ClaudeSkill] { skills.filter { $0.scope == .global } }
    var projectSkills: [ClaudeSkill] { skills.filter { $0.scope == .project } }

    var globalHooks: [ClaudeHook] { hooks.filter { $0.scope == .global } }
    var projectHooks: [ClaudeHook] { hooks.filter { $0.scope == .project } }

    var globalAgents: [ClaudeAgent] { agents.filter { $0.scope == .global } }
    var projectAgents: [ClaudeAgent] { agents.filter { $0.scope == .project } }

    var globalHookRules: [ClaudeHookRule] { hookRules.filter { $0.scope == .global } }
    var projectHookRules: [ClaudeHookRule] { hookRules.filter { $0.scope == .project } }

    // Stats
    var totalComponents: Int {
        commands.count + skills.count + hookRules.count + hooks.count + agents.count + plugins.count + mcpServers.count
    }

    var hookEventSummary: [(event: ClaudeHookEvent, count: Int)] {
        let counts = Dictionary(grouping: hookRules) { $0.event }
        return counts.map { ($0.key, $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    var activePlugins: [ClaudePlugin] { plugins.filter { $0.isEnabled } }
    var connectedMCPServers: [ClaudeMCPServer] { mcpServers.filter { $0.status == .connected } }
}

// MARK: - Session Config Usage
struct SessionConfigUsage {
    var usedCommands: [String] = []
    var usedSkills: [String] = []
    var triggeredHooks: [String] = []
    var invokedAgents: [String] = []
    var spawnedTeammates: [String] = []
    var mcpToolCalls: [String] = []

    var isEmpty: Bool {
        usedCommands.isEmpty && usedSkills.isEmpty && triggeredHooks.isEmpty && invokedAgents.isEmpty && spawnedTeammates.isEmpty && mcpToolCalls.isEmpty
    }

    var totalUsage: Int {
        usedCommands.count + usedSkills.count + triggeredHooks.count + invokedAgents.count + spawnedTeammates.count + mcpToolCalls.count
    }
}
