import SwiftUI
import Charts

// MARK: - Model Display Utilities

/// Shared utilities for displaying Claude model names and colors
/// Used by DailyUsageRow, MonthlyUsageRow, BlockUsageRow, ModelBreakdownRow, NativeMonitorView
enum ModelDisplayUtils {
    /// Returns a short, human-readable model name
    static func shortName(_ model: String) -> String {
        if model.contains("opus") { return "Opus" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("haiku") { return "Haiku" }
        return String(model.prefix(6))
    }
    
    /// Returns the color associated with a model
    static func color(_ model: String) -> Color {
        if model.contains("opus") { return .purple }
        if model.contains("sonnet") { return .blue }
        if model.contains("haiku") { return .green }
        return .gray
    }
    
    /// Formats a token count with K/M suffix
    static func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000)
        }
        return "\(n)"
    }
}

struct DetailView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        switch appState.selectedTab {
        case .sessions:
            SessionDetailView()
        case .projects:
            ProjectsView()
        case .dashboard:
            DashboardView()
        case .configuration:
            ConfigurationView()
        case .interaction:
            InteractionView()
        }
    }
}

struct SessionDetailView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        if let session = appState.selectedSession {
            ConversationView(session: session)
        } else {
            ContentUnavailableView {
                Label("Select a Session", systemImage: "bubble.left.and.bubble.right")
            } description: {
                Text("Choose a session from the sidebar to view the conversation")
            }
        }
    }
}

struct ConversationView: View {
    let session: Session
    @Environment(AppState.self) private var appState
    @State private var messages: [Message] = []
    @State private var isLoading = true
    @State private var showRenameAlert = false
    @State private var newName = ""
    @State private var copySuccess = false
    
    var body: some View {
        VStack(spacing: 0) {
            SessionHeader(
                session: session,
                messages: messages,
                showRenameAlert: $showRenameAlert,
                newName: $newName,
                copySuccess: $copySuccess
            )
            
            if isLoading {
                ProgressView("Loading messages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messages.isEmpty {
                ContentUnavailableView {
                    Label("No Messages", systemImage: "bubble.left")
                } description: {
                    Text("This session has no messages")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        let filteredMessages = appState.settings.showToolCalls 
                            ? messages 
                            : messages.filter { !$0.isToolUse }
                        ForEach(filteredMessages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadMessages()
        }
        .onChange(of: session) { _, _ in
            Task { await loadMessages() }
        }
        .alert("Rename Session", isPresented: $showRenameAlert) {
            TextField("Session name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                appState.setSessionName(newName, for: session.id)
            }
        }
    }
    
    private func loadMessages() async {
        isLoading = true
        let service = SessionService()
        do {
            messages = try await service.loadMessages(for: session, agent: appState.agentType)
        } catch {
            messages = []
        }
        isLoading = false
    }
}

struct SessionHeader: View {
    let session: Session
    let messages: [Message]
    @Binding var showRenameAlert: Bool
    @Binding var newName: String
    @Binding var copySuccess: Bool
    @Environment(AppState.self) private var appState
    @State private var isGeneratingTitle = false
    @State private var showExportSheet = false
    @State private var showDiffSheet = false
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(appState.getDisplayName(for: session))
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                
                Button {
                    newName = appState.sessionMetadata[session.id]?.customName ?? ""
                    showRenameAlert = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Rename session")
                
                Button {
                    Task { await generateTitle() }
                } label: {
                    if isGeneratingTitle {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundStyle(.purple)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isGeneratingTitle || !appState.settings.hasSummaryProviderKey)
                .help("Auto-generate title")
                
                Spacer()
                
                HStack(spacing: 4) {
                    RibbonButton(icon: "arrow.clockwise", isActive: false) {
                        Task { await appState.loadSessions() }
                    }
                    .help("Refresh")
                    
                    Divider().frame(height: 20)
                    
                    RibbonButton(icon: "text.badge.checkmark", isActive: state.settings.renderMarkdown) {
                        state.settings.renderMarkdown.toggle()
                    }
                    .help("Markdown")
                    
                    RibbonButton(icon: "wrench.and.screwdriver", isActive: state.settings.showToolCalls) {
                        state.settings.showToolCalls.toggle()
                    }
                    .help("Tools")
                    
                    Divider().frame(height: 20)
                    
                    RibbonButton(icon: copySuccess ? "checkmark" : "doc.on.doc", isActive: copySuccess) {
                        copyAllAsMarkdown()
                    }
                    .help("Copy MD")
                    
                    RibbonButton(icon: "square.and.arrow.down", isActive: false) {
                        showExportSheet = true
                    }
                    .help("Export")
                    
                    RibbonButton(icon: "arrow.left.arrow.right", isActive: false) {
                        showDiffSheet = true
                    }
                    .help("Compare")
                    
                    if appState.selectedCLI == .claude || appState.selectedCLI == .opencode || appState.selectedCLI == .antigravity {
                        Menu {
                            Section("Terminal") {
                                Button("Open") { executeResumeSession(session, terminal: .terminal, bypass: false, cliType: appState.selectedCLI) }
                                if appState.selectedCLI == .claude {
                                    Button("Bypass") { executeResumeSession(session, terminal: .terminal, bypass: true, cliType: appState.selectedCLI) }
                                }
                            }
                            Section("iTerm2") {
                                Button("Open") { executeResumeSession(session, terminal: .iterm, bypass: false, cliType: appState.selectedCLI) }
                                if appState.selectedCLI == .claude {
                                    Button("Bypass") { executeResumeSession(session, terminal: .iterm, bypass: true, cliType: appState.selectedCLI) }
                                }
                            }
                            Section("Warp") {
                                Button("Open") { executeResumeSession(session, terminal: .warp, bypass: false, cliType: appState.selectedCLI) }
                                if appState.selectedCLI == .claude {
                                    Button("Bypass") { executeResumeSession(session, terminal: .warp, bypass: true, cliType: appState.selectedCLI) }
                                }
                            }
                        } label: {
                            Image(systemName: "play.circle")
                                .font(.system(size: 12))
                                .frame(width: 28, height: 28)
                        }
                        .menuStyle(.borderlessButton)
                        .buttonStyle(.bordered)
                        .help("Resume")
                    }
                }
            }
            
            HStack(spacing: 12) {
                Label(session.projectName, systemImage: "folder")
                Label("\(session.messageCount)", systemImage: "bubble.left.and.bubble.right")
                Label(session.relativeTime, systemImage: "clock")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .sheet(isPresented: $showExportSheet) {
            ExportView(session: session, messages: messages)
        }
        .sheet(isPresented: $showDiffSheet) {
            SessionDiffView(baseSession: session)
        }
    }
    
    private func copyAllAsMarkdown() {
        let md = generateMarkdown()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)
        
        copySuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copySuccess = false
        }
    }
    
    private func downloadAsMarkdown() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]

        // Use custom display name with prefix/suffix
        let displayName = appState.getDisplayName(for: session)
        let fileName = generateFilename(displayName: displayName)
        panel.nameFieldStringValue = fileName

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let md = generateMarkdown()
                try? md.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    /// Generate filename with prefix, suffix and variable substitution
    private func generateFilename(displayName: String) -> String {
        let prefix = appState.settings.obsidianPrefix
        let suffix = appState.settings.obsidianSuffix

        // Process variables in prefix and suffix
        let processedPrefix = processFilenameVariables(prefix)
        let processedSuffix = processFilenameVariables(suffix)

        // Sanitize display name for filename
        let safeName = displayName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "\"", with: "")

        return "\(processedPrefix)\(safeName)\(processedSuffix).md"
    }

    /// Process template variables in filename parts
    private func processFilenameVariables(_ text: String) -> String {
        var result = text

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: Date())

        result = result.replacingOccurrences(of: "{{date}}", with: dateStr)
        result = result.replacingOccurrences(of: "{{time}}", with: timeStr)
        result = result.replacingOccurrences(of: "{{project}}", with: session.projectName)
        result = result.replacingOccurrences(of: "{{cli}}", with: appState.selectedCLI.rawValue)
        result = result.replacingOccurrences(of: "{{session}}", with: session.resumeId)
        result = result.replacingOccurrences(of: "{{messages}}", with: String(session.messageCount))

        return result
    }
    
