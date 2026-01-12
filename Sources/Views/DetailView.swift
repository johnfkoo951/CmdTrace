import SwiftUI

struct DetailView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        switch appState.selectedTab {
        case .sessions:
            SessionDetailView()
        case .dashboard:
            DashboardView()
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
                .disabled(isGeneratingTitle || appState.settings.anthropicKey.isEmpty)
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
                        downloadAsMarkdown()
                    }
                    .help("Download")
                    
                    // Resume 버튼 - Claude Code, OpenCode, Antigravity 지원
                    if appState.selectedCLI == .claude || appState.selectedCLI == .opencode || appState.selectedCLI == .antigravity {
                        Menu {
                            Section("Terminal") {
                                Button("Open") { executeResume(.terminal, bypass: false) }
                                if appState.selectedCLI == .claude {
                                    Button("Bypass") { executeResume(.terminal, bypass: true) }
                                }
                            }
                            Section("iTerm2") {
                                Button("Open") { executeResume(.iterm, bypass: false) }
                                if appState.selectedCLI == .claude {
                                    Button("Bypass") { executeResume(.iterm, bypass: true) }
                                }
                            }
                            Section("Warp") {
                                Button("Open") { executeResume(.warp, bypass: false) }
                                if appState.selectedCLI == .claude {
                                    Button("Bypass") { executeResume(.warp, bypass: true) }
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
    }
    
    private func executeResume(_ terminal: TerminalType, bypass: Bool) {
        let projectPath = session.project

        // CLI별로 다른 명령어 생성
        let resumeCommand: String
        switch appState.selectedCLI {
        case .claude:
            resumeCommand = bypass
                ? "claude -r \(session.id) --dangerously-skip-permissions"
                : "claude -r \(session.id)"
        case .opencode:
            resumeCommand = "opencode -s \(session.id)"
        case .antigravity:
            resumeCommand = "antigravity --resume \(session.id)"
        }

        DispatchQueue.global(qos: .userInitiated).async {
            switch terminal {
            case .terminal:
                // osascript -e 방식 사용 (bash 스크립트와 동일)
                let script = """
                tell application "Terminal"
                    activate
                    do script "cd '\(projectPath)' && \(resumeCommand)"
                end tell
                """
                self.runOsascript(script)

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
                self.runOsascript(script)

            case .warp:
                // Warp: 명령어만 복사 (cd 없이! Warp가 해당 디렉토리에서 열림)
                DispatchQueue.main.async {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(resumeCommand, forType: .string)
                }

                // open -a Warp "path" - Warp가 해당 디렉토리에서 바로 열림
                let openProcess = Process()
                openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                openProcess.arguments = ["-a", "Warp", projectPath]
                try? openProcess.run()
                openProcess.waitUntilExit()

                // 잠시 대기 후 붙여넣기 실행
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
                self.runOsascript(pasteScript)
            }
        }
    }

    /// osascript 명령으로 AppleScript 실행
    private func runOsascript(_ script: String) {
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
                    print("osascript error: \(errorOutput)")
                }
            }
        } catch {
            print("Failed to run osascript: \(error)")
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
        panel.nameFieldStringValue = "\(session.id).md"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let md = generateMarkdown()
                try? md.write(to: url, atomically: true, encoding: .utf8)
            }
        }
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
        md += "author:\n"
        md += "  - \"[[구요한]]\"\n"
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
        
        // Build conversation context from first few messages
        let conversationText = messages.prefix(10).map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            return "\(role): \(msg.content.prefix(300))"
        }.joined(separator: "\n\n")
        
        let prompt = """
        이 코딩 세션 대화를 분석하여 다음을 생성해주세요:

        1. 타이틀: 핵심 작업/주제를 담은 간결한 제목 (한국어, 10-20자)
        2. 컨텍스트 요약: 다음 내용을 포함 (한국어, 2-3문장)
           - 무슨 작업을 했는지
           - 어디까지 진행됐는지
           - 다음에 이어서 할 때 참고할 핵심 맥락

        프로젝트: \(session.projectName)

        대화 내용:
        \(conversationText)

        JSON 형식으로 응답:
        {"title": "...", "summary": "..."}
        """
        
        let requestBody: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 512,
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
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String,
               let responseData = text.data(using: .utf8),
               let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                
                // Set the generated title
                if let title = response["title"] as? String {
                    appState.setSessionName(title, for: session.id)
                }
                
                // Also save the summary if generated
                if let summaryText = response["summary"] as? String {
                    let summary = SessionSummary(
                        sessionId: session.id,
                        summary: summaryText,
                        keyPoints: [],
                        suggestedNextSteps: [],
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
            // Silently fail - user can try again
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
        HStack {
            Text(label)
                .font(font)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(font)
                .lineLimit(truncate ? 1 : nil)
                .truncationMode(.middle)
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

private func executeResumeInspector(_ session: Session, terminal: TerminalType, bypass: Bool) {
    let projectPath = session.project
    let resumeCommand = bypass
        ? "claude -r \(session.id) --dangerously-skip-permissions"
        : "claude -r \(session.id)"

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
    
    private let labelFont: Font = .system(size: 11)
    private let valueFont: Font = .system(size: 11)
    private let smallFont: Font = .system(size: 10)
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                    
                    Divider().padding(.vertical, 2)
                    
                    HStack {
                        Text("Path")
                            .font(labelFont)
                            .foregroundStyle(.secondary)
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
                    Text(session.project)
                        .font(smallFont)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                
                Divider()
                
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

                    if appState.settings.anthropicKey.isEmpty {
                        Label("설정 → AI에서 API 키를 입력하세요", systemImage: "exclamationmark.triangle.fill")
                            .font(smallFont)
                            .foregroundStyle(.orange)
                    }
                    
                    Button {
                        Task { await generateSummary() }
                    } label: {
                        Label(isGeneratingSummary ? "Generating..." : "Generate Summary", systemImage: "sparkles")
                            .font(labelFont)
                    }
                    .disabled(isGeneratingSummary || appState.settings.anthropicKey.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 4)
                }
                
                Divider()
                
                SectionHeader("Tags")
                VStack(alignment: .leading, spacing: 6) {
                    let tags = appState.getTags(for: session.id)
                    if !tags.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(tags, id: \.self) { tag in
                                HStack(spacing: 3) {
                                    Text(tag)
                                        .font(smallFont)
                                    Button {
                                        appState.removeTag(tag, from: session.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 9))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.blue.opacity(0.15))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    
                    HStack(spacing: 6) {
                        TextField("Add tag", text: $newTag)
                            .textFieldStyle(.roundedBorder)
                            .font(smallFont)
                            .onSubmit { addTag() }
                        
                        Button { addTag() } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                        }
                        .disabled(newTag.isEmpty)
                    }
                }
                
                Divider()
                
                SectionHeader("Quick Actions")
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        appState.toggleFavorite(for: session.id)
                    } label: {
                        Label(appState.isFavorite(session.id) ? "Remove from Favorites" : "Add to Favorites",
                              systemImage: appState.isFavorite(session.id) ? "star.fill" : "star")
                            .font(labelFont)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        appState.togglePinned(for: session.id)
                    } label: {
                        Label(appState.isPinned(session.id) ? "Unpin" : "Pin to Top",
                              systemImage: appState.isPinned(session.id) ? "pin.slash" : "pin")
                            .font(labelFont)
                    }
                    .buttonStyle(.plain)
                    
                    Divider().padding(.vertical, 2)
                    
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(session.id, forType: .string)
                    } label: {
                        Label("Copy Session ID", systemImage: "doc.on.doc")
                            .font(labelFont)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        sendToObsidian()
                    } label: {
                        Label("Send to Obsidian", systemImage: "arrow.up.doc")
                            .font(labelFont)
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.settings.obsidianVaultPath.isEmpty)
                }
                
                if appState.selectedCLI == .claude {
                    Divider()
                    
                    SectionHeader("Resume Session")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ResumeButton(label: "Terminal", icon: "terminal") {
                            executeResumeInspector(session, terminal: .terminal, bypass: false)
                        }
                        ResumeButton(label: "Terminal+", icon: "terminal.fill") {
                            executeResumeInspector(session, terminal: .terminal, bypass: true)
                        }
                        ResumeButton(label: "iTerm2", icon: "apple.terminal") {
                            executeResumeInspector(session, terminal: .iterm, bypass: false)
                        }
                        ResumeButton(label: "iTerm2+", icon: "apple.terminal.fill") {
                            executeResumeInspector(session, terminal: .iterm, bypass: true)
                        }
                        ResumeButton(label: "Warp", icon: "bolt.horizontal") {
                            executeResumeInspector(session, terminal: .warp, bypass: false)
                        }
                        ResumeButton(label: "Warp+", icon: "bolt.horizontal.fill") {
                            executeResumeInspector(session, terminal: .warp, bypass: true)
                        }
                    }
                }
                
                Divider()
                
                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: session.project)
                } label: {
                    Label("Open in Finder", systemImage: "folder")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(12)
        }
    }
    
    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces)
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
        
        let apiKey = appState.settings.anthropicKey
        guard !apiKey.isEmpty else {
            isGeneratingSummary = false
            return
        }
        
        let service = SessionService()
        var messages: [Message] = []
        do {
            messages = try await service.loadMessages(for: session, agent: appState.agentType)
        } catch {
            isGeneratingSummary = false
            return
        }
        
        let conversationText = messages.prefix(50).map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            return "\(role): \(msg.content.prefix(500))"
        }.joined(separator: "\n\n")
        
        let prompt = """
        이 코딩 세션 대화를 분석하여 다음을 한국어로 생성해주세요.

        **마크다운 포맷 필수 사용:**
        - **굵은 글씨**로 핵심 키워드 강조
        - 불렛포인트(-)로 목록 정리
        - 위계 구조 활용 (들여쓰기)
        - 관련 #태그 자유롭게 추가 (예: #버그수정 #SwiftUI #리팩토링)

        1. 세션 요약 (2-3문장)
           - 어떤 작업을 진행했는지
           - 현재 진행 상황/완료 여부

        2. 핵심 포인트 (3-5개)
           - 주요 결정사항, 변경된 파일, 해결한 문제 등

        3. 다음 단계 (2-3개)
           - 이 세션을 이어서 작업할 때 해야 할 것들
           - 미완료 작업이나 확인 필요한 사항

        대화 내용:
        \(conversationText)

        JSON 형식으로 응답 (각 값에 마크다운 포맷 포함):
        {"summary": "...", "keyPoints": ["- **키워드** 설명...", "..."], "nextSteps": ["...", "..."], "tags": ["#태그1", "#태그2"]}
        """
        
        let requestBody: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ]
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages"),
              let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            isGeneratingSummary = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String,
               let responseData = text.data(using: .utf8),
               let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                
                let summary = SessionSummary(
                    sessionId: session.id,
                    summary: response["summary"] as? String ?? "Summary generated",
                    keyPoints: response["keyPoints"] as? [String] ?? [],
                    suggestedNextSteps: response["nextSteps"] as? [String] ?? [],
                    tags: response["tags"] as? [String] ?? [],
                    generatedAt: Date(),
                    provider: .anthropic
                )
                appState.saveSummary(summary)

                // 클립보드에 마크다운 포맷으로 복사
                var clipboardText = "## 요약\n\(summary.summary)\n\n"
                if !summary.keyPoints.isEmpty {
                    clipboardText += "## 핵심 포인트\n" + summary.keyPoints.joined(separator: "\n") + "\n\n"
                }
                if !summary.suggestedNextSteps.isEmpty {
                    clipboardText += "## 다음 단계\n" + summary.suggestedNextSteps.map { "- \($0)" }.joined(separator: "\n") + "\n\n"
                }
                if !summary.tags.isEmpty {
                    clipboardText += "## 태그\n" + summary.tags.joined(separator: " ") + "\n"
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(clipboardText, forType: .string)
            }
        } catch {
            let fallbackSummary = SessionSummary(
                sessionId: session.id,
                summary: "\(session.displayTitle) 세션. 총 \(session.messageCount)개의 메시지 포함.",
                keyPoints: ["API 호출 실패 - 기본 요약 사용"],
                suggestedNextSteps: ["설정에서 API 키 확인"],
                generatedAt: Date(),
                provider: .anthropic
            )
            appState.saveSummary(fallbackSummary)
        }
        
        isGeneratingSummary = false
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
        
        md += "---\n\n"
        md += "*Exported from Agent Archives*\n"
        
        let safeName = displayName.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "\(safeName).md"
        let filePath = URL(fileURLWithPath: vaultPath).appendingPathComponent(fileName)
        
        do {
            try md.write(to: filePath, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(filePath)
        } catch {
            print("Failed to write to Obsidian: \(error)")
        }
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



// MARK: - Message Bubble
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
                    MarkdownText(message.content)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(bubbleColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text(message.content)
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

// MARK: - Dashboard View
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var usageData: UsageData?
    @State private var isLoadingUsage = false
    
    private var totalMessages: Int {
        appState.sessions.reduce(0) { $0 + $1.messageCount }
    }
    
    private var uniqueProjects: Int {
        Set(appState.sessions.map { $0.project }).count
    }
    
    private var todaySessions: Int {
        let calendar = Calendar.current
        return appState.sessions.filter { calendar.isDateInToday($0.lastActivity) }.count
    }
    
    private var projectStats: [(project: String, sessions: Int, messages: Int)] {
        let grouped = Dictionary(grouping: appState.sessions) { $0.projectName }
        return grouped.map { (project: $0.key, sessions: $0.value.count, messages: $0.value.reduce(0) { $0 + $1.messageCount }) }
            .sorted { $0.sessions > $1.sessions }
            .prefix(10)
            .map { $0 }
    }
    
    private var recentActivity: [(date: String, count: Int)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        let calendar = Calendar.current
        
        var activity: [String: Int] = [:]
        for i in 0..<14 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            activity[formatter.string(from: date)] = 0
        }
        
        for session in appState.sessions {
            let key = formatter.string(from: session.lastActivity)
            if activity[key] != nil {
                activity[key]! += 1
            }
        }
        
        return activity.sorted { 
            formatter.date(from: $0.key)! > formatter.date(from: $1.key)!
        }.reversed().map { ($0.key, $0.value) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(title: "Sessions", value: "\(appState.sessions.count)", icon: "bubble.left.and.bubble.right", color: .blue)
                    StatCard(title: "Messages", value: formatNumber(totalMessages), icon: "text.bubble", color: .purple)
                    StatCard(title: "Projects", value: "\(uniqueProjects)", icon: "folder", color: .orange)
                    StatCard(title: "Today", value: "\(todaySessions)", icon: "sun.max", color: .yellow)
                }
                
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activity (14 days)")
                            .font(.headline)
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(recentActivity, id: \.date) { item in
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.blue.opacity(0.8))
                                        .frame(width: 24, height: max(4, CGFloat(item.count) * 8))
                                    Text(item.date)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(height: 120, alignment: .bottom)
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Projects")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            ForEach(projectStats.prefix(8), id: \.project) { stat in
                                HStack {
                                    Text(stat.project)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(stat.sessions)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if appState.selectedCLI == .claude {
                    UsageSection(usageData: $usageData, isLoading: $isLoadingUsage)
                }
            }
            .padding()
        }
        .task {
            if appState.selectedCLI == .claude {
                await loadUsageData()
            }
        }
    }
    
    private func loadUsageData() async {
        isLoadingUsage = true
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["python3", "-c", """
        import json
        try:
            from ccusage import get_usage
            usage = get_usage(days=14)
            print(json.dumps(usage))
        except:
            print('{}')
        """]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let jsonData = output.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                usageData = UsageData(from: json)
            }
        } catch {}
        
        isLoadingUsage = false
    }
    
    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000.0)
        }
        return "\(n)"
    }
}

