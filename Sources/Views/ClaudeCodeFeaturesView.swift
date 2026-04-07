import SwiftUI

// MARK: - Claude Code Features Dashboard
struct ClaudeCodeFeaturesView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedSection: FeatureSection = .agents
    @State private var expandedCategories: Set<String> = []

    enum FeatureSection: String, CaseIterable {
        case agents = "Agents"
        case hooks = "Hooks"
        case skills = "Skills"
        case mcp = "MCP"
        case plugins = "Plugins"

        var icon: String {
            switch self {
            case .agents: return "person.2.circle"
            case .hooks: return "link.circle"
            case .skills: return "sparkles"
            case .mcp: return "server.rack"
            case .plugins: return "puzzlepiece.extension"
            }
        }

        var color: Color {
            switch self {
            case .agents: return .green
            case .hooks: return .orange
            case .skills: return .purple
            case .mcp: return .cyan
            case .plugins: return .indigo
            }
        }
    }

    private var config: ClaudeConfiguration { appState.claudeConfig }

    var body: some View {
        Group {
            if appState.isLoadingConfig {
                loadingView
            } else if config.totalComponents == 0 {
                emptyStateView
            } else {
                mainContent
            }
        }
        .task {
            if config.totalComponents == 0 {
                await appState.loadClaudeConfig()
            }
        }
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading Claude Code configuration...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Features Configured", systemImage: "cpu")
        } description: {
            Text("Claude Code features like agents, hooks, skills, and MCP servers will appear here once configured.")
        } actions: {
            Button("Refresh") {
                Task { await appState.loadClaudeConfig() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                topStatsBar
                sectionPicker

                switch selectedSection {
                case .agents:
                    FeaturesAgentsSection(config: config)
                case .hooks:
                    FeaturesHooksSection(config: config, expandedCategories: $expandedCategories)
                case .skills:
                    FeaturesSkillsCommandsSection(config: config)
                case .mcp:
                    FeaturesMCPServersSection(config: config)
                case .plugins:
                    FeaturesPluginsSection(config: config)
                }
            }
            .padding()
        }
    }

    // MARK: - Top Stats Bar
    private var topStatsBar: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            FeatureStatCard(
                title: "Agents",
                count: config.agents.count,
                icon: "person.2.circle",
                color: .green,
                isSelected: selectedSection == .agents
            ) { selectedSection = .agents }

            FeatureStatCard(
                title: "Hooks",
                count: config.hookRules.count + config.hooks.count,
                icon: "link.circle",
                color: .orange,
                isSelected: selectedSection == .hooks
            ) { selectedSection = .hooks }

            FeatureStatCard(
                title: "Skills",
                count: config.skills.count,
                icon: "sparkles",
                color: .purple,
                isSelected: selectedSection == .skills
            ) { selectedSection = .skills }

            FeatureStatCard(
                title: "MCP Servers",
                count: config.mcpServers.count,
                icon: "server.rack",
                color: .cyan,
                isSelected: selectedSection == .mcp
            ) { selectedSection = .mcp }
        }
    }

    // MARK: - Section Picker
    private var sectionPicker: some View {
        HStack(spacing: 6) {
            ForEach(FeatureSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: section.icon)
                            .font(.system(size: 11))
                        Text(section.rawValue)
                            .font(.system(size: 11, weight: .medium))
                        let count = sectionCount(for: section)
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(selectedSection == section ? .white.opacity(0.3) : section.color.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedSection == section ? section.color.opacity(0.8) : Color.secondary.opacity(0.08))
                    .foregroundStyle(selectedSection == section ? .white : .primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button {
                Task { await appState.loadClaudeConfig() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func sectionCount(for section: FeatureSection) -> Int {
        switch section {
        case .agents: return config.agents.count + config.agentTeams.count
        case .hooks: return config.hookRules.count + config.hooks.count
        case .skills: return config.skills.count + config.commands.count
        case .mcp: return config.mcpServers.count
        case .plugins: return config.plugins.count
        }
    }
}

// MARK: - Feature Stat Card
struct FeatureStatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(title)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    color.opacity(0.12)
                } else {
                    AnyView(Rectangle().fill(.regularMaterial))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color.opacity(0.4) : .clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Agents Section
struct FeaturesAgentsSection: View {
    let config: ClaudeConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Agent Teams
            if !config.agentTeams.isEmpty {
                featuresSectionLabel("Agent Teams", icon: "person.3.sequence", color: .purple)
                ForEach(config.agentTeams) { team in
                    agentTeamCard(team)
                }
            }

            // Individual Agents
            if !config.agents.isEmpty {
                featuresSectionLabel("Agents", icon: "person.2.circle", color: .green)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(config.agents) { agent in
                        agentCard(agent)
                    }
                }
            }

            if config.agents.isEmpty && config.agentTeams.isEmpty {
                featuresEmptyState(
                    title: "No Agents",
                    description: "Define agents in your Claude Code settings to see them here.",
                    icon: "person.2.circle"
                )
            }
        }
    }

    private func agentCard(_ agent: ClaudeAgent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(agent.agentColor)
                    .frame(width: 10, height: 10)

                Text(agent.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                featuresScopeBadge(agent.scope)
            }

            if !agent.description.isEmpty {
                Text(agent.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                if let model = agent.model, !model.isEmpty {
                    featuresModelBadge(agent.modelBadge.isEmpty ? model : agent.modelBadge)
                }

                if agent.isBackground {
                    featuresBadgePill("Background", color: .indigo, icon: "moon")
                }

                if let mode = agent.permissionMode, !mode.isEmpty {
                    featuresBadgePill(mode, color: .mint, icon: "lock.shield")
                }

                if let maxTurns = agent.maxTurns {
                    featuresBadgePill("\(maxTurns) turns", color: .secondary, icon: "arrow.2.squarepath")
                }
            }

            if !agent.tools.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(agent.tools.prefix(4).joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if agent.tools.count > 4 {
                        Text("+\(agent.tools.count - 4)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func agentTeamCard(_ team: ClaudeAgentTeam) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.sequence.fill")
                    .foregroundStyle(.purple)
                Text(team.displayName)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(team.agentCount) agents")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(max(team.agents.count, 1), 4)), spacing: 8) {
                ForEach(team.agents) { member in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(member.memberColor)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(member.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            if let model = member.model {
                                Text(model)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(8)
                    .background(member.memberColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Hooks Section
struct FeaturesHooksSection: View {
    let config: ClaudeConfiguration
    @Binding var expandedCategories: Set<String>

    private var hooksByCategory: [(category: String, rules: [ClaudeHookRule])] {
        let grouped = Dictionary(grouping: config.hookRules) { $0.event.category }
        let order = ["Tool", "Session", "Agent", "Permission", "Task", "Context", "Worktree", "System"]
        return order.compactMap { cat in
            guard let rules = grouped[cat], !rules.isEmpty else { return nil }
            return (category: cat, rules: rules)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Modern Hook Rules
            if !config.hookRules.isEmpty {
                featuresSectionLabel("Hook Rules", icon: "link.circle", color: .orange)

                hookCategorySummary

                ForEach(hooksByCategory, id: \.category) { group in
                    hookCategorySection(group.category, rules: group.rules)
                }
            }

            // Legacy Hooks
            if !config.hooks.isEmpty {
                featuresSectionLabel("Legacy Hooks", icon: "link", color: .secondary)
                ForEach(config.hooks) { hook in
                    legacyHookRow(hook)
                }
            }

            if config.hookRules.isEmpty && config.hooks.isEmpty {
                featuresEmptyState(
                    title: "No Hooks",
                    description: "Configure hooks in Claude Code settings to automate workflows.",
                    icon: "link.circle"
                )
            }
        }
    }

    private var hookCategorySummary: some View {
        HStack(spacing: 8) {
            ForEach(hooksByCategory, id: \.category) { group in
                HStack(spacing: 4) {
                    let event = group.rules.first?.event
                    Image(systemName: event?.icon ?? "questionmark")
                        .font(.system(size: 10))
                        .foregroundStyle(event?.color ?? .secondary)
                    Text(group.category)
                        .font(.system(size: 10, weight: .medium))
                    Text("\(group.rules.count)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(event?.color.opacity(0.15) ?? Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial)
                .clipShape(Capsule())
            }
        }
    }

    private func hookCategorySection(_ category: String, rules: [ClaudeHookRule]) -> some View {
        let isExpanded = expandedCategories.contains(category)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    let event = rules.first?.event
                    Image(systemName: event?.icon ?? "questionmark")
                        .font(.system(size: 12))
                        .foregroundStyle(event?.color ?? .secondary)

                    Text(category)
                        .font(.system(size: 13, weight: .semibold))

                    Text("\(rules.count)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(event?.color.opacity(0.15) ?? Color.secondary.opacity(0.15))
                        .clipShape(Capsule())

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(rules) { rule in
                        hookRuleRow(rule)
                    }
                }
                .padding(.leading, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func hookRuleRow(_ rule: ClaudeHookRule) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: rule.event.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(rule.event.color)

                Text(rule.event.rawValue)
                    .font(.system(size: 11, weight: .medium))

                if let matcher = rule.matcher, !matcher.isEmpty {
                    Text("[\(matcher)]")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                }

                Spacer()

                hookTypeBadge(rule.hookType)
                featuresScopeBadge(rule.scope)
            }

            Text(rule.shortCommand)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                if rule.isAsync {
                    featuresBadgePill("Async", color: .blue, icon: "bolt")
                }
                if rule.once {
                    featuresBadgePill("Once", color: .yellow, icon: "1.circle")
                }
                if let timeout = rule.timeout {
                    featuresBadgePill("\(timeout)ms", color: .secondary, icon: "clock")
                }
                if let status = rule.statusMessage, !status.isEmpty {
                    featuresBadgePill(status, color: .teal, icon: "text.bubble")
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func legacyHookRow(_ hook: ClaudeHook) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(hook.displayName)
                    .font(.system(size: 12, weight: .medium))
                Text(hook.hookType)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
            featuresScopeBadge(hook.scope)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func hookTypeBadge(_ type: ClaudeHookType) -> some View {
        HStack(spacing: 3) {
            Image(systemName: type.icon)
                .font(.system(size: 8))
            Text(type.displayName)
                .font(.system(size: 9, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.blue.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Skills & Commands Section
struct FeaturesSkillsCommandsSection: View {
    let config: ClaudeConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                // Skills Column
                VStack(alignment: .leading, spacing: 12) {
                    featuresSectionLabel("Skills", icon: "sparkles", color: .purple)

                    if config.skills.isEmpty {
                        featuresEmptyState(
                            title: "No Skills",
                            description: "Skills extend Claude Code with specialized capabilities.",
                            icon: "sparkles"
                        )
                    } else {
                        ForEach(config.skills) { skill in
                            skillCard(skill)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Commands Column
                VStack(alignment: .leading, spacing: 12) {
                    featuresSectionLabel("Commands", icon: "terminal", color: .blue)

                    if config.commands.isEmpty {
                        featuresEmptyState(
                            title: "No Commands",
                            description: "Custom slash commands will appear here.",
                            icon: "terminal"
                        )
                    } else {
                        ForEach(config.commands) { command in
                            commandCard(command)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func skillCard(_ skill: ClaudeSkill) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(.purple)

                Text(skill.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Spacer()
                featuresScopeBadge(skill.scope)
            }

            if !skill.description.isEmpty {
                Text(skill.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let pluginName = skill.pluginName, !pluginName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 8))
                    Text(pluginName)
                        .font(.system(size: 9))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func commandCard(_ command: ClaudeCommand) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 10))
                    .foregroundStyle(.blue)

                Text("/\(command.displayName)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .lineLimit(1)

                Spacer()
                featuresScopeBadge(command.scope)
            }

            if !command.shortDescription.isEmpty {
                Text(command.shortDescription)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                if let model = command.model, !model.isEmpty {
                    featuresModelBadge(model)
                }

                if !command.argNames.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "textformat.alt")
                            .font(.system(size: 8))
                        Text(command.argNames.joined(separator: ", "))
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - MCP Servers Section
struct FeaturesMCPServersSection: View {
    let config: ClaudeConfiguration

    private static let allStatuses: [MCPConnectionStatus] = [.connected, .pending, .needsAuth, .failed, .disabled]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            featuresSectionLabel("MCP Servers", icon: "server.rack", color: .cyan)

            if config.mcpServers.isEmpty {
                featuresEmptyState(
                    title: "No MCP Servers",
                    description: "MCP servers provide tools and resources to Claude Code.",
                    icon: "server.rack"
                )
            } else {
                mcpStatusSummary

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(config.mcpServers) { server in
                        mcpServerCard(server)
                    }
                }
            }
        }
    }

    private var mcpStatusSummary: some View {
        HStack(spacing: 12) {
            let statusGroups = Dictionary(grouping: config.mcpServers) { $0.status }
            ForEach(Self.allStatuses, id: \.self) { status in
                if let servers = statusGroups[status], !servers.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: status.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(status.color)
                        Text("\(servers.count) \(status.rawValue)")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
            }
        }
    }

    private func mcpServerCard(_ server: ClaudeMCPServer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: server.status.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(server.status.color)

                Text(server.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                featuresScopeBadge(server.scope)
            }

            HStack(spacing: 6) {
                Image(systemName: server.transportType.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(server.transportType.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text(server.connectionInfo)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let source = server.pluginSource, !source.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 8))
                    Text(source)
                        .font(.system(size: 9))
                }
                .foregroundStyle(.purple.opacity(0.8))
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(server.status.color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Plugins Section
struct FeaturesPluginsSection: View {
    let config: ClaudeConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            featuresSectionLabel("Plugins", icon: "puzzlepiece.extension", color: .indigo)

            if config.plugins.isEmpty {
                featuresEmptyState(
                    title: "No Plugins",
                    description: "Plugins bundle skills, agents, hooks, and MCP servers together.",
                    icon: "puzzlepiece.extension"
                )
            } else {
                ForEach(config.plugins) { plugin in
                    pluginCard(plugin)
                }
            }
        }
    }

    private func pluginCard(_ plugin: ClaudePlugin) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(plugin.isEnabled ? .indigo : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(plugin.name)
                            .font(.system(size: 13, weight: .semibold))
                        if let version = plugin.version {
                            Text("v\(version)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Text(plugin.source)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(plugin.isEnabled ? "Enabled" : "Disabled")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(plugin.isEnabled ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .foregroundStyle(plugin.isEnabled ? .green : .secondary)
                    .clipShape(Capsule())
            }

            if let desc = plugin.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if plugin.hasComponents {
                HStack(spacing: 10) {
                    if plugin.skillCount > 0 {
                        pluginComponentCount("Skills", count: plugin.skillCount, icon: "sparkles", color: .purple)
                    }
                    if plugin.agentCount > 0 {
                        pluginComponentCount("Agents", count: plugin.agentCount, icon: "person.2", color: .green)
                    }
                    if plugin.hookCount > 0 {
                        pluginComponentCount("Hooks", count: plugin.hookCount, icon: "link", color: .orange)
                    }
                    if plugin.mcpServerCount > 0 {
                        pluginComponentCount("MCP", count: plugin.mcpServerCount, icon: "server.rack", color: .cyan)
                    }
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func pluginComponentCount(_ label: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Features Inspector Panel
struct FeaturesInspectorPanel: View {
    @Environment(AppState.self) private var appState

    private var config: ClaudeConfiguration { appState.claudeConfig }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    VStack(spacing: 6) {
                        featuresInspectorRow("Total Components", value: "\(config.totalComponents)")
                        featuresInspectorRow("Agents", value: "\(config.agents.count)")
                        featuresInspectorRow("Agent Teams", value: "\(config.agentTeams.count)")
                        featuresInspectorRow("Hook Rules", value: "\(config.hookRules.count)")
                        featuresInspectorRow("Legacy Hooks", value: "\(config.hooks.count)")
                        featuresInspectorRow("Skills", value: "\(config.skills.count)")
                        featuresInspectorRow("Commands", value: "\(config.commands.count)")
                        featuresInspectorRow("MCP Servers", value: "\(config.mcpServers.count)")
                        featuresInspectorRow("Plugins", value: "\(config.plugins.count)")
                        featuresInspectorRow("Active Plugins", value: "\(config.activePlugins.count)")
                        featuresInspectorRow("Connected MCP", value: "\(config.connectedMCPServers.count)")
                    }
                }

                Divider()

                // Component Distribution
                VStack(alignment: .leading, spacing: 8) {
                    Text("Distribution")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    distributionBar
                }

                if !config.hookRules.isEmpty {
                    Divider()

                    // Hook Event Breakdown
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hook Events")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(config.hookEventSummary, id: \.event) { item in
                            HStack(spacing: 6) {
                                Image(systemName: item.event.icon)
                                    .font(.system(size: 9))
                                    .foregroundStyle(item.event.color)
                                    .frame(width: 14)
                                Text(item.event.rawValue)
                                    .font(.system(size: 10))
                                Spacer()
                                Text("\(item.count)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                        }
                    }
                }

                Divider()

                // Scope Breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("By Scope")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ForEach(ClaudeConfigScope.allCases, id: \.self) { scope in
                        let count = scopeCount(scope)
                        if count > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: scope.icon)
                                    .font(.system(size: 9))
                                    .foregroundStyle(scope.color)
                                    .frame(width: 14)
                                Text(scope.rawValue)
                                    .font(.system(size: 10))
                                Spacer()
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                        }
                    }
                }

                Divider()

                // Quick Actions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Actions")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Button {
                        Task { await appState.loadClaudeConfig() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Configuration")
                        }
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
        }
    }

    private var distributionBar: some View {
        let items: [(String, Int, Color)] = [
            ("Agents", config.agents.count, .green),
            ("Hooks", config.hookRules.count + config.hooks.count, .orange),
            ("Skills", config.skills.count, .purple),
            ("Commands", config.commands.count, .blue),
            ("MCP", config.mcpServers.count, .cyan),
            ("Plugins", config.plugins.count, .indigo),
        ].filter { $0.1 > 0 }

        let maxVal = items.map(\.1).max() ?? 1

        return VStack(spacing: 6) {
            ForEach(items, id: \.0) { item in
                HStack(spacing: 8) {
                    Text(item.0)
                        .font(.system(size: 10))
                        .frame(width: 60, alignment: .trailing)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.2.opacity(0.7))
                            .frame(width: max(4, geo.size.width * CGFloat(item.1) / CGFloat(maxVal)))
                    }
                    .frame(height: 12)

                    Text("\(item.1)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
    }

    private func featuresInspectorRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
    }

    private func scopeCount(_ scope: ClaudeConfigScope) -> Int {
        let agents = config.agents.filter { $0.scope == scope }.count
        let hooks = config.hookRules.filter { $0.scope == scope }.count
        let legacyHooks = config.hooks.filter { $0.scope == scope }.count
        let skills = config.skills.filter { $0.scope == scope }.count
        let commands = config.commands.filter { $0.scope == scope }.count
        let mcp = config.mcpServers.filter { $0.scope == scope }.count
        return agents + hooks + legacyHooks + skills + commands + mcp
    }
}

// MARK: - Feature Quick Card (for Dashboard)
struct FeatureQuickCard: View {
    @Environment(AppState.self) private var appState
    let title: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        Button {
            appState.selectedTab = .features
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(color)
                    Spacer()
                }
                Text("\(count)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared View Builders

@ViewBuilder
private func featuresSectionLabel(_ title: String, icon: String, color: Color) -> some View {
    HStack(spacing: 6) {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
        Text(title)
            .font(.system(size: 16, weight: .bold))
        Spacer()
    }
}

@ViewBuilder
private func featuresScopeBadge(_ scope: ClaudeConfigScope) -> some View {
    HStack(spacing: 3) {
        Image(systemName: scope.icon)
            .font(.system(size: 8))
        Text(scope.rawValue)
            .font(.system(size: 9, weight: .medium))
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(scope.color.opacity(0.12))
    .foregroundStyle(scope.color)
    .clipShape(Capsule())
}

@ViewBuilder
private func featuresModelBadge(_ model: String) -> some View {
    let color: Color = {
        let lower = model.lowercased()
        if lower.contains("opus") { return .orange }
        if lower.contains("sonnet") { return .blue }
        if lower.contains("haiku") { return .green }
        return .secondary
    }()

    HStack(spacing: 3) {
        Image(systemName: "cpu")
            .font(.system(size: 8))
        Text(model)
            .font(.system(size: 9, weight: .medium))
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(color.opacity(0.12))
    .foregroundStyle(color)
    .clipShape(Capsule())
}

@ViewBuilder
private func featuresBadgePill(_ text: String, color: Color, icon: String) -> some View {
    HStack(spacing: 3) {
        Image(systemName: icon)
            .font(.system(size: 7))
        Text(text)
            .font(.system(size: 9, weight: .medium))
    }
    .padding(.horizontal, 5)
    .padding(.vertical, 2)
    .background(color.opacity(0.1))
    .foregroundStyle(color)
    .clipShape(Capsule())
}

@ViewBuilder
private func featuresEmptyState(title: String, description: String, icon: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon)
            .font(.system(size: 24))
            .foregroundStyle(.tertiary)
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        Text(description)
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
