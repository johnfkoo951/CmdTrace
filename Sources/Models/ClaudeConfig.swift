import Foundation

enum ClaudeConfigScope: String, Codable, CaseIterable {
    case global = "Global"
    case project = "Project"
}

struct ClaudeCommand: Identifiable, Hashable {
    let id: String
    let name: String
    let filename: String
    let content: String
    let scope: ClaudeConfigScope
    let projectPath: String?
    
    var displayName: String {
        name.isEmpty ? filename.replacingOccurrences(of: ".md", with: "") : name
    }
    
    var shortDescription: String {
        let lines = content.components(separatedBy: .newlines)
        return lines.first(where: { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("---") }) ?? ""
    }
}

struct ClaudeSkill: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let directory: String
    let scope: ClaudeConfigScope
    let projectPath: String?
    
    var displayName: String {
        name.isEmpty ? directory : name
    }
}

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

struct ClaudeAgent: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let model: String?
    let color: String?
    let filename: String
    let scope: ClaudeConfigScope
    let projectPath: String?
    
    var displayName: String {
        name.isEmpty ? filename.replacingOccurrences(of: ".md", with: "") : name
    }
}

struct ClaudePlugin: Identifiable, Hashable {
    let id: String
    let name: String
    let source: String
    let isEnabled: Bool
}

struct ClaudeConfiguration {
    var commands: [ClaudeCommand] = []
    var skills: [ClaudeSkill] = []
    var hooks: [ClaudeHook] = []
    var agents: [ClaudeAgent] = []
    var plugins: [ClaudePlugin] = []
    
    var globalCommands: [ClaudeCommand] { commands.filter { $0.scope == .global } }
    var projectCommands: [ClaudeCommand] { commands.filter { $0.scope == .project } }
    
    var globalSkills: [ClaudeSkill] { skills.filter { $0.scope == .global } }
    var projectSkills: [ClaudeSkill] { skills.filter { $0.scope == .project } }
    
    var globalHooks: [ClaudeHook] { hooks.filter { $0.scope == .global } }
    var projectHooks: [ClaudeHook] { hooks.filter { $0.scope == .project } }
    
    var globalAgents: [ClaudeAgent] { agents.filter { $0.scope == .global } }
    var projectAgents: [ClaudeAgent] { agents.filter { $0.scope == .project } }
}

struct SessionConfigUsage {
    var usedCommands: [String] = []
    var usedSkills: [String] = []
    var triggeredHooks: [String] = []
    var invokedAgents: [String] = []
    
    var isEmpty: Bool {
        usedCommands.isEmpty && usedSkills.isEmpty && triggeredHooks.isEmpty && invokedAgents.isEmpty
    }
}
