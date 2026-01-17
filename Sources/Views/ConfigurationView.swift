import SwiftUI
import Combine

struct ConfigurationView: View {
    @Environment(AppState.self) private var appState
    @State private var configuration: ClaudeConfiguration?
    @State private var isLoading = true
    @State private var selectedScope: ClaudeConfigScope? = nil
    @State private var searchText = ""
    @State private var showExportSheet = false
    @State private var copiedItemId: String? = nil
    @State private var fileWatcher: ConfigFileWatcher?
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            
            if isLoading {
                ProgressView("Loading configuration...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let config = configuration {
                if filteredTotalCount(config) == 0 && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            ConfigSummaryCards(config: config)
                            
                            ConfigSection(
                                title: "Commands",
                                icon: "terminal",
                                color: .blue,
                                items: filteredCommands(config.commands),
                                itemView: { CommandRow(command: $0, searchText: searchText, copiedItemId: $copiedItemId) }
                            )
                            
                            ConfigSection(
                                title: "Skills",
                                icon: "sparkles",
                                color: .purple,
                                items: filteredSkills(config.skills),
                                itemView: { SkillRow(skill: $0, searchText: searchText, copiedItemId: $copiedItemId) }
                            )
                            
                            ConfigSection(
                                title: "Hooks",
                                icon: "link",
                                color: .orange,
                                items: filteredHooks(config.hooks),
                                itemView: { HookRow(hook: $0, searchText: searchText, copiedItemId: $copiedItemId) }
                            )
                            
                            ConfigSection(
                                title: "Agents",
                                icon: "person.2",
                                color: .green,
                                items: filteredAgents(config.agents),
                                itemView: { AgentRow(agent: $0, searchText: searchText, copiedItemId: $copiedItemId) }
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
                }
            } else {
                ConfigEmptyStateView {
                    Task { await loadConfiguration() }
                }
            }
        }
        .task {
            await loadConfiguration()
            setupFileWatcher()
        }
        .onDisappear {
            fileWatcher?.stop()
        }
        .sheet(isPresented: $showExportSheet) {
            if let config = configuration {
                ConfigExportSheet(config: config)
            }
        }
    }
    
    private func filteredTotalCount(_ config: ClaudeConfiguration) -> Int {
        filteredCommands(config.commands).count +
        filteredSkills(config.skills).count +
        filteredHooks(config.hooks).count +
        filteredAgents(config.agents).count
    }
    
    private func setupFileWatcher() {
        fileWatcher = ConfigFileWatcher { [self] in
            Task { await loadConfiguration() }
        }
        fileWatcher?.start()
    }
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 220)
            
            HStack(spacing: 8) {
                Text("Scope")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $selectedScope) {
                    Text("All").tag(nil as ClaudeConfigScope?)
                    ForEach(ClaudeConfigScope.allCases, id: \.self) { scope in
                        Text(scope.rawValue).tag(scope as ClaudeConfigScope?)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
            }
            
            Spacer()
            
            Button {
                showExportSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.borderless)
            .disabled(configuration == nil)
            .help("Export Configuration")
            
            Button {
                Task { await loadConfiguration() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
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
    let searchText: String
    @Binding var copiedItemId: String?
    @State private var isExpanded = false
    @State private var isHovering = false
    
    private var isCopied: Bool { copiedItemId == command.id }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "terminal")
                    .font(.caption)
                    .foregroundStyle(.blue)
                HighlightedText("/\(command.displayName)", searchTerm: searchText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                ScopeBadge(scope: command.scope)
                Spacer()
                
                if isHovering || isCopied {
                    CopyButton(isCopied: isCopied) {
                        copyToClipboard("/\(command.displayName)")
                        showCopiedFeedback(command.id)
                    }
                }
                
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
            
            if !command.shortDescription.isEmpty {
                HighlightedText(command.shortDescription, searchTerm: searchText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 1)
            }
            
            if isExpanded {
                HStack {
                    Text(command.content)
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    CopyButton(isCopied: false, label: "Copy Content") {
                        copyToClipboard(command.content)
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(isHovering ? 0.08 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy Command Name") {
                copyToClipboard("/\(command.displayName)")
            }
            Button("Copy Content") {
                copyToClipboard(command.content)
            }
            Divider()
            if let path = command.projectPath {
                Button("Open in Finder") {
                    openInFinder(path)
                }
            }
        }
    }
    
    private func showCopiedFeedback(_ id: String) {
        copiedItemId = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedItemId == id { copiedItemId = nil }
        }
    }
}

struct SkillRow: View {
    let skill: ClaudeSkill
    let searchText: String
    @Binding var copiedItemId: String?
    @State private var isHovering = false
    
    private var isCopied: Bool { copiedItemId == skill.id }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    HighlightedText(skill.displayName, searchTerm: searchText)
                        .font(.system(size: 12, weight: .medium))
                    ScopeBadge(scope: skill.scope)
                }
                
                if !skill.description.isEmpty {
                    HighlightedText(skill.description, searchTerm: searchText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if isHovering || isCopied {
                CopyButton(isCopied: isCopied) {
                    copyToClipboard("/\(skill.displayName)")
                    copiedItemId = skill.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedItemId == skill.id { copiedItemId = nil }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(isHovering ? 0.08 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy Skill Name") {
                copyToClipboard("/\(skill.displayName)")
            }
            if let path = skill.projectPath {
                Divider()
                Button("Open in Finder") {
                    openInFinder(path)
                }
            }
        }
    }
}

struct HookRow: View {
    let hook: ClaudeHook
    let searchText: String
    @Binding var copiedItemId: String?
    @State private var isExpanded = false
    @State private var isHovering = false
    
    private var isCopied: Bool { copiedItemId == hook.id }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.orange)
                HighlightedText(hook.displayName, searchTerm: searchText)
                    .font(.system(size: 12, weight: .medium))
                Text(hook.hookType)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15))
                    .clipShape(Capsule())
                ScopeBadge(scope: hook.scope)
                Spacer()
                
                if isHovering || isCopied {
                    CopyButton(isCopied: isCopied) {
                        copyToClipboard(hook.scriptContent)
                        copiedItemId = hook.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if copiedItemId == hook.id { copiedItemId = nil }
                        }
                    }
                }
                
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
                    .textSelection(.enabled)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .lineLimit(15)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(isHovering ? 0.08 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy Script") {
                copyToClipboard(hook.scriptContent)
            }
            if let path = hook.projectPath {
                Divider()
                Button("Open in Finder") {
                    openInFinder(path)
                }
            }
        }
    }
}