    private func generateMarkdown() -> String {
        let agentName = appState.selectedCLI.rawValue
        let tags = appState.getTags(for: session.id)
        let displayName = appState.getDisplayName(for: session)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let now = dateFormatter.string(from: Date())
        let created = session.firstTimestamp.map { dateFormatter.string(from: $0) } ?? now
        
        var md = "---\n"
        md += "type: session\n"
        md += "aliases:\n"
        md += "  - \"\(displayName)\"\n"
        md += "date created: \(created)\n"
        md += "date modified: \(now)\n"
        md += "tags:\n"
        md += "  - CmdTrace\n"
        md += "  - \(agentName.replacingOccurrences(of: " ", with: ""))\n"
        for tag in tags {
            md += "  - \(tag)\n"
        }
        md += "session-id: \(session.id)\n"
        md += "project: \(session.projectName)\n"
        md += "messages: \(messages.isEmpty ? session.messageCount : messages.count)\n"
        md += "---\n\n"
        
        md += "# \(displayName)\n\n"
        
        for msg in messages {
            let role = msg.role == .user ? "**You**" : "**\(agentName)**"
            var roleInfo = role
            if msg.role == .assistant {
                var extras: [String] = []
                if let agent = msg.agentDisplayName { extras.append(agent) }
                if let model = msg.modelDisplayName { extras.append(model) }
                if !extras.isEmpty {
                    roleInfo = "\(role) (\(extras.joined(separator: " · ")))"
                }
            }
            md += "\(roleInfo):\n\n\(msg.content)\n\n---\n\n"
        }
        
        return md
    }
    
    private func generateTitle() async {
        isGeneratingTitle = true
        defer { isGeneratingTitle = false }

        let apiKey = appState.settings.anthropicKey
        guard !apiKey.isEmpty else { return }

        // Build conversation context from most recent messages
        let conversationText = messages.suffix(20).map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            return "\(role): \(msg.content.prefix(500))"
        }.joined(separator: "\n\n")

        let prompt = """
        이 코딩 세션 대화를 분석하여 다음을 생성해주세요:

        ## 생성 항목

        1. **타이틀** (title)
           - 핵심 작업/주제를 담은 간결한 제목
           - 한국어, 10-25자
           - 예: "SwiftUI 대시보드 차트 구현", "API 인증 버그 수정"

        2. **태그** (tags)
           - 세션의 주요 키워드를 태그로 추출
           - 3-5개의 태그
           - 기술 스택, 작업 유형, 주요 기능 등 포함
           - 예: ["SwiftUI", "Charts", "Dashboard", "버그수정"]

        3. **컨텍스트 요약** (summary)
           - 다음에 이어서 작업할 때 참고할 핵심 맥락
           - 한국어, 3-5문장
           - 반드시 포함할 내용:
             * 무슨 작업을 했는지 (What)
             * 어디까지 진행됐는지 (Progress)
             * 주요 결정사항이나 변경점 (Key Changes)
             * 다음에 해야 할 작업 힌트 (Next)

        ## 프로젝트 정보
        - 프로젝트: \(session.projectName)
        - 메시지 수: \(session.messageCount)개

        ## 대화 내용
        \(conversationText)

        ## 응답 형식 (JSON만 출력, 다른 텍스트 없이)
        {"title": "...", "tags": ["...", "..."], "summary": "..."}
        """

