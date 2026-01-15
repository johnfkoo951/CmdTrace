import SwiftUI

struct ConfigurationView: View {
    @Environment(AppState.self) private var appState
    @State private var configuration: ClaudeConfiguration?
    @State private var isLoading = true
    @State private var selectedScope: ClaudeConfigScope? = nil
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            
            if isLoading {
                ProgressView("Loading configuration...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let config = configuration {
                ScrollView {
                    VStack(spacing: 24) {
                        ConfigSummaryCards(config: config)
                        
                        ConfigSection(
                            title: "Commands",
                            icon: "terminal",
                            color: .blue,
                            items: filteredCommands(config.commands),
                            itemView: { CommandRow(command: $0) }
                        )
                        
                        ConfigSection(
                            title: "Skills",
                            icon: "sparkles",
                            color: .purple,
                            items: filteredSkills(config.skills),
                            itemView: { SkillRow(skill: $0) }
                        )
                        
                        ConfigSection(
                            title: "Hooks",
                            icon: "link",
                            color: .orange,
                            items: filteredHooks(config.hooks),
                            itemView: { HookRow(hook: $0) }
                        )
                        
                        ConfigSection(
                            title: "Agents",
                            icon: "person.2",
                            color: .green,
                            items: filteredAgents(config.agents),
                            itemView: { AgentRow(agent: $0) }
                        )
                        
                        ConfigSection(
                            title: "Plugins",
                            icon: "puzzlepiece.extension",
                            color: .cyan,
                            items: config.plugins.filter { $0.isEnabled },
                            itemView: { PluginRow(plugin: $0) }
                        )
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("No Configuration", systemImage: "gear", description: Text("Claude configuration not found"))
            }
        }
        .task {
            await loadConfiguration()
        }
    }
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 200)
            
            Picker("Scope", selection: $selectedScope) {
                Text("All").tag(nil as ClaudeConfigScope?)
                ForEach(ClaudeConfigScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope as ClaudeConfigScope?)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            Spacer()
            
            Button {
                Task { await loadConfiguration() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(.bar)
    }
    
    private func loadConfiguration() async {
        isLoading = true
        defer { isLoading = false }
        
        let projectPaths = Set(appState.sessions.map { $0.project }).map { $0 }
        let service = ClaudeConfigService()
        configuration = await service.loadConfiguration(projectPaths: projectPaths)
    }
    
    private func filteredCommands(_ commands: [ClaudeCommand]) -> [ClaudeCommand] {
        commands.filter { cmd in
            (selectedScope == nil || cmd.scope == selectedScope) &&
            (searchText.isEmpty || cmd.displayName.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    private func filteredSkills(_ skills: [ClaudeSkill]) -> [ClaudeSkill] {
        skills.filter { skill in
            (selectedScope == nil || skill.scope == selectedScope) &&
            (searchText.isEmpty || skill.displayName.localizedCaseInsensitiveContains(searchText) || skill.description.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    private func filteredHooks(_ hooks: [ClaudeHook]) -> [ClaudeHook] {
        hooks.filter { hook in
            (selectedScope == nil || hook.scope == selectedScope) &&
            (searchText.isEmpty || hook.displayName.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    private func filteredAgents(_ agents: [ClaudeAgent]) -> [ClaudeAgent] {
        agents.filter { agent in
            (selectedScope == nil || agent.scope == selectedScope) &&
            (searchText.isEmpty || agent.displayName.localizedCaseInsensitiveContains(searchText) || agent.description.localizedCaseInsensitiveContains(searchText))
        }
    }
}

struct ConfigSummaryCards: View {
    let config: ClaudeConfiguration
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ConfigStatCard(title: "Commands", value: config.commands.count, icon: "terminal", color: .blue)
            ConfigStatCard(title: "Skills", value: config.skills.count, icon: "sparkles", color: .purple)
            ConfigStatCard(title: "Hooks", value: config.hooks.count, icon: "link", color: .orange)
            ConfigStatCard(title: "Agents", value: config.agents.count, icon: "person.2", color: .green)
            ConfigStatCard(title: "Plugins", value: config.plugins.filter(\.isEnabled).count, icon: "puzzlepiece.extension", color: .cyan)
        }
    }
}

struct ConfigStatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
                Text("\(value)")
                    .font(.title)
                    .fontWeight(.bold)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ConfigSection<Item: Identifiable, ItemView: View>: View {
    let title: String
    let icon: String
    let color: Color
    let items: [Item]
    @ViewBuilder let itemView: (Item) -> ItemView
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.headline)
                    Text("(\(items.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded && !items.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        itemView(item)
                    }
                }
            } else if isExpanded && items.isEmpty {
                Text("No items")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 24)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CommandRow: View {
    let command: ClaudeCommand
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "terminal")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("/\(command.displayName)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                ScopeBadge(scope: command.scope)
                Spacer()
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
            
            if !command.shortDescription.isEmpty {
                Text(command.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 1)
            }
            
            if isExpanded {
                Text(command.content)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .lineLimit(20)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SkillRow: View {
    let skill: ClaudeSkill
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(skill.displayName)
                        .font(.system(size: 12, weight: .medium))
                    ScopeBadge(scope: skill.scope)
                }
                
                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct HookRow: View {
    let hook: ClaudeHook
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(hook.displayName)
                    .font(.system(size: 12, weight: .medium))
                Text(hook.hookType)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15))
                    .clipShape(Capsule())
                ScopeBadge(scope: hook.scope)
                Spacer()
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
            
            if isExpanded {
                Text(hook.scriptContent)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .lineLimit(15)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AgentRow: View {
    let agent: ClaudeAgent
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.2")
                .font(.caption)
                .foregroundStyle(.green)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(agent.displayName)
                        .font(.system(size: 12, weight: .medium))
                    if let model = agent.model {
                        Text(model)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    ScopeBadge(scope: agent.scope)
                }
                
                if !agent.description.isEmpty {
                    Text(agent.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PluginRow: View {
    let plugin: ClaudePlugin
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: plugin.isEnabled ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(plugin.isEnabled ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.name)
                    .font(.system(size: 12, weight: .medium))
                Text(plugin.source)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ScopeBadge: View {
    let scope: ClaudeConfigScope
    
    var body: some View {
        Text(scope.rawValue)
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(scope == .global ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
            .foregroundStyle(scope == .global ? .blue : .purple)
            .clipShape(Capsule())
    }
}

struct ConfigurationInspectorPanel: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Configuration")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude Configuration")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Browse your commands, skills, hooks, and agents in the main view.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paths")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Global:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        Text("~/.claude/")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Project:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        Text("<project>/.claude/")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Divider()
                
                Button {
                    let url = URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.path + "/.claude")
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open .claude folder", systemImage: "folder")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(12)
        }
    }
}