// MARK: - Dashboard Inspector Panel
struct DashboardInspectorPanel: View {
    @Environment(AppState.self) private var appState
    
    private var tagStats: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for (_, meta) in appState.sessionMetadata {
            for tag in meta.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
    
    private var favoriteCount: Int {
        appState.sessionMetadata.values.filter { $0.isFavorite }.count
    }
    
    private var pinnedCount: Int {
        appState.sessionMetadata.values.filter { $0.isPinned }.count
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Overview") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("CLI", value: appState.selectedCLI.rawValue)
                        LabeledContent("Total Sessions", value: "\(appState.sessions.count)")
                        LabeledContent("Favorites", value: "\(favoriteCount)")
                        LabeledContent("Pinned", value: "\(pinnedCount)")
                    }
                    .font(.caption)
                }
                
                GroupBox("Tag Distribution") {
                    VStack(alignment: .leading, spacing: 8) {
                        if tagStats.isEmpty {
                            Text("No tags yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(tagStats.prefix(10), id: \.tag) { stat in
                                HStack {
                                    if let tagInfo = appState.tagDatabase[stat.tag] {
                                        Circle()
                                            .fill(tagInfo.swiftUIColor)
                                            .frame(width: 8, height: 8)
                                    }
                                    Text(stat.tag)
                                        .font(.caption)
                                    Spacer()
                                    Text("\(stat.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                GroupBox("Display Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Chart Range", selection: .constant(14)) {
                            Text("7 days").tag(7)
                            Text("14 days").tag(14)
                            Text("30 days").tag(30)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .padding()
        }
    }
}

struct UsageSection: View {
    @Binding var usageData: UsageData?
    @Binding var isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Usage")
                .font(.headline)
            
            if isLoading {
                ProgressView()
            } else if let data = usageData {
                HStack(spacing: 16) {
                    StatCard(title: "Cost", value: String(format: "$%.2f", data.totalCost), icon: "dollarsign.circle", color: .green)
                    StatCard(title: "Input", value: formatTokens(data.inputTokens), icon: "arrow.down.circle", color: .blue)
                    StatCard(title: "Output", value: formatTokens(data.outputTokens), icon: "arrow.up.circle", color: .purple)
                }
            } else {
                Text("Install ccusage for usage data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000.0)
        } else if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000.0)
        }
        return "\(n)"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Interaction View (AI Features)
struct InteractionView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Session Summaries", systemImage: "doc.text.magnifyingglass")
                            .font(.headline)
                        
                        Text("AI-powered summaries of your coding sessions. Get key insights and suggestions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if appState.settings.anthropicKey.isEmpty {
                            Text("Configure API keys in Settings to enable AI features")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Smart Suggestions", systemImage: "lightbulb")
                            .font(.headline)
                        
                        Text("Get AI-powered suggestions based on your recent sessions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ForEach(0..<3, id: \.self) { i in
                            HStack {
                                Image(systemName: "sparkle")
                                    .foregroundStyle(.yellow)
                                Text("Suggestion placeholder \(i + 1)")
                                    .font(.subheadline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Session Reminders", systemImage: "bell")
                            .font(.headline)
                        
                        Toggle("Enable reminders", isOn: .constant(appState.settings.enableReminders))
                        
                        Text("Get reminded about sessions you haven't revisited in \(appState.settings.reminderHours) hours.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
    }
}

// MARK: - AI Inspector Panel
struct AIInspectorPanel: View {
    @Environment(AppState.self) private var appState
    
    private var summaryCount: Int {
        appState.sessionSummaries.count
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("AI Configuration") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Summary Provider") {
                            Picker("", selection: .constant(appState.settings.summaryProvider)) {
                                ForEach(AIProvider.allCases, id: \.self) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }
                        
                        LabeledContent("Suggestion Provider") {
                            Picker("", selection: .constant(appState.settings.suggestionProvider)) {
                                ForEach(AIProvider.allCases, id: \.self) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }
                    }
                    .font(.caption)
                }
                
                GroupBox("API Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        APIStatusRow(name: "Anthropic", hasKey: !appState.settings.anthropicKey.isEmpty)
                        APIStatusRow(name: "OpenAI", hasKey: !appState.settings.openaiKey.isEmpty)
                        APIStatusRow(name: "Gemini", hasKey: !appState.settings.geminiKey.isEmpty)
                        APIStatusRow(name: "Grok", hasKey: !appState.settings.grokKey.isEmpty)
                    }
                }
                
                GroupBox("Summaries") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Generated", value: "\(summaryCount)")
                        
                        if summaryCount > 0 {
                            Button("Clear All Summaries") {
                                // TODO: Implement clear
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    }
                    .font(.caption)
                }
                
                GroupBox("Reminders") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enable", isOn: .constant(appState.settings.enableReminders))
                            .font(.caption)
                        
                        LabeledContent("Interval") {
                            Picker("", selection: .constant(appState.settings.reminderHours)) {
                                Text("12 hours").tag(12)
                                Text("24 hours").tag(24)
                                Text("48 hours").tag(48)
                                Text("72 hours").tag(72)
                            }
                            .labelsHidden()
                            .frame(width: 100)
                        }
                        .font(.caption)
                    }
                }
            }
            .padding()
        }
    }
}

struct APIStatusRow: View {
    let name: String
    let hasKey: Bool
    