        // Use settings for model and parameters
        let model = appState.settings.effectiveAnthropicModel
        let maxTokens = appState.settings.aiMaxTokens
        let temperature = appState.settings.aiTemperature

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "messages": [["role": "user", "content": prompt]]
        ]

        guard let url = URL(string: "https://api.anthropic.com/v1/messages"),
              let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("API Error: HTTP \(httpResponse.statusCode)")
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Error details: \(errorJson)")
                }
                return
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String,
               let responseData = text.data(using: .utf8),
               let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {

                // 1. Set the generated title
                if let title = response["title"] as? String {
                    appState.setSessionName(title, for: session.id)
                }

                // 2. Add generated tags to session (sanitize: remove # prefix and spaces)
                if let tags = response["tags"] as? [String] {
                    for tag in tags {
                        var cleanTag = tag.hasPrefix("#") ? String(tag.dropFirst()) : tag
                        cleanTag = cleanTag.replacingOccurrences(of: " ", with: "") // No spaces allowed
                        if !cleanTag.isEmpty {
                            appState.addTag(cleanTag, to: session.id)
                        }
                    }
                }

                // 3. Save the summary
                if let summaryText = response["summary"] as? String {
                    let summary = SessionSummary(
                        sessionId: session.id,
                        summary: summaryText,
                        keyPoints: [],
                        suggestedNextSteps: [],
                        tags: response["tags"] as? [String] ?? [],
                        generatedAt: Date(),
                        provider: .anthropic
                    )
                    appState.saveSummary(summary)

                    // Copy summary to clipboard
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(summaryText, forType: .string)
                }
            }
        } catch {
            print("API Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Helper Views
struct RibbonButton: View {
    let icon: String
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
        .tint(isActive ? .accentColor : nil)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var font: Font = .system(size: 11)
    var truncate: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(font)
                .foregroundStyle(.secondary)
                .frame(minWidth: 80, alignment: .leading)
            Spacer(minLength: 8)
            Text(value)
                .font(font)
                .lineLimit(truncate ? 1 : 2)
                .truncationMode(.middle)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct ResumeButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 9))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.bordered)
    }
}

struct QuickActionButton: View {
    let label: String
    let icon: String
    var color: Color = .blue
    var isActive: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isActive ? color : .primary)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isActive ? color.opacity(0.12) : Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}

struct SectionHeader: View {
    let title: String
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.primary)
    }
}

/// Execute resume session in terminal (unified global function for all CLI types)
/// - Parameters:
///   - session: The session to resume
///   - terminal: Terminal type (Terminal.app, iTerm2, Warp)
///   - bypass: Whether to bypass permission checks (Claude Code only)
///   - cliType: The CLI tool type (Claude Code, OpenCode, Antigravity)
private func executeResumeSession(_ session: Session, terminal: TerminalType, bypass: Bool, cliType: CLITool) {
    let projectPath = session.project
    
    let resumeCommand: String
    switch cliType {
    case .claude:
        resumeCommand = bypass
            ? "claude -r \(session.resumeId) --dangerously-skip-permissions"
            : "claude -r \(session.resumeId)"
    case .opencode:
        resumeCommand = "opencode --resume \(session.resumeId)"
    case .antigravity:
        resumeCommand = "antigravity --resume \(session.resumeId)"
    }

    DispatchQueue.global(qos: .userInitiated).async {
        switch terminal {
        case .terminal:
            let script = """
            tell application "Terminal"
                activate
                do script "cd '\(projectPath)' && \(resumeCommand)"
            end tell
            """
            runOsascriptGlobal(script)

        case .iterm:
            let script = """
            tell application "iTerm2"
                activate
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text "cd '\(projectPath)' && \(resumeCommand)"
                end tell
            end tell
            """
            runOsascriptGlobal(script)

        case .warp:
            // Warp: 명령어만 복사 (cd 없이! Warp가 해당 디렉토리에서 열림)
            DispatchQueue.main.async {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(resumeCommand, forType: .string)
            }

            let openProcess = Process()
            openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            openProcess.arguments = ["-a", "Warp", projectPath]
            try? openProcess.run()
            openProcess.waitUntilExit()

            Thread.sleep(forTimeInterval: 0.5)

            let pasteScript = """
            tell application "System Events"
                tell process "Warp"
                    set frontmost to true
                    delay 1.0
                    keystroke "v" using command down
                    delay 0.2
                    key code 36
                end tell
            end tell
            """
            runOsascriptGlobal(pasteScript)
        }
    }
}

/// Global osascript runner (for use outside of view context)
private func runOsascriptGlobal(_ script: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]

    let pipe = Pipe()
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let errorOutput = String(data: data, encoding: .utf8) {
                print("osascript error (Inspector): \(errorOutput)")
            }
        }
    } catch {
        print("Failed to run osascript: \(error)")
    }
}

// MARK: - Inspector Panel
struct InspectorPanel: View {
    let session: Session
    @Environment(AppState.self) private var appState
    @State private var newTag = ""
    @State private var isGeneratingSummary = false
    @State private var summaryCopySuccess = false
    @State private var summaryError: String? = nil
    @State private var sessionInsights: SessionInsights? = nil
    @State private var isLoadingInsights = false
    @State private var sessionConfigUsage: SessionConfigUsage? = nil

    private let labelFont: Font = .system(size: 11)
    private let valueFont: Font = .system(size: 11)
    private let smallFont: Font = .system(size: 10)
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: - 1. Session Info
                SectionHeader("Session Info")
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow(label: "ID", value: session.id, font: smallFont, truncate: true)
                    InfoRow(label: "Project", value: session.projectName, font: labelFont)
                    InfoRow(label: "Messages", value: "\(session.messageCount)", font: labelFont)
                    
