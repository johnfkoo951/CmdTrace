import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval = 60
    
    var body: some View {
        @Bindable var state = appState
        
        TabView {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $state.settings.theme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    
                    Toggle("Show Tool Calls", isOn: $state.settings.showToolCalls)
                    Toggle("Render Markdown", isOn: $state.settings.renderMarkdown)
                }
                
                Section("CLI Tools") {
                    Text("Select which CLI tools to show:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ForEach(CLITool.allCases, id: \.self) { cli in
                        HStack {
                            Toggle(cli.rawValue, isOn: Binding(
                                get: { state.settings.enabledCLIs.contains(cli) },
                                set: { enabled in
                                    if enabled {
                                        if !state.settings.enabledCLIs.contains(cli) {
                                            state.settings.enabledCLIs.append(cli)
                                        }
                                    } else {
                                        state.settings.enabledCLIs.removeAll { $0 == cli }
                                    }
                                    appState.saveUserData()
                                }
                            ))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            CLIIconPicker(cli: cli)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .frame(height: 28)
                    }
                }
                
                Section("Refresh") {
                    Picker("Auto Refresh", selection: $autoRefreshInterval) {
                        Text("Off").tag(0)
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("5 minutes").tag(300)
                    }
                }
                
                Section("Obsidian Integration") {
                    LabeledContent("Vault Path") {
                        HStack {
                            Text(state.settings.obsidianVaultPath.isEmpty ? "Not set" : state.settings.obsidianVaultPath)
                                .foregroundStyle(state.settings.obsidianVaultPath.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Button("Browse...") {
                                selectObsidianVault()
                            }
                        }
                    }
                    
                    if !state.settings.obsidianVaultPath.isEmpty {
                        let exists = FileManager.default.fileExists(atPath: state.settings.obsidianVaultPath)
                        HStack {
                            Image(systemName: exists ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(exists ? .green : .red)
                            Text(exists ? "Vault found" : "Path not found")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    TextField("Filename Prefix", text: $state.settings.obsidianPrefix, prompt: Text("e.g., CmdTrace_"))
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Filename Suffix", text: $state.settings.obsidianSuffix, prompt: Text("e.g., _{{date}}"))
                        .textFieldStyle(.roundedBorder)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Available Variables:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("{{date}} - Current date (2025-01-13)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("{{time}} - Current time (06:44)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("{{project}} - Project name")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("{{cli}} - CLI tool (ClaudeCode, OpenCode)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("{{session}} - Session ID")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("{{messages}} - Message count")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    
                    DisclosureGroup("Expected YAML Frontmatter") {
                        Text("""
                        ---
                        type: session
                        aliases: ["Session Title"]
                        date created: 2025-01-13T06:44
                        date modified: 2025-01-13T06:44
                        tags: [CmdTrace, ClaudeCode]
                        session-id: abc123...
                        agent: "[[Claude Code]]"
                        project: project-name
                        project-path: "/path/to/project"
                        project-link: "[name](hook://...)"
                        messages: 42
                        ---
                        """)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            
            // Tags Tab
            Form {
                Section("Tag Management") {
                    Text("Manage all tags across sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if appState.tagDatabase.isEmpty {
                        Text("No tags created yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.allTags) { tagInfo in
                            TagManagementRow(tagInfo: tagInfo)
                        }
                    }
                }
                
                Section("Tag Sorting") {
                    Picker("Sort by", selection: $state.settings.tagSortMode) {
                        ForEach(TagSortMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Tags", systemImage: "tag")
            }
            
            Form {
                Section("API Keys") {
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("OpenAI API Key", text: $state.settings.openaiKey, prompt: Text("sk-..."))
                        Text("Used for AI suggestions")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("Anthropic API Key", text: $state.settings.anthropicKey, prompt: Text("sk-ant-..."))
                        Text("Used for session summaries")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("Google Gemini API Key", text: $state.settings.geminiKey, prompt: Text("AIza..."))
                        Text("Alternative AI provider")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("xAI Grok API Key", text: $state.settings.grokKey, prompt: Text("xai-..."))
                        Text("Alternative AI provider")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Section("AI Tasks") {
                    Picker("Summary Provider", selection: $state.settings.summaryProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }

                    Picker("Suggestion Provider", selection: $state.settings.suggestionProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                }

                Section("Model Settings") {
                    // OpenAI Model
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("OpenAI Model")
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Toggle("Custom", isOn: $state.settings.useCustomOpenaiModel)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                        }
                        if state.settings.useCustomOpenaiModel {
                            TextField("Model name (e.g., gpt-5)", text: $state.settings.customOpenaiModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                        } else {
                            Picker("", selection: $state.settings.openaiModel) {
                                Text("GPT-5.2 (Latest)").tag("gpt-5.2")
                                Text("GPT-5.1").tag("gpt-5.1")
                                Text("GPT-5").tag("gpt-5")
                                Text("GPT-4.1").tag("gpt-4.1")
                                Text("GPT-4.1 Mini").tag("gpt-4.1-mini")
                                Text("GPT-4.1 Nano").tag("gpt-4.1-nano")
                                Text("GPT-4o").tag("gpt-4o")
                                Text("GPT-4o Mini").tag("gpt-4o-mini")
                            }
                            .labelsHidden()
                        }
                    }

                    // Anthropic Model
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Anthropic Model")
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Toggle("Custom", isOn: $state.settings.useCustomAnthropicModel)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                        }
                        if state.settings.useCustomAnthropicModel {
                            TextField("Model name (e.g., claude-4-sonnet)", text: $state.settings.customAnthropicModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                        } else {
                            Picker("", selection: $state.settings.anthropicModel) {
                                Text("Claude 4 Sonnet (Latest)").tag("claude-sonnet-4-20250514")
                                Text("Claude 4 Opus").tag("claude-opus-4-20250514")
                                Text("Claude 4.5 Opus").tag("claude-opus-4-5-20251101")
                                Text("Claude 3.7 Sonnet").tag("claude-3-7-sonnet-20250219")
                                Text("Claude 3.5 Haiku").tag("claude-3-5-haiku-latest")
                                Text("Claude 3.5 Sonnet").tag("claude-3-5-sonnet-latest")
                            }
                            .labelsHidden()
                        }
                    }

                    // Gemini Model
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Gemini Model")
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Toggle("Custom", isOn: $state.settings.useCustomGeminiModel)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                        }
                        if state.settings.useCustomGeminiModel {
                            TextField("Model name (e.g., gemini-3-pro)", text: $state.settings.customGeminiModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                        } else {
                            Picker("", selection: $state.settings.geminiModel) {
                                Text("Gemini 2.5 Flash (Recommended)").tag("gemini-2.5-flash")
                                Text("Gemini 2.5 Pro").tag("gemini-2.5-pro")
                                Text("Gemini 2.0 Flash").tag("gemini-2.0-flash")
                                Text("Gemini 2.5 Flash Lite").tag("gemini-2.5-flash-lite")
                            }
                            .labelsHidden()
                        }
                    }

                    // Grok Model
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Grok Model")
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Toggle("Custom", isOn: $state.settings.useCustomGrokModel)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                        }
                        if state.settings.useCustomGrokModel {
                            TextField("Model name (e.g., grok-5)", text: $state.settings.customGrokModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                        } else {
                            Picker("", selection: $state.settings.grokModel) {
                                Text("Grok 4.1 Fast (Latest)").tag("grok-4-1-fast-non-reasoning")
                                Text("Grok 4.1 Reasoning").tag("grok-4-1-fast-reasoning")
                                Text("Grok 4").tag("grok-4")
                                Text("Grok 3").tag("grok-3")
                                Text("Grok Code").tag("grok-code-fast-1")
                            }
                            .labelsHidden()
                        }
                    }

                    Text("Check 'Custom' to enter a model name directly. Useful for new models not yet listed.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Section("Generation Parameters") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.1f", state.settings.aiTemperature))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $state.settings.aiTemperature, in: 0...1, step: 0.1)
                        Text("Lower = more focused, Higher = more creative")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max Tokens")
                                .font(.caption)
                            Spacer()
                            Text("\(state.settings.aiMaxTokens)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(state.settings.aiMaxTokens) },
                            set: { state.settings.aiMaxTokens = Int($0) }
                        ), in: 256...4096, step: 256)
                        Text("Maximum tokens for AI response")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Section("Reminders") {
                    Toggle("Enable Session Reminders", isOn: $state.settings.enableReminders)

                    Stepper("Reminder after \(state.settings.reminderHours) hours", value: $state.settings.reminderHours, in: 1...168)

                    Text("When enabled, you'll receive a notification about sessions you haven't revisited within the specified time. This helps you remember to follow up on ongoing work.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Enable AI Suggestions", isOn: $state.settings.enableSuggestions)
                }

                Section("Context Summary Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source Content Range")
                            .font(.caption)
                            .fontWeight(.semibold)

                        HStack {
                            Text("Max Messages:")
                                .font(.caption)
                            Stepper("\(state.settings.contextMaxMessages)", value: $state.settings.contextMaxMessages, in: 10...200, step: 10)
                                .frame(width: 100)
                        }

                        HStack {
                            Text("Max Chars/Message:")
                                .font(.caption)
                            Stepper("\(state.settings.contextMaxCharsPerMessage)", value: $state.settings.contextMaxCharsPerMessage, in: 100...2000, step: 100)
                                .frame(width: 100)
                        }

                        Text("Current: Up to \(state.settings.contextMaxMessages) messages, \(state.settings.contextMaxCharsPerMessage) chars each")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Context Prompt")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Spacer()

                            Button {
                                state.settings.contextPrompt = AppSettings.defaultContextPrompt
                            } label: {
                                Label("Reset to Default", systemImage: "arrow.counterclockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .disabled(state.settings.contextPrompt == AppSettings.defaultContextPrompt)
                        }

                        TextEditor(text: $state.settings.contextPrompt)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(height: 150)
                            .scrollContentBackground(.hidden)
                            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )

                        Text("This prompt is sent to the AI to generate session summaries, titles, and tags.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    DisclosureGroup("View Default Prompt") {
                        Text(AppSettings.defaultContextPrompt)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .font(.caption)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("AI", systemImage: "sparkles")
            }
            
            // About Tab
            Form {
                Section("About") {
                    LabeledContent("App", value: "CmdTrace")
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    Text("macOS native session viewer for AI CLI coding assistants")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Contributors") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Yohan Koo")
                                .fontWeight(.medium)
                            Spacer()
                            Link(destination: URL(string: "https://github.com/johnfkoo951")!) {
                                Image(systemName: "link")
                            }
                        }
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.green)
                            Text("Joon Park")
                                .fontWeight(.medium)
                        }
                    }
                }

                Section("Links") {
                    Link(destination: URL(string: "https://github.com/johnfkoo951/CmdTrace")!) {
                        Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: URL(string: "https://x.com/YohanKoo")!) {
                        Label("X (Twitter)", systemImage: "at")
                    }
                    Link(destination: URL(string: "https://www.youtube.com/@cmdspace")!) {
                        Label("YouTube - 커맨드스페이스", systemImage: "play.rectangle")
                    }
                    Link(destination: URL(string: "https://www.instagram.com/cmds_pace/")!) {
                        Label("Instagram", systemImage: "camera")
                    }
                    Link(destination: URL(string: "https://www.linkedin.com/in/yohan-koo-a1baa3138/")!) {
                        Label("LinkedIn", systemImage: "briefcase")
                    }
                    Link(destination: URL(string: "https://www.threads.com/@cmds_pace")!) {
                        Label("Threads", systemImage: "at.circle")
                    }
                    Link(destination: URL(string: "https://class.cmdspace.kr/")!) {
                        Label("Edu Portal", systemImage: "graduationcap")
                    }
                }

                Section("Credits") {
                    Text("Built with SwiftUI for macOS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 500, height: 550)
        .onChange(of: state.settings) { _, _ in
            appState.saveUserData()
        }
    }
    
    private func selectObsidianVault() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select your Obsidian vault folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            appState.settings.obsidianVaultPath = url.path
            appState.saveUserData()
        }
    }
}

// MARK: - Tag Management Row
struct TagManagementRow: View {
    @Environment(AppState.self) private var appState
    let tagInfo: TagInfo
    @State private var isRenaming = false
    @State private var newName = ""
    
    var usageCount: Int {
        appState.tagCount(for: tagInfo.name)
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(tagInfo.swiftUIColor)
                .frame(width: 12, height: 12)
            
            if tagInfo.isImportant {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
            
            Text(tagInfo.name)
            
            Spacer()
            
            Text("\(usageCount) sessions")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Menu {
                Button {
                    newName = tagInfo.name
                    isRenaming = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                
                Button {
                    toggleImportant()
                } label: {
                    Label(tagInfo.isImportant ? "Remove Important" : "Mark Important",
                          systemImage: tagInfo.isImportant ? "star.slash" : "star")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    appState.deleteTag(tagInfo.name)
                } label: {
                    Label("Delete Tag", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .alert("Rename Tag", isPresented: $isRenaming) {
            TextField("New name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if !newName.isEmpty && newName != tagInfo.name {
                    appState.renameTag(from: tagInfo.name, to: newName)
                }
            }
        } message: {
            Text("This will rename the tag across all \(usageCount) sessions.")
        }
    }
    
    private func toggleImportant() {
        var updated = tagInfo
        updated = TagInfo(name: tagInfo.name, color: tagInfo.color, isImportant: !tagInfo.isImportant, parentTag: tagInfo.parentTag)
        appState.updateTagInfo(updated)
    }
}

// MARK: - CLI Icon Picker
struct CLIIconPicker: View {
    @Environment(AppState.self) private var appState
    let cli: CLITool
    @State private var customIconName = ""
    @State private var showCustomInput = false
    
    static let iconOptions = [
        "c.circle.fill", "o.circle.fill", "a.circle.fill",
        "terminal.fill", "apple.terminal.fill", "command.circle.fill",
        "chevron.left.forwardslash.chevron.right", "curlybraces",
        "sparkles", "brain.head.profile", "cpu.fill",
        "bolt.fill", "wand.and.stars", "atom",
        "gear", "wrench.and.screwdriver.fill", "hammer.fill",
        "antenna.radiowaves.left.and.right", "network",
        "externaldrive.fill.badge.icloud", "icloud.fill",
        "square.stack.3d.up.fill", "cube.fill", "shippingbox.fill"
    ]
    
    var currentIcon: String {
        appState.settings.iconFor(cli)
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Menu {
                ForEach(Self.iconOptions, id: \.self) { icon in
                    Button {
                        setIcon(icon)
                    } label: {
                        HStack {
                            Image(systemName: icon)
                            Text(icon)
                            if currentIcon == icon {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
                
                Button("Custom SF Symbol...") {
                    customIconName = currentIcon
                    showCustomInput = true
                }
                
                Button("Reset to Default") {
                    var newIcons = appState.settings.cliIcons
                    newIcons.removeValue(forKey: cli.rawValue)
                    appState.settings.cliIcons = newIcons
                    appState.saveUserData()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: currentIcon)
                        .frame(width: 20, height: 20)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
        }
        .alert("Custom SF Symbol", isPresented: $showCustomInput) {
            TextField("SF Symbol name", text: $customIconName)
            Button("Cancel", role: .cancel) {}
            Button("Apply") {
                if !customIconName.isEmpty {
                    setIcon(customIconName)
                }
            }
        } message: {
            Text("Enter SF Symbol name (e.g., star.fill, bolt.circle)")
        }
    }
    
    private func setIcon(_ icon: String) {
        var newIcons = appState.settings.cliIcons
        newIcons[cli.rawValue] = icon
        appState.settings.cliIcons = newIcons
        appState.saveUserData()
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
