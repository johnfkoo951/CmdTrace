import Foundation

actor ClaudeConfigService {
    private let fileManager = FileManager.default
    private let globalClaudePath: String

    init() {
        self.globalClaudePath = fileManager.homeDirectoryForCurrentUser.path + "/.claude"
    }

    func loadConfiguration(projectPaths: [String] = []) async -> ClaudeConfiguration {
        var config = ClaudeConfiguration()

        // Global configuration
        config.commands = await loadCommands(from: globalClaudePath, scope: .global)
        config.skills = await loadSkills(from: globalClaudePath, scope: .global)
        config.hooks = await loadHooks(from: globalClaudePath, scope: .global)
        config.agents = await loadAgents(from: globalClaudePath, scope: .global)
        config.plugins = await loadPlugins()
        config.mcpServers = await loadMCPServers(scope: .global)
        config.hookRules = await loadHookRules(from: globalClaudePath, scope: .global)

        // Load plugin-provided agents, skills, MCP servers
        let pluginAgentsAndSkills = await loadPluginComponents()
        config.agents += pluginAgentsAndSkills.agents
        config.skills += pluginAgentsAndSkills.skills
        config.mcpServers += pluginAgentsAndSkills.mcpServers

        // Project-scoped configuration
        for projectPath in projectPaths {
            let projectClaudePath = projectPath + "/.claude"
            if fileManager.fileExists(atPath: projectClaudePath) {
                config.commands += await loadCommands(from: projectClaudePath, scope: .project, projectPath: projectPath)
                config.skills += await loadSkills(from: projectClaudePath, scope: .project, projectPath: projectPath)
                config.hooks += await loadHooks(from: projectClaudePath, scope: .project, projectPath: projectPath)
                config.agents += await loadAgents(from: projectClaudePath, scope: .project, projectPath: projectPath)
                config.hookRules += await loadHookRules(from: projectClaudePath, scope: .project, projectPath: projectPath)
                config.mcpServers += await loadMCPServers(scope: .project, projectPath: projectPath)
            }
        }

        // Build agent teams from discovered agents
        config.agentTeams = buildAgentTeams(from: config.agents)

        return config
    }

    // MARK: - Commands

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
                    let model = extractFrontmatterValue(from: content, key: "model")
                    let argsStr = extractFrontmatterValue(from: content, key: "argNames") ?? ""
                    let argNames = argsStr.isEmpty ? [] : argsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    commands.append(ClaudeCommand(
                        id: "\(scope.rawValue)-cmd-\(file)",
                        name: name,
                        filename: file,
                        content: content,
                        scope: scope,
                        projectPath: projectPath,
                        argNames: argNames,
                        model: model
                    ))
                }
            }
        } catch {}

        return commands
    }

    // MARK: - Skills

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

    // MARK: - Legacy File-based Hooks

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

    // MARK: - Modern Hook Rules (from settings.json)

    private func loadHookRules(from basePath: String, scope: ClaudeConfigScope, projectPath: String? = nil) async -> [ClaudeHookRule] {
        let settingsPath = basePath + "/settings.json"
        guard let data = fileManager.contents(atPath: settingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooksJson = json["hooks"] as? [String: Any] else {
            return []
        }

        var rules: [ClaudeHookRule] = []
        var ruleIndex = 0

        for (eventKey, matchersValue) in hooksJson {
            guard let event = ClaudeHookEvent(rawValue: eventKey),
                  let matchers = matchersValue as? [[String: Any]] else { continue }

            for matcher in matchers {
                let matcherPattern = matcher["matcher"] as? String
                guard let hookArray = matcher["hooks"] as? [[String: Any]] else { continue }

                for hookDef in hookArray {
                    let hookType = ClaudeHookType(rawValue: hookDef["type"] as? String ?? "command") ?? .command
                    let command = hookDef["command"] as? String
                    let prompt = hookDef["prompt"] as? String
                    let url = hookDef["url"] as? String
                    let model = hookDef["model"] as? String
                    let timeout = hookDef["timeout"] as? Int
                    let isAsync = hookDef["async"] as? Bool ?? false
                    let once = hookDef["once"] as? Bool ?? false
                    let statusMessage = hookDef["statusMessage"] as? String

                    ruleIndex += 1
                    rules.append(ClaudeHookRule(
                        id: "\(scope.rawValue)-hookrule-\(eventKey)-\(ruleIndex)",
                        event: event,
                        matcher: matcherPattern,
                        hookType: hookType,
                        command: command,
                        prompt: prompt,
                        url: url,
                        model: model,
                        timeout: timeout,
                        isAsync: isAsync,
                        once: once,
                        scope: scope,
                        statusMessage: statusMessage
                    ))
                }
            }
        }

        return rules
    }

    // MARK: - Agents

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
                    let toolsStr = extractFrontmatterValue(from: content, key: "tools") ?? ""
                    let tools = toolsStr.isEmpty ? [] : toolsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    let maxTurns = Int(extractFrontmatterValue(from: content, key: "maxTurns") ?? "")
                    let permissionMode = extractFrontmatterValue(from: content, key: "permissionMode")
                    let isBackground = extractFrontmatterValue(from: content, key: "background") == "true"
                    let isolation = extractFrontmatterValue(from: content, key: "isolation")

                    agents.append(ClaudeAgent(
                        id: "\(scope.rawValue)-agent-\(file)",
                        name: name,
                        description: description,
                        model: model,
                        color: color,
                        filename: file,
                        scope: scope,
                        projectPath: projectPath,
                        tools: tools,
                        maxTurns: maxTurns,
                        permissionMode: permissionMode,
                        isBackground: isBackground,
                        isolation: isolation
                    ))
                }
            }
        } catch {}

        return agents
    }

    // MARK: - MCP Servers

    private func loadMCPServers(scope: ClaudeConfigScope, projectPath: String? = nil) async -> [ClaudeMCPServer] {
        let basePath = projectPath ?? globalClaudePath
        var servers: [ClaudeMCPServer] = []

        // Load from .mcp.json
        let mcpJsonPaths = [
            basePath + "/.mcp.json",
            (projectPath ?? fileManager.homeDirectoryForCurrentUser.path) + "/.mcp.json"
        ]

        for mcpPath in mcpJsonPaths {
            guard let data = fileManager.contents(atPath: mcpPath),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let mcpServers = json["mcpServers"] as? [String: Any] else { continue }

            for (name, serverConfig) in mcpServers {
                guard let config = serverConfig as? [String: Any] else { continue }
                let typeStr = config["type"] as? String ?? "stdio"
                let transport = MCPTransportType(rawValue: typeStr) ?? .stdio

                servers.append(ClaudeMCPServer(
                    id: "\(scope.rawValue)-mcp-\(name)",
                    name: name,
                    transportType: transport,
                    command: config["command"] as? String,
                    args: config["args"] as? [String] ?? [],
                    url: config["url"] as? String,
                    scope: scope,
                    status: .pending,
                    env: config["env"] as? [String: String] ?? [:]
                ))
            }
        }

        return servers
    }

    // MARK: - Plugins

    private func loadPlugins() async -> [ClaudePlugin] {
        let settingsPath = globalClaudePath + "/settings.json"
        guard let data = fileManager.contents(atPath: settingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let enabledPlugins = json["enabledPlugins"] as? [String: Any] else {
            return []
        }

        return enabledPlugins.compactMap { key, value in
            let isEnabled: Bool
            if let boolVal = value as? Bool {
                isEnabled = boolVal
            } else if value is [String] {
                isEnabled = true
            } else {
                isEnabled = false
            }

            let parts = key.components(separatedBy: "@")
            let name = parts.first ?? key
            let source = parts.count > 1 ? parts[1] : "unknown"

            // Count components by checking plugin directory
            let pluginDir = globalClaudePath + "/plugins/" + key
            let skillCount = countItems(at: pluginDir + "/skills")
            let agentCount = countItems(at: pluginDir + "/agents")

            return ClaudePlugin(
                id: "plugin-\(key)",
                name: name,
                source: source,
                isEnabled: isEnabled,
                skillCount: skillCount,
                agentCount: agentCount
            )
        }.sorted { $0.name < $1.name }
    }

    // MARK: - Plugin Components (agents, skills, MCP from plugins)

    private func loadPluginComponents() async -> (agents: [ClaudeAgent], skills: [ClaudeSkill], mcpServers: [ClaudeMCPServer]) {
        var agents: [ClaudeAgent] = []
        var skills: [ClaudeSkill] = []
        let mcpServers: [ClaudeMCPServer] = []

        let pluginsDir = globalClaudePath + "/plugins"
        guard fileManager.fileExists(atPath: pluginsDir) else { return (agents, skills, mcpServers) }

        do {
            let pluginDirs = try fileManager.contentsOfDirectory(atPath: pluginsDir)
            for pluginDir in pluginDirs {
                let pluginPath = pluginsDir + "/" + pluginDir
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: pluginPath, isDirectory: &isDir), isDir.boolValue else { continue }

                // Load plugin agents
                let pluginAgents = await loadAgents(from: pluginPath, scope: .plugin, projectPath: nil)
                agents += pluginAgents

                // Load plugin skills
                let pluginSkills = await loadSkills(from: pluginPath, scope: .plugin, projectPath: nil)
                for skill in pluginSkills {
                    skills.append(ClaudeSkill(
                        id: skill.id,
                        name: skill.name,
                        description: skill.description,
                        directory: skill.directory,
                        scope: .plugin,
                        pluginName: pluginDir
                    ))
                }
            }
        } catch {}

        return (agents, skills, mcpServers)
    }

    // MARK: - Agent Teams

    private func buildAgentTeams(from agents: [ClaudeAgent]) -> [ClaudeAgentTeam] {
        // Group agents by project (potential teams)
        var teams: [String: [ClaudeAgent]] = [:]

        for agent in agents {
            if let projectPath = agent.projectPath {
                let teamName = (projectPath as NSString).lastPathComponent
                teams[teamName, default: []].append(agent)
            }
        }

        // Only create teams for projects with multiple agents
        return teams.compactMap { teamName, teamAgents in
            guard teamAgents.count > 1 else { return nil }
            let members = teamAgents.map { agent in
                ClaudeTeamMember(
                    id: "\(agent.id)-member",
                    agentId: "\(agent.displayName)@\(teamName)",
                    agentName: agent.displayName,
                    teamName: teamName,
                    color: agent.color,
                    model: agent.model
                )
            }
            return ClaudeAgentTeam(
                id: "team-\(teamName)",
                teamName: teamName,
                agents: members
            )
        }
    }

    // MARK: - Session Config Usage

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

        guard let data = fileManager.contents(atPath: sessionPath),
              let content = String(data: data, encoding: .utf8) else { return usage }

        content.enumerateSubstrings(in: content.startIndex..<content.endIndex, options: .byLines) { line, _, _, _ in
            guard let line = line, !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { return }

            // Tool use detection
            if let message = json["message"] as? [String: Any],
               let contentArray = message["content"] as? [[String: Any]] {
                for item in contentArray {
                    guard let type = item["type"] as? String, type == "tool_use",
                          let name = item["name"] as? String else { continue }

                    // Skill invocation
                    if name == "Skill" || name == "skill" {
                        if let input = item["input"] as? [String: Any],
                           let skillName = input["skill"] as? String ?? input["name"] as? String {
                            if !usage.usedSkills.contains(skillName) {
                                usage.usedSkills.append(skillName)
                            }
                        }
                    }

                    // Agent invocation
                    if name == "Agent" {
                        if let input = item["input"] as? [String: Any],
                           let agentType = input["subagent_type"] as? String ?? input["name"] as? String {
                            if !usage.invokedAgents.contains(agentType) {
                                usage.invokedAgents.append(agentType)
                            }
                        }
                    }

                    // MCP tool calls
                    if name.hasPrefix("mcp__") {
                        let parts = name.components(separatedBy: "__")
                        if parts.count >= 2 {
                            let serverName = parts[1]
                            if !usage.mcpToolCalls.contains(serverName) {
                                usage.mcpToolCalls.append(serverName)
                            }
                        }
                    }

                    // Command invocation
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

            // Hook events
            if let type = json["type"] as? String {
                if type == "system",
                   let subtype = json["subtype"] as? String, subtype == "stop_hook_summary",
                   let hookInfos = json["hookInfos"] as? [[String: Any]] {
                    for hook in hookInfos {
                        if let hookName = hook["hookName"] as? String ?? hook["command"] as? String {
                            if !usage.triggeredHooks.contains(hookName) {
                                usage.triggeredHooks.append(hookName)
                            }
                        }
                    }
                }

                // Agent/Teammate spawning
                if type == "agent-name" {
                    if let agentName = json["agentName"] as? String {
                        if !usage.spawnedTeammates.contains(agentName) {
                            usage.spawnedTeammates.append(agentName)
                        }
                    }
                }
            }
        }

        return usage
    }

    // MARK: - Helpers

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

    private func countItems(at path: String) -> Int {
        guard fileManager.fileExists(atPath: path) else { return 0 }
        return (try? fileManager.contentsOfDirectory(atPath: path).count) ?? 0
    }
}