                    Divider().padding(.vertical, 2)
                    
                    if let firstTimestamp = session.firstTimestamp {
                        InfoRow(label: "First Message", value: firstTimestamp.formatted(date: .abbreviated, time: .shortened), font: labelFont)
                    }
                    InfoRow(label: "Last Message", value: session.lastActivity.formatted(date: .abbreviated, time: .shortened), font: labelFont)
                    
                    if let duration = session.duration {
                        HStack {
                            Text("Duration")
                                .font(labelFont)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(duration)
                                .font(labelFont)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    InfoRow(label: "Last Active", value: session.relativeTime, font: labelFont)
                }
                
                Divider()
                
                // MARK: - 2. Summary
                SectionHeader("컨텍스트 요약")
                VStack(alignment: .leading, spacing: 6) {
                    if let summary = appState.getSummary(for: session.id) {
                        MarkdownText(summary.summary)
                            .font(labelFont)

                        if !summary.keyPoints.isEmpty {
                            Text("핵심 포인트")
                                .font(labelFont)
                                .fontWeight(.medium)
                                .padding(.top, 4)
                            ForEach(summary.keyPoints, id: \.self) { point in
                                MarkdownText(point)
                                    .font(smallFont)
                            }
                        }

                        if !summary.suggestedNextSteps.isEmpty {
                            Text("다음 단계")
                                .font(labelFont)
                                .fontWeight(.medium)
                                .padding(.top, 4)
                            ForEach(summary.suggestedNextSteps, id: \.self) { step in
                                MarkdownText("• \(step)")
                                    .font(smallFont)
                            }
                        }

                        if !summary.tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(summary.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.top, 4)
                        }

                        Text("생성: \(summary.generatedAt.formatted())")
                            .font(smallFont)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                        
                        HStack(spacing: 6) {
                            Button {
                                copySummary(summary)
                            } label: {
                                Label(summaryCopySuccess ? "Copied!" : "Copy", systemImage: summaryCopySuccess ? "checkmark" : "doc.on.doc")
                                    .font(smallFont)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(summaryCopySuccess ? .green : nil)
                            
                            Button {
                                downloadSummary(summary)
                            } label: {
                                Label("Download", systemImage: "square.and.arrow.down")
                                    .font(smallFont)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.top, 4)
                    } else {
                        Text("아직 요약이 생성되지 않았습니다")
                            .font(labelFont)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Picker("", selection: Binding(
                            get: { appState.settings.summaryProvider },
                            set: { appState.settings.summaryProvider = $0 }
                        )) {
                            ForEach(AIProvider.allCases, id: \.self) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 100)

                        Spacer()

                        Button {
                            summaryError = nil
                            Task { await generateSummary() }
                        } label: {
                            Label(isGeneratingSummary ? "Generating..." : "Generate Summary", systemImage: "sparkles")
                                .font(labelFont)
                        }
                        .disabled(isGeneratingSummary || !appState.settings.hasSummaryProviderKey)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    if !appState.settings.hasSummaryProviderKey {
                        Label("\(appState.settings.summaryProviderKeyName) API 키 필요", systemImage: "exclamationmark.triangle.fill")
                            .font(smallFont)
                            .foregroundStyle(.orange)
                    }

                    if let error = summaryError {
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(smallFont)
                                .foregroundStyle(.red)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                
                Divider()
                
                // MARK: - 3. Tags
                SectionHeader("Tags")
                VStack(alignment: .leading, spacing: 6) {
                    let tags = appState.getTags(for: session.id)
                    if !tags.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(tags, id: \.self) { tag in
                                let tagInfo = appState.tagDatabase[tag]
                                let tagColor = tagInfo?.swiftUIColor ?? .blue
                                HStack(spacing: 3) {
                                    Button {
                                        appState.selectedTag = tag
                                        appState.sidebarViewMode = .list
                                        appState.filterSessions()
                                    } label: {
                                        Text(tag)
                                            .font(smallFont)
                                            .foregroundStyle(tagColor)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Filter by this tag")

                                    Button {
                                        appState.removeTag(tag, from: session.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove tag")
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(tagColor.opacity(0.15))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    
                    HStack(spacing: 6) {
                        TextField("Add tag (no spaces)", text: $newTag)
                            .textFieldStyle(.roundedBorder)
                            .font(smallFont)
                            .onSubmit { addTag() }
                            .onChange(of: newTag) { oldValue, newValue in
                                let sanitized = newValue.replacingOccurrences(of: " ", with: "")
                                if sanitized != newValue {
                                    newTag = sanitized
                                }
                            }

                        Button { addTag() } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                        }
                        .disabled(newTag.isEmpty)
                    }
                }
                
                Divider()
                
                // MARK: - 4. Quick Actions
                SectionHeader("Quick Actions")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    QuickActionButton(
                        label: appState.isFavorite(session.id) ? "Unfavorite" : "Favorite",
                        icon: appState.isFavorite(session.id) ? "star.fill" : "star",
                        color: .yellow,
                        isActive: appState.isFavorite(session.id)
                    ) {
                        appState.toggleFavorite(for: session.id)
                    }

                    QuickActionButton(
                        label: appState.isPinned(session.id) ? "Unpin" : "Pin",
                        icon: appState.isPinned(session.id) ? "pin.slash.fill" : "pin",
                        color: .orange,
                        isActive: appState.isPinned(session.id)
                    ) {
                        appState.togglePinned(for: session.id)
                    }

                    QuickActionButton(
                        label: "Copy ID",
                        icon: "doc.on.doc",
                        color: .blue
                    ) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(session.id, forType: .string)
                    }

                    QuickActionButton(
                        label: "Obsidian",
                        icon: "arrow.up.doc",
                        color: .purple,
                        disabled: appState.settings.obsidianVaultPath.isEmpty
                    ) {
                        sendToObsidian()
                    }
                    
                    QuickActionButton(
                        label: appState.isArchived(session.id) ? "Unarchive" : "Archive",
                        icon: appState.isArchived(session.id) ? "arrow.uturn.backward" : "archivebox",
                        color: .gray,
                        isActive: appState.isArchived(session.id)
                    ) {
                        appState.toggleArchive(for: session.id)
                    }
                }
                
                // MARK: - 5. Resume Session (Claude only)
                if appState.selectedCLI == .claude {
                    Divider()
                    
                    SectionHeader("Resume Session")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ResumeButton(label: "Terminal", icon: "terminal") {
                            executeResumeSession(session, terminal: .terminal, bypass: false, cliType: .claude)
                        }
                        ResumeButton(label: "Terminal+", icon: "terminal.fill") {
                            executeResumeSession(session, terminal: .terminal, bypass: true, cliType: .claude)
                        }
                        ResumeButton(label: "iTerm2", icon: "apple.terminal") {
                            executeResumeSession(session, terminal: .iterm, bypass: false, cliType: .claude)
                        }
                        ResumeButton(label: "iTerm2+", icon: "apple.terminal.fill") {
                            executeResumeSession(session, terminal: .iterm, bypass: true, cliType: .claude)
                        }
                        ResumeButton(label: "Warp", icon: "bolt.horizontal") {
                            executeResumeSession(session, terminal: .warp, bypass: false, cliType: .claude)
                        }
                        ResumeButton(label: "Warp+", icon: "bolt.horizontal.fill") {
                            executeResumeSession(session, terminal: .warp, bypass: true, cliType: .claude)
                        }
                    }
                }
                
                Divider()
                
                // MARK: - 6. Open in Finder
                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: session.project)
                } label: {
                    Label("Open in Finder", systemImage: "folder")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                // MARK: - 7. Additional Info (Session Insights, Config Usage)
                if appState.selectedCLI == .claude {
                    Divider()
                    
                    SectionHeader("Path")
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.project)
                                .font(smallFont)
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(session.project, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Divider()
                    
                    SessionInsightsSection(
                        session: session,
                        insights: sessionInsights,
                        isLoading: isLoadingInsights
                    )
                    
                    if let usage = sessionConfigUsage, !usage.isEmpty {
                        Divider()
                        
                        SessionConfigUsageSection(usage: usage)
                    }
                } else {
                    Divider()
                    
                    SectionHeader("Path")
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.project)
                                .font(smallFont)
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(session.project, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(12)
        }
        .task {
            await loadSessionInsights()
        }
        .onChange(of: session) { _, _ in
            Task { await loadSessionInsights() }
        }
    }
    
    private func loadSessionInsights() async {
        guard appState.selectedCLI == .claude else { return }
        
        isLoadingInsights = true
        defer { isLoadingInsights = false }
        
        let service = SessionService()
        do {
            sessionInsights = try await service.loadSessionInsights(for: session)
        } catch {
            sessionInsights = nil
        }
        
        let configService = ClaudeConfigService()
        sessionConfigUsage = await configService.loadSessionConfigUsage(for: session, agent: appState.agentType)
    }
    
    private func addTag() {
        // Obsidian tag format: no spaces allowed, only concatenated words
        var tag = newTag.trimmingCharacters(in: .whitespaces)
        // Remove all spaces (concatenate words)
        tag = tag.replacingOccurrences(of: " ", with: "")
        // Remove any invalid characters (keep alphanumeric, -, _, /, Korean)
        tag = tag.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "/" }

        if !tag.isEmpty {
            appState.addTag(tag, to: session.id)
            newTag = ""
        }
    }
    
    private func copySummary(_ summary: SessionSummary) {
        var text = "## Summary\n\n\(summary.summary)\n\n"
        if !summary.keyPoints.isEmpty {
            text += "## Key Points\n\n"
            for point in summary.keyPoints {
                text += "• \(point)\n"
            }
        }
        if !summary.suggestedNextSteps.isEmpty {
            text += "\n## Suggested Next Steps\n\n"
            for step in summary.suggestedNextSteps {
                text += "• \(step)\n"
            }
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        summaryCopySuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { summaryCopySuccess = false }
    }
    
    private func downloadSummary(_ summary: SessionSummary) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        let displayName = appState.getDisplayName(for: session)
        let safeName = displayName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        panel.nameFieldStringValue = "\(safeName)-summary.md"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                var text = "# \(displayName) - Summary\n\n"
                text += "Session ID: \(session.id)\n"
                text += "Project: \(session.projectName)\n"
                text += "Generated: \(summary.generatedAt.formatted())\n\n"
                text += "---\n\n"
                text += "## Summary\n\n\(summary.summary)\n\n"
                if !summary.keyPoints.isEmpty {
                    text += "## Key Points\n\n"
                    for point in summary.keyPoints {
                        text += "• \(point)\n"
                    }
                }
                if !summary.suggestedNextSteps.isEmpty {
                    text += "\n## Suggested Next Steps\n\n"
                    for step in summary.suggestedNextSteps {
                        text += "• \(step)\n"
                    }
                }
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func generateSummary() async {
        isGeneratingSummary = true
        defer { isGeneratingSummary = false }

        let provider = appState.settings.summaryProvider

        // Get API key based on selected provider
        let apiKey: String
        switch provider {
        case .openai: apiKey = appState.settings.openaiKey
        case .anthropic: apiKey = appState.settings.anthropicKey
        case .gemini: apiKey = appState.settings.geminiKey
        case .grok: apiKey = appState.settings.grokKey
        }

        guard !apiKey.isEmpty else {
            await MainActor.run { summaryError = "\(provider.rawValue) API 키가 설정되지 않았습니다" }
            return
        }

        // Load messages
        let service = SessionService()
        var messages: [Message] = []
        do {
            messages = try await service.loadMessages(for: session, agent: appState.agentType)
        } catch {
            await MainActor.run { summaryError = "메시지 로드 실패: \(error.localizedDescription)" }
            return
        }

        if messages.isEmpty {
            await MainActor.run { summaryError = "분석할 메시지가 없습니다" }
            return
        }

        // Use settings for source content range
        let maxMessages = appState.settings.contextMaxMessages
        let maxChars = appState.settings.contextMaxCharsPerMessage

        let conversationText = messages.suffix(maxMessages).map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            return "\(role): \(msg.content.prefix(maxChars))"
        }.joined(separator: "\n\n")

        let prompt = """
        \(appState.settings.contextPrompt)

        ## 프로젝트 정보
        - 프로젝트: \(session.projectName)
        - 메시지 수: \(session.messageCount)개
        - 분석 범위: 최근 \(min(messages.count, maxMessages))개 메시지 (각 \(maxChars)자 제한)

        ## 대화 내용
        \(conversationText)
        """

        let maxTokens = appState.settings.aiMaxTokens
        let temperature = appState.settings.aiTemperature

        // Build request based on provider
        var request: URLRequest
        do {
            request = try buildAPIRequest(provider: provider, apiKey: apiKey, prompt: prompt, maxTokens: maxTokens, temperature: temperature)
        } catch {
            await MainActor.run { summaryError = "요청 생성 실패: \(error.localizedDescription)" }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                var errorMsg = "HTTP \(httpResponse.statusCode)"
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = errorJson["error"] as? [String: Any], let message = error["message"] as? String {
                        errorMsg = message
                    } else if let message = errorJson["message"] as? String {
                        errorMsg = message
                    }
                }
                await MainActor.run { summaryError = "\(provider.rawValue) API 오류: \(errorMsg)" }
                return
            }

            // Parse response based on provider
            var responseText = try parseAPIResponse(provider: provider, data: data)

            // Extract JSON from markdown code blocks if present
            responseText = extractJSONFromMarkdown(responseText)

            // Try to parse as JSON first
            if let responseData = responseText.data(using: .utf8),
               let parsedResponse = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                processStructuredResponse(parsedResponse, provider: provider)
            }
            // Try partial JSON parsing for truncated responses
            else if let partialResponse = parsePartialJSON(responseText) {
                processStructuredResponse(partialResponse, provider: provider)
            } else {
                // Fallback: use raw text as summary (cleaned)
                let cleanedText = responseText
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let summary = SessionSummary(
                    sessionId: session.id,
                    summary: cleanedText,
                    keyPoints: [],
                    suggestedNextSteps: [],
                    tags: [],
                    generatedAt: Date(),
                    provider: provider
                )
                await MainActor.run { appState.saveSummary(summary) }
            }
        } catch {
            await MainActor.run { summaryError = "네트워크 오류: \(error.localizedDescription)" }
        }
    }