struct AgentRow: View {
    let agent: ClaudeAgent
    let searchText: String
    @Binding var copiedItemId: String?
    @State private var isHovering = false
    
    private var isCopied: Bool { copiedItemId == agent.id }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.2")
                .font(.caption)
                .foregroundStyle(.green)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    HighlightedText(agent.displayName, searchTerm: searchText)
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
                    HighlightedText(agent.description, searchTerm: searchText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if isHovering || isCopied {
                CopyButton(isCopied: isCopied) {
                    copyToClipboard(agent.displayName)
                    copiedItemId = agent.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedItemId == agent.id { copiedItemId = nil }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(isHovering ? 0.08 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy Agent Name") {
                copyToClipboard(agent.displayName)
            }
            if let path = agent.projectPath {
                Divider()
                Button("Open in Finder") {
                    openInFinder(path)
                }
            }
        }
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

struct CopyButton: View {
    let isCopied: Bool
    var label: String = "Copy"
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.caption2)
                .foregroundStyle(isCopied ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .help(isCopied ? "Copied!" : label)
    }
}

struct ConfigEmptyStateView: View {
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Configuration Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Claude configuration files not found.\nCreate configuration files in ~/.claude/ or <project>/.claude/")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Button {
                    let url = URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.path + "/.claude")
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open .claude folder", systemImage: "folder")
                        .frame(width: 180)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    if let url = URL(string: "https://docs.anthropic.com/en/docs/claude-code") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("View Documentation", systemImage: "book")
                        .frame(width: 180)
                }
                .buttonStyle(.bordered)
                