    var body: some View {
        HStack {
            Image(systemName: hasKey ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(hasKey ? .green : .secondary)
            Text(name)
                .font(.caption)
            Spacer()
            Text(hasKey ? "Configured" : "Not set")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Supporting Types
struct UsageData {
    let totalCost: Double
    let inputTokens: Int
    let outputTokens: Int
    let dailyUsage: [DailyUsage]
    var maxDailyCost: Double { dailyUsage.map { $0.cost }.max() ?? 1.0 }
    
    struct DailyUsage {
        let date: String
        let cost: Double
    }
    
    init(from json: [String: Any]) {
        totalCost = json["total_cost"] as? Double ?? 0
        inputTokens = json["input_tokens"] as? Int ?? 0
        outputTokens = json["output_tokens"] as? Int ?? 0
        
        if let daily = json["daily"] as? [[String: Any]] {
            dailyUsage = daily.compactMap { day in
                guard let date = day["date"] as? String,
                      let cost = day["cost"] as? Double else { return nil }
                return DailyUsage(date: date, cost: cost)
            }
        } else {
            dailyUsage = []
        }
    }
}

// MARK: - Markdown Text View
struct MarkdownText: View {
    let content: String

    init(_ content: String) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                        Text(attributed)
                            .font(.body)
                    } else {
                        Text(text)
                            .font(.body)
                    }
                case .code(let code, let language):
                    VStack(alignment: .leading, spacing: 4) {
                        if !language.isEmpty {
                            Text(language)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(code)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(10)
                        }
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                case .heading(let text, let level):
                    Text(text)
                        .font(level == 1 ? .title2.bold() : level == 2 ? .title3.bold() : .headline)
                        .padding(.top, level == 1 ? 8 : 4)
                case .listItem(let text, let indent):
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                            Text(attributed)
                                .font(.body)
                        } else {
                            Text(text)
                                .font(.body)
                        }
                    }
                    .padding(.leading, CGFloat(indent * 16))
                case .quote(let text):
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(.blue.opacity(0.5))
                            .frame(width: 3)
                        Text(text)
                            .font(.body)
                            .italic()
                            .foregroundStyle(.secondary)
                            .padding(.leading, 10)
                    }
                case .table(let rows, let headers):
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header row
                            if !headers.isEmpty {
                                HStack(spacing: 0) {
                                    ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                                        Text(header)
                                            .font(.caption.bold())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .frame(minWidth: 80, alignment: .leading)
                                            .background(Color(nsColor: .controlBackgroundColor))
                                    }
                                }
                                Divider()
                            }