    private func buildAPIRequest(provider: AIProvider, apiKey: String, prompt: String, maxTokens: Int, temperature: Double) throws -> URLRequest {
        let url: URL
        var request: URLRequest
        let jsonData: Data

        switch provider {
        case .anthropic:
            url = URL(string: "https://api.anthropic.com/v1/messages")!
            let body: [String: Any] = [
                "model": appState.settings.effectiveAnthropicModel,
                "max_tokens": maxTokens,
                "messages": [["role": "user", "content": prompt]]
            ]
            jsonData = try JSONSerialization.data(withJSONObject: body)
            request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        case .openai:
            url = URL(string: "https://api.openai.com/v1/chat/completions")!
            // Some newer models (o-series, gpt-5) don't support temperature parameter
            var body: [String: Any] = [
                "model": appState.settings.effectiveOpenaiModel,
                "max_completion_tokens": maxTokens,
                "messages": [["role": "user", "content": prompt]]
            ]
            // Only add temperature if it's not 1.0 (some models only accept 1.0)
            let modelName = appState.settings.effectiveOpenaiModel.lowercased()
            let supportsTemperature = !modelName.contains("o1") && !modelName.contains("o3") && !modelName.hasPrefix("gpt-5")
            if supportsTemperature {
                body["temperature"] = temperature
            }
            jsonData = try JSONSerialization.data(withJSONObject: body)
            request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        case .gemini:
            let model = appState.settings.effectiveGeminiModel
            // Use v1 for stable models, v1beta for preview models
            let apiVersion = model.contains("preview") ? "v1beta" : "v1beta"
            url = URL(string: "https://generativelanguage.googleapis.com/\(apiVersion)/models/\(model):generateContent?key=\(apiKey)")!
            let body: [String: Any] = [
                "contents": [["parts": [["text": prompt]]]],
                "generationConfig": ["maxOutputTokens": maxTokens]
            ]
            jsonData = try JSONSerialization.data(withJSONObject: body)
            request = URLRequest(url: url)

        case .grok:
            url = URL(string: "https://api.x.ai/v1/chat/completions")!
            let body: [String: Any] = [
                "model": appState.settings.effectiveGrokModel,
                "max_tokens": maxTokens,
                "temperature": temperature,
                "messages": [["role": "user", "content": prompt]]
            ]
            jsonData = try JSONSerialization.data(withJSONObject: body)
            request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        return request
    }

    private func parseAPIResponse(provider: AIProvider, data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ParseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "JSON 파싱 실패"])
        }

        // Check for API error responses first
        if let error = json["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown error"
            let code = error["code"] as? Int ?? error["status"] as? Int ?? 0
            throw NSError(domain: "APIError", code: code, userInfo: [NSLocalizedDescriptionKey: "API 오류: \(message)"])
        }

        switch provider {
        case .anthropic:
            // Anthropic error format
            if let errorType = json["type"] as? String, errorType == "error" {
                let message = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                throw NSError(domain: "APIError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Anthropic 오류: \(message)"])
            }
            if let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                return text
            }
        case .openai, .grok:
            if let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
        case .gemini:
            // Gemini error format
            if let errorInfo = json["error"] as? [String: Any] {
                let message = errorInfo["message"] as? String ?? "Unknown error"
                let status = errorInfo["status"] as? String ?? "ERROR"
                throw NSError(domain: "APIError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Gemini 오류 (\(status)): \(message)"])
            }
            if let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                return text
            }
            // Check for blocked content
            if let promptFeedback = json["promptFeedback"] as? [String: Any],
               let blockReason = promptFeedback["blockReason"] as? String {
                throw NSError(domain: "APIError", code: 403, userInfo: [NSLocalizedDescriptionKey: "콘텐츠 차단됨: \(blockReason)"])
            }
        }

        // Debug: print the actual response structure
        let responseStr = String(data: data, encoding: .utf8) ?? "Unable to decode"
        print("API Response structure: \(responseStr.prefix(500))")

        throw NSError(domain: "ParseError", code: 2, userInfo: [NSLocalizedDescriptionKey: "응답에서 텍스트를 찾을 수 없음"])
    }

    /// Extract JSON from markdown code blocks (```json ... ``` or ``` ... ```)
    private func extractJSONFromMarkdown(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Pattern 1: ```json ... ``` (with closing)
        if let jsonMatch = result.range(of: "```json\\s*\\n?", options: .regularExpression),
           let endMatch = result.range(of: "\\n?```", options: .regularExpression, range: jsonMatch.upperBound..<result.endIndex) {
            result = String(result[jsonMatch.upperBound..<endMatch.lowerBound])
        }
        // Pattern 2: ```json without closing (truncated response)
        else if let jsonMatch = result.range(of: "```json\\s*\\n?", options: .regularExpression) {
            result = String(result[jsonMatch.upperBound...])
        }
        // Pattern 3: ``` ... ``` (without language specifier)
        else if result.hasPrefix("```") && result.hasSuffix("```") {
            result = String(result.dropFirst(3).dropLast(3))
            if let newlineIndex = result.firstIndex(of: "\n") {
                let firstLine = String(result[..<newlineIndex]).trimmingCharacters(in: .whitespaces)
                if firstLine.allSatisfy({ $0.isLetter }) {
                    result = String(result[result.index(after: newlineIndex)...])
                }
            }
        }
        // Pattern 4: ``` without closing (truncated)
        else if result.hasPrefix("```") {
            result = String(result.dropFirst(3))
            if let newlineIndex = result.firstIndex(of: "\n") {
                result = String(result[result.index(after: newlineIndex)...])
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse truncated or malformed JSON by extracting fields manually
    private func parsePartialJSON(_ text: String) -> [String: Any]? {
        var result: [String: Any] = [:]

        // Extract title
        if let titleMatch = text.range(of: "\"title\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            let match = String(text[titleMatch])
            if let valueStart = match.range(of: ":"),
               let firstQuote = match[valueStart.upperBound...].firstIndex(of: "\"") {
                let afterQuote = match.index(after: firstQuote)
                if let lastQuote = match[afterQuote...].firstIndex(of: "\"") {
                    result["title"] = String(match[afterQuote..<lastQuote])
                }
            }
        }

        // Extract tags array
        if let tagsStart = text.range(of: "\"tags\"\\s*:\\s*\\[", options: .regularExpression) {
            let afterBracket = text[tagsStart.upperBound...]
            if let closeBracket = afterBracket.firstIndex(of: "]") {
                let tagsContent = String(afterBracket[..<closeBracket])
                let tagPattern = "\"([^\"]+)\""
                var tags: [String] = []
                var searchRange = tagsContent.startIndex..<tagsContent.endIndex
                while let match = tagsContent.range(of: tagPattern, options: .regularExpression, range: searchRange) {
                    let tagWithQuotes = String(tagsContent[match])
                    let tag = tagWithQuotes.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    tags.append(tag)
                    searchRange = match.upperBound..<tagsContent.endIndex
                }
                result["tags"] = tags
            }
        }

        // Extract summary (may be truncated)
        if let summaryMatch = text.range(of: "\"summary\"\\s*:\\s*\"", options: .regularExpression) {
            let afterQuote = text[summaryMatch.upperBound...]
            // Find the end - either closing quote or end of string
            var summaryText = ""
            var escaped = false
            for char in afterQuote {
                if escaped {
                    summaryText.append(char)
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    break
                } else {
                    summaryText.append(char)
                }
            }
            if !summaryText.isEmpty {
                result["summary"] = summaryText
            }
        }

        return result.isEmpty ? nil : result
    }

    private func processStructuredResponse(_ response: [String: Any], provider: AIProvider) {
        // 1. Set the generated title
        if let title = response["title"] as? String {
            appState.setSessionName(title, for: session.id)
        }

        // 2. Add generated tags to session metadata (sanitize: remove # prefix and spaces)
        if let tags = response["tags"] as? [String] {
            for tag in tags {
                var cleanTag = tag.hasPrefix("#") ? String(tag.dropFirst()) : tag
                cleanTag = cleanTag.replacingOccurrences(of: " ", with: "") // No spaces allowed
                if !cleanTag.isEmpty {
                    appState.addTag(cleanTag, to: session.id)
                }
            }
        }

        // 3. Save the summary
        let summary = SessionSummary(
            sessionId: session.id,
            summary: response["summary"] as? String ?? "Summary generated",
            keyPoints: response["keyPoints"] as? [String] ?? [],
            suggestedNextSteps: response["nextSteps"] as? [String] ?? [],
            tags: response["tags"] as? [String] ?? [],
            generatedAt: Date(),
            provider: provider
        )
        appState.saveSummary(summary)
    }
    
    private func sendToObsidian() {
        let vaultPath = appState.settings.obsidianVaultPath
        guard !vaultPath.isEmpty else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let now = dateFormatter.string(from: Date())
        let created = session.firstTimestamp.map { dateFormatter.string(from: $0) } ?? now
        
        let displayName = appState.getDisplayName(for: session)
        let tags = appState.getTags(for: session.id)
        let cliName = appState.selectedCLI.rawValue
        let agentName = cliName.replacingOccurrences(of: " ", with: "")
        
        // Get project path
        let projectPath = session.project
        let projectName = session.projectName
        
        // Generate Hookmark deeplink for project path
        let hookmarkLink = generateHookmarkLink(for: projectPath, name: projectName)
        
        var md = "---\n"
        md += "type: session\n"
        md += "aliases:\n"
        md += "  - \"\(displayName)\"\n"
        md += "date created: \(created)\n"
        md += "date modified: \(now)\n"
        md += "tags:\n"
        md += "  - CmdTrace\n"
        md += "  - \(agentName)\n"
        for tag in tags {
            md += "  - \(tag)\n"
        }
        md += "session-id: \(session.id)\n"
        md += "agent: \"[[\(cliName)]]\"\n"
        md += "project: \(projectName)\n"
        md += "project-path: \"\(projectPath)\"\n"
        if let hookmark = hookmarkLink {
            md += "project-link: \"[\(projectName)](\(hookmark))\"\n"
        }
        md += "messages: \(session.messageCount)\n"
        md += "---\n\n"
        md += "# \(displayName)\n\n"
        md += "**Agent**: [[\(cliName)]]\n"
        md += "**Project**: \(projectName)\n"
        if let hookmark = hookmarkLink {
            md += "**Project Link**: [\(projectName)](\(hookmark))\n"
        }
        md += "**Path**: `\(projectPath)`\n"
        md += "**Messages**: \(session.messageCount)\n"
        md += "**Last Activity**: \(session.relativeTime)\n\n"
        
        if let summary = appState.getSummary(for: session.id) {
            md += "## Summary\n\n\(summary.summary)\n\n"
        }

        // Resume Commands section
        md += "## Resume Session\n\n"
        md += "터미널에서 이 세션을 이어서 진행하려면:\n\n"

        switch appState.selectedCLI {
        case .claude:
            md += "```bash\n"
            md += "# 기본 Resume\n"
            md += "cd \"\(projectPath)\"\n"
            md += "claude -r \(session.resumeId)\n"
            md += "```\n\n"
            md += "```bash\n"
            md += "# Bypass 모드 (권한 확인 건너뛰기)\n"
            md += "cd \"\(projectPath)\"\n"
            md += "claude -r \(session.resumeId) --dangerously-skip-permissions\n"
            md += "```\n\n"
        case .opencode:
            md += "```bash\n"
            md += "cd \"\(projectPath)\"\n"
            md += "opencode --resume \(session.resumeId)\n"
            md += "```\n\n"
        case .antigravity:
            md += "```bash\n"
            md += "cd \"\(projectPath)\"\n"
            md += "antigravity --resume \(session.resumeId)\n"
            md += "```\n\n"
        }

        md += "---\n\n"
        md += "*Exported from CmdTrace*\n"

        // Use filename with prefix/suffix
        let fileName = generateFilename(displayName: displayName)
        let filePath = URL(fileURLWithPath: vaultPath).appendingPathComponent(fileName)
        
        do {
            try md.write(to: filePath, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(filePath)
        } catch {
            print("Failed to write to Obsidian: \(error)")
        }
    }

    /// Generate filename with prefix, suffix and variable substitution
    private func generateFilename(displayName: String) -> String {
        let prefix = appState.settings.obsidianPrefix
        let suffix = appState.settings.obsidianSuffix

        // Process variables in prefix and suffix
        let processedPrefix = processFilenameVariables(prefix)
        let processedSuffix = processFilenameVariables(suffix)

        // Sanitize display name for filename
        let safeName = displayName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "\"", with: "")

        return "\(processedPrefix)\(safeName)\(processedSuffix).md"
    }

    /// Process template variables in filename parts
    private func processFilenameVariables(_ text: String) -> String {
        var result = text

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: Date())

        result = result.replacingOccurrences(of: "{{date}}", with: dateStr)
        result = result.replacingOccurrences(of: "{{time}}", with: timeStr)
        result = result.replacingOccurrences(of: "{{project}}", with: session.projectName)
        result = result.replacingOccurrences(of: "{{cli}}", with: appState.selectedCLI.rawValue)
        result = result.replacingOccurrences(of: "{{session}}", with: session.resumeId)
        result = result.replacingOccurrences(of: "{{messages}}", with: String(session.messageCount))

        return result
    }

    private func generateHookmarkLink(for path: String, name: String) -> String? {
        // Check if path exists
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        
        // Get the home directory to create relative path for encoding
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        var relativePath = path
        if path.hasPrefix(homeDir) {
            relativePath = String(path.dropFirst(homeDir.count + 1)) // +1 for the /
        }
        
        // Base64 encode the relative path (without padding, URL-safe)
        guard let pathData = relativePath.data(using: .utf8) else { return nil }
        let base64Path = pathData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        // URL encode the name
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        
        // Generate a simple file ID based on path hash
        let fileID = String(format: "%llX", path.hashValue & 0xFFFFFFFFFFFF)
        
        return "hook://file/\(fileID)?p=\(base64Path)&n=\(encodedName)"
    }
}



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
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 60) }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
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
                
                if appState.settings.renderMarkdown {
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