                Button(action: onRefresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .frame(width: 180)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ConfigExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let config: ClaudeConfiguration
    @State private var exportFormat: ExportFormat = .json
    @State private var includeCommands = true
    @State private var includeSkills = true
    @State private var includeHooks = true
    @State private var includeAgents = true
    @State private var includePlugins = true
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case markdown = "Markdown"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Export Configuration")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()
            .background(.bar)
            
            Form {
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                
                Section("Include") {
                    Toggle("Commands (\(config.commands.count))", isOn: $includeCommands)
                    Toggle("Skills (\(config.skills.count))", isOn: $includeSkills)
                    Toggle("Hooks (\(config.hooks.count))", isOn: $includeHooks)
                    Toggle("Agents (\(config.agents.count))", isOn: $includeAgents)
                    Toggle("Plugins (\(config.plugins.filter(\.isEnabled).count))", isOn: $includePlugins)
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Spacer()
                Button("Export") {
                    exportConfiguration()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }
    
    private func exportConfiguration() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = exportFormat == .json ? [.json] : [.plainText]
        panel.nameFieldStringValue = "claude-config.\(exportFormat == .json ? "json" : "md")"
        
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        let content: String
        if exportFormat == .json {
            content = generateJSON()
        } else {
            content = generateMarkdown()
        }
        
        try? content.write(to: url, atomically: true, encoding: .utf8)
        dismiss()
    }
    
    private func generateJSON() -> String {
        var dict: [String: Any] = [:]
        
        if includeCommands {
            dict["commands"] = config.commands.map { ["name": $0.displayName, "scope": $0.scope.rawValue] }
        }
        if includeSkills {
            dict["skills"] = config.skills.map { ["name": $0.displayName, "description": $0.description, "scope": $0.scope.rawValue] }
        }
        if includeHooks {
            dict["hooks"] = config.hooks.map { ["name": $0.displayName, "type": $0.hookType, "scope": $0.scope.rawValue] }
        }
        if includeAgents {
            dict["agents"] = config.agents.map { ["name": $0.displayName, "description": $0.description, "model": $0.model ?? "", "scope": $0.scope.rawValue] }
        }
        if includePlugins {
            dict["plugins"] = config.plugins.filter(\.isEnabled).map { ["name": $0.name, "source": $0.source] }
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }
    
    private func generateMarkdown() -> String {
        var lines: [String] = ["# Claude Configuration\n"]
        
        if includeCommands && !config.commands.isEmpty {
            lines.append("## Commands (\(config.commands.count))\n")
            for cmd in config.commands {
                lines.append("- `/\(cmd.displayName)` [\(cmd.scope.rawValue)]")
            }
            lines.append("")
        }
        
        if includeSkills && !config.skills.isEmpty {
            lines.append("## Skills (\(config.skills.count))\n")
            for skill in config.skills {
                lines.append("- **\(skill.displayName)** [\(skill.scope.rawValue)]")
                if !skill.description.isEmpty {
                    lines.append("  - \(skill.description)")
                }
            }
            lines.append("")
        }
        
        if includeHooks && !config.hooks.isEmpty {
            lines.append("## Hooks (\(config.hooks.count))\n")
            for hook in config.hooks {
                lines.append("- **\(hook.displayName)** (\(hook.hookType)) [\(hook.scope.rawValue)]")
            }
            lines.append("")
        }
        
        if includeAgents && !config.agents.isEmpty {
            lines.append("## Agents (\(config.agents.count))\n")
            for agent in config.agents {
                var line = "- **\(agent.displayName)**"
                if let model = agent.model { line += " (\(model))" }
                line += " [\(agent.scope.rawValue)]"
                lines.append(line)
                if !agent.description.isEmpty {
                    lines.append("  - \(agent.description)")
                }
            }
            lines.append("")
        }
        
        if includePlugins {
            let enabledPlugins = config.plugins.filter(\.isEnabled)
            if !enabledPlugins.isEmpty {
                lines.append("## Plugins (\(enabledPlugins.count))\n")
                for plugin in enabledPlugins {
                    lines.append("- **\(plugin.name)** - \(plugin.source)")
                }
            }
        }
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - File Watcher

class ConfigFileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let callback: () -> Void
    private var fileDescriptor: Int32 = -1
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
    }
    
    func start() {
        let claudePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path
        fileDescriptor = open(claudePath, O_EVTONLY)
        
        guard fileDescriptor >= 0 else { return }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )
        
        source?.setEventHandler { [weak self] in
            self?.callback()
        }
        
        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
        }
        
        source?.resume()
    }
    
    func stop() {
        source?.cancel()
        source = nil
    }
    
    deinit {
        stop()
    }
}

// MARK: - Helper Functions

private func copyToClipboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

private func openInFinder(_ path: String) {
    let url = URL(fileURLWithPath: path)
    NSWorkspace.shared.activateFileViewerSelecting([url])
}