                            // Data rows
                            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                                HStack(spacing: 0) {
                                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                        Text(cell)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .frame(minWidth: 80, alignment: .leading)
                                    }
                                }
                                .background(rowIndex % 2 == 0 ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.3))
                            }
                        }
                    }
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
                }
            }
        }
    }

    private enum Block {
        case text(String)
        case code(String, String) // code, language
        case heading(String, Int) // text, level
        case listItem(String, Int) // text, indent level
        case quote(String)
        case table([[String]], [String]) // rows, headers
    }

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        let lines = content.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Code block
            if line.hasPrefix("```") {
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.code(codeLines.joined(separator: "\n"), language))
                i += 1
                continue
            }

            // Heading
            if line.hasPrefix("#") {
                let level = line.prefix(while: { $0 == "#" }).count
                let text = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                if level <= 6 && !text.isEmpty {
                    blocks.append(.heading(text, level))
                    i += 1
                    continue
                }
            }

            // List item
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") ||
               line.trimmingCharacters(in: .whitespaces).hasPrefix("* ") {
                let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count / 2
                let text = line.trimmingCharacters(in: .whitespaces).dropFirst(2).trimmingCharacters(in: .whitespaces)
                blocks.append(.listItem(String(text), indent))
                i += 1
                continue
            }

            // Quote
            if line.hasPrefix("> ") {
                let text = String(line.dropFirst(2))
                blocks.append(.quote(text))
                i += 1
                continue
            }

            // Table - lines starting with |
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                var tableLines: [String] = []
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    tableLines.append(lines[i])
                    i += 1
                }

                if tableLines.count >= 2 {
                    // Parse header row
                    let headers = parseTableRow(tableLines[0])

                    // Skip separator row (|---|---|)
                    var dataStartIndex = 1
                    if tableLines.count > 1 && tableLines[1].contains("---") {
                        dataStartIndex = 2
                    }

                    // Parse data rows
                    var rows: [[String]] = []
                    for j in dataStartIndex..<tableLines.count {
                        let cells = parseTableRow(tableLines[j])
                        if !cells.isEmpty {
                            rows.append(cells)
                        }
                    }

                    blocks.append(.table(rows, headers))
                }
                continue
            }

            // Regular text - accumulate consecutive non-special lines
            var textLines: [String] = []
            while i < lines.count {
                let currentLine = lines[i]
                if currentLine.hasPrefix("```") || currentLine.hasPrefix("#") ||
                   currentLine.trimmingCharacters(in: .whitespaces).hasPrefix("- ") ||
                   currentLine.trimmingCharacters(in: .whitespaces).hasPrefix("* ") ||
                   currentLine.hasPrefix("> ") ||
                   currentLine.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    break
                }
                textLines.append(currentLine)
                i += 1
            }

            let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.text(text))
            }
        }

        return blocks
    }

    private func parseTableRow(_ line: String) -> [String] {
        var cells: [String] = []
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Remove leading and trailing pipes
        var content = trimmed
        if content.hasPrefix("|") {
            content = String(content.dropFirst())
        }
        if content.hasSuffix("|") {
            content = String(content.dropLast())
        }

        // Split by | and trim each cell
        let parts = content.components(separatedBy: "|")
        for part in parts {
            cells.append(part.trimmingCharacters(in: .whitespaces))
        }

        return cells
    }
}

#Preview {
    DetailView()
        .environment(AppState())
}
