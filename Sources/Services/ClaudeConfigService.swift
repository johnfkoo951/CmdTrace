import Foundation

actor ClaudeConfigService {
    private let fileManager = FileManager.default
    private let globalClaudePath: String
    
    init() {
        self.globalClaudePath = fileManager.homeDirectoryForCurrentUser.path + "/.claude"
    }
    
    func loadConfiguration(projectPaths: [String] = []) async -> ClaudeConfiguration {
        var config = ClaudeConfiguration()
        
        config.commands = await loadCommands(from: globalClaudePath, scope: .global)
        config.skills = await loadSkills(from: globalClaudePath, scope: .global)
        config.hooks = await loadHooks(from: globalClaudePath, scope: .global)
        config.agents = await loadAgents(from: globalClaudePath, scope: .global)
        config.plugins = await loadPlugins()
        
        for projectPath in projectPaths {
            let projectClaudePath = projectPath + "/.claude"
            if fileManager.fileExists(atPath: projectClaudePath) {
                config.commands += await loadCommands(from: projectClaudePath, scope: .project, projectPath: projectPath)
                config.skills += await loadSkills(from: projectClaudePath, scope: .project, projectPath: projectPath)
                config.hooks += await loadHooks(from: projectClaudePath, scope: .project, projectPath: projectPath)
                config.agents += await loadAgents(from: projectClaudePath, scope: .project, projectPath: projectPath)
            }
        }
        
        return config
    }
    
    private func loadCommands(from basePath: String, scope: ClaudeConfigScope, projectPath: String? = nil) async -> [ClaudeCommand] {
        let commandsPath = basePath + "/commands"
        guard fileManager.fileExists(atPath: commandsPath) else { return [] }
        
        var commands: [ClaudeCommand] = []
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: commandsPath)
            for file in files where file.hasSuffix(".md") {
                let filePath = commandsPath + "/" + file
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    let name = extractFrontmatterValue(from: content, key: "name") ?? ""
                    commands.append(ClaudeCommand(
                        id: "\(scope.rawValue)-cmd-\(file)",
                        name: name,
                        filename: file,
                        content: content,
                        scope: scope,
                        projectPath: projectPath
                    ))
                }
            }
        } catch {}
        
        return commands
    }
    
    private func loadSkills(from basePath: String, scope: ClaudeConfigScope, projectPath: String? = nil) async -> [ClaudeSkill] {
        let skillsPath = basePath + "/skills"
        guard fileManager.fileExists(atPath: skillsPath) else { return [] }
        
        var skills: [ClaudeSkill] = []
        
        do {
            let directories = try fileManager.contentsOfDirectory(atPath: skillsPath)
            for dir in directories {
                let dirPath = skillsPath + "/" + dir
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: dirPath, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
                
                let skillFile = dirPath + "/SKILL.md"
                if let content = try? String(contentsOfFile: skillFile, encoding: .utf8) {
                    let name = extractFrontmatterValue(from: content, key: "name") ?? dir
                    let description = extractFrontmatterValue(from: content, key: "description") ?? ""
                    skills.append(ClaudeSkill(
                        id: "\(scope.rawValue)-skill-\(dir)",
                        name: name,
                        description: description,
                        directory: dir,
                        scope: scope,
                        projectPath: projectPath
                    ))
                }
            }
        } catch {}
        
        return skills
    }
    
    private func loadHooks(from basePath: String, scope: ClaudeConfigScope, projectPath: String? = nil) async -> [ClaudeHook] {
        let hooksPath = basePath + "/hooks"
        guard fileManager.fileExists(atPath: hooksPath) else { return [] }
        
        var hooks: [ClaudeHook] = []
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: hooksPath)
            for file in files where file.hasSuffix(".sh") {
                let filePath = hooksPath + "/" + file
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    hooks.append(ClaudeHook(
                        id: "\(scope.rawValue)-hook-\(file)",
                        name: file.replacingOccurrences(of: ".sh", with: ""),
                        filename: file,
                        scriptContent: content,
                        scope: scope,
                        projectPath: projectPath
                    ))
                }
            }
        } catch {}
        
        return hooks
    }
    
    private func loadAgents(from basePath: String, scope: ClaudeConfigScope, projectPath: String? = nil) async -> [ClaudeAgent] {
        let agentsPath = basePath + "/agents"
        guard fileManager.fileExists(atPath: agentsPath) else { return [] }
        
        var agents: [ClaudeAgent] = []
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: agentsPath)
            for file in files where file.hasSuffix(".md") {
                let filePath = agentsPath + "/" + file
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    let name = extractFrontmatterValue(from: content, key: "name") ?? ""
                    let description = extractFrontmatterValue(from: content, key: "description") ?? ""
                    let model = extractFrontmatterValue(from: content, key: "model")
                    let color = extractFrontmatterValue(from: content, key: "color")
                    agents.append(ClaudeAgent(
                        id: "\(scope.rawValue)-agent-\(file)",
                        name: name,
                        description: description,
                        model: model,
                        color: color,
                        filename: file,
                        scope: scope,
                        projectPath: projectPath
                    ))
                }
            }
        } catch {}
        
        return agents
    }
    
    private func loadPlugins() async -> [ClaudePlugin] {
        let settingsPath = globalClaudePath + "/settings.json"
        guard let data = fileManager.contents(atPath: settingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let enabledPlugins = json["enabledPlugins"] as? [String: Bool] else {
            return []
        }
        
        return enabledPlugins.map { key, value in
            let parts = key.components(separatedBy: "@")
            let name = parts.first ?? key
            let source = parts.count > 1 ? parts[1] : "unknown"
            return ClaudePlugin(
                id: "plugin-\(key)",
                name: name,
                source: source,
                isEnabled: value
            )
        }.sorted { $0.name < $1.name }
    }
    
    private func extractFrontmatterValue(from content: String, key: String) -> String? {
        guard content.hasPrefix("---") else { return nil }
        
        let parts = content.components(separatedBy: "---")
        guard parts.count >= 3 else { return nil }
        
        let frontmatter = parts[1]
        let lines = frontmatter.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("\(key):") {
                var value = String(trimmed.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                }
                return value.isEmpty ? nil : value
            }
        }
        
        return nil
    }
    
    func loadSessionConfigUsage(for session: Session, agent: AgentType) async -> SessionConfigUsage {
        var usage = SessionConfigUsage()
        
        guard let projectFolder = session.projectFolder,
              let fileName = session.fileName else { return usage }
        
        let sessionPath: String
        switch agent {
        case .claude:
            sessionPath = fileManager.homeDirectoryForCurrentUser.path + "/.claude/projects/" + projectFolder + "/" + fileName
        case .opencode:
            sessionPath = fileManager.homeDirectoryForCurrentUser.path + "/.opencode/sessions/" + projectFolder + "/" + fileName
        }
        
        guard let data = fileManager.contents(atPath: sessionPath) else { return usage }
        guard let content = String(data: data, encoding: String.Encoding.utf8) else { return usage }
        
        let lines = content.components(separatedBy: CharacterSet.newlines)
        
        for line in lines where !line.isEmpty {
            guard let lineData = line.data(using: String.Encoding.utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }
            
            if let message = json["message"] as? [String: Any],
               let contentArray = message["content"] as? [[String: Any]] {
                for item in contentArray {
                    if let type = item["type"] as? String, type == "tool_use",
                       let name = item["name"] as? String {
                        if name == "Skill" || name == "skill" {
                            if let input = item["input"] as? [String: Any],
                               let skillName = input["name"] as? String {
                                if !usage.usedSkills.contains(skillName) {
                                    usage.usedSkills.append(skillName)
                                }
                            }
                        }
                        if name == "Task" || name == "task" {
                            if let input = item["input"] as? [String: Any],
                               let command = input["command"] as? String,
                               command.hasPrefix("/") {
                                let cmdName = command.components(separatedBy: " ").first ?? command
                                if !usage.usedCommands.contains(cmdName) {
                                    usage.usedCommands.append(cmdName)
                                }
                            }
                        }
                    }
                }
            }
            
            if let type = json["type"] as? String, type == "system",
               let subtype = json["subtype"] as? String, subtype == "stop_hook_summary",
               let hookInfos = json["hookInfos"] as? [[String: Any]] {
                for hook in hookInfos {
                    if let hookName = hook["hookName"] as? String {
                        if !usage.triggeredHooks.contains(hookName) {
                            usage.triggeredHooks.append(hookName)
                        }
                    }
                }
            }
        }
        
        return usage
    }
}
