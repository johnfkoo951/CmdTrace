import SwiftUI
import Charts

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
    @State private var summaryError: String? = nil

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

                    // Provider selector
                    HStack {
                        Text("Provider")
                            .font(smallFont)
                            .foregroundStyle(.secondary)
                        Spacer()
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
                    }

                    if !appState.settings.hasSummaryProviderKey {
                        Label("\(appState.settings.summaryProviderKeyName) API 키 필요", systemImage: "exclamationmark.triangle.fill")
                            .font(smallFont)
                            .foregroundStyle(.orange)
                    }

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
                    .padding(.top, 4)

                    // Error display
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
                
                SectionHeader("Tags")
                VStack(alignment: .leading, spacing: 6) {
                    let tags = appState.getTags(for: session.id)
                    if !tags.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(tags, id: \.self) { tag in
                                let tagInfo = appState.tagDatabase[tag]
                                let tagColor = tagInfo?.swiftUIColor ?? .blue
                                HStack(spacing: 3) {
                                    // Clickable tag name - filters sessions
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

                                    // Remove button
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
                                // Remove spaces in real-time as user types
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
                await processStructuredResponse(parsedResponse, provider: provider)
            }
            // Try partial JSON parsing for truncated responses
            else if let partialResponse = parsePartialJSON(responseText) {
                await processStructuredResponse(partialResponse, provider: provider)
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
                "temperature": temperature,
                "messages": [["role": "user", "content": prompt]]
            ]
            jsonData = try JSONSerialization.data(withJSONObject: body)
            request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2025-01-01", forHTTPHeaderField: "anthropic-version")  // Updated for Claude 4.5+ models

        case .openai:
            url = URL(string: "https://api.openai.com/v1/chat/completions")!
            let body: [String: Any] = [
                "model": appState.settings.effectiveOpenaiModel,
                "max_completion_tokens": maxTokens,  // Updated for newer models (o-series, GPT-4o+)
                "temperature": temperature,
                "messages": [["role": "user", "content": prompt]]
            ]
            jsonData = try JSONSerialization.data(withJSONObject: body)
            request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        case .gemini:
            let model = appState.settings.effectiveGeminiModel
            url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
            let body: [String: Any] = [
                "contents": [["parts": [["text": prompt]]]],
                "generationConfig": ["temperature": temperature, "maxOutputTokens": maxTokens]
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

    @MainActor
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
            md += "claude -r \(session.id)\n"
            md += "```\n\n"
            md += "```bash\n"
            md += "# Bypass 모드 (권한 확인 건너뛰기)\n"
            md += "cd \"\(projectPath)\"\n"
            md += "claude -r \(session.id) --dangerously-skip-permissions\n"
            md += "```\n\n"
        case .opencode:
            md += "```bash\n"
            md += "cd \"\(projectPath)\"\n"
            md += "opencode --resume \(session.id)\n"
            md += "```\n\n"
        case .antigravity:
            md += "```bash\n"
            md += "cd \"\(projectPath)\"\n"
            md += "antigravity --resume \(session.id)\n"
            md += "```\n\n"
        }

        md += "---\n\n"
        md += "*Exported from CmdTrace*\n"
        
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
                    UsageToolsSection()
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

        // Run ccusage for daily, monthly, and blocks data
        let result = await Task.detached(priority: .userInitiated) { () -> UsageData? in
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

            func runCcusage(_ command: String, outputFile: String) -> [String: Any]? {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/zsh")
                let script = """
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
                ccusage \(command) --json -o desc > "\(outputFile)" 2>&1
                """
                task.arguments = ["-c", script]
                task.currentDirectoryURL = URL(fileURLWithPath: homeDir)

                do {
                    try task.run()
                    let deadline = Date().addingTimeInterval(15)
                    while task.isRunning && Date() < deadline {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    if task.isRunning {
                        task.terminate()
                        return nil
                    }

                    if let output = try? String(contentsOfFile: outputFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                       !output.isEmpty,
                       let jsonData = output.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        try? FileManager.default.removeItem(atPath: outputFile)
                        return json
                    }
                } catch {}
                return nil
            }

            // Load all three types of data
            let dailyJson = runCcusage("daily", outputFile: "\(homeDir)/.cmdtrace-daily.json")
            let monthlyJson = runCcusage("monthly", outputFile: "\(homeDir)/.cmdtrace-monthly.json")
            let blocksJson = runCcusage("blocks", outputFile: "\(homeDir)/.cmdtrace-blocks.json")

            if dailyJson != nil || monthlyJson != nil || blocksJson != nil {
                return UsageData(dailyJson: dailyJson, monthlyJson: monthlyJson, blocksJson: blocksJson)
            }
            return nil
        }.value

        usageData = result
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
    @State private var viewMode: UsageViewMode = .daily
    @State private var showAll = false
    @State private var selectedItemForBreakdown: String?
    @State private var selectedPlan: ClaudePlan = .max20
    @State private var showNativeMonitor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("API Usage")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                // claude-monitor menu
                Menu {
                    Section("플랜 선택") {
                        ForEach(ClaudePlan.allCases, id: \.self) { plan in
                            Button {
                                selectedPlan = plan
                            } label: {
                                HStack {
                                    Text(plan.displayName)
                                    if selectedPlan == plan {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    Divider()
                    Button {
                        launchClaudeMonitor(plan: selectedPlan, view: "realtime")
                    } label: {
                        Label("실시간 모니터링", systemImage: "waveform.path.ecg")
                    }
                    Button {
                        launchClaudeMonitor(plan: selectedPlan, view: "daily")
                    } label: {
                        Label("일일 리포트", systemImage: "calendar")
                    }
                    Button {
                        launchClaudeMonitor(plan: selectedPlan, view: "monthly")
                    } label: {
                        Label("월간 리포트", systemImage: "calendar.badge.clock")
                    }
                    Button {
                        launchClaudeMonitor(plan: selectedPlan, view: "session")
                    } label: {
                        Label("세션별 리포트", systemImage: "clock.arrow.circlepath")
                    }
                    Divider()
                    Button {
                        showNativeMonitor = true
                    } label: {
                        Label("내장 모니터링", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    }
                } label: {
                    Label("모니터링 (\(selectedPlan.shortName))", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .sheet(isPresented: $showNativeMonitor) {
                NativeMonitorView(plan: selectedPlan)
            }

            if let data = usageData {
                // Summary Cards
                HStack(spacing: 12) {
                    UsageStatCard(title: "총 비용", value: String(format: "$%.2f", data.totalCost), icon: "dollarsign.circle", color: .green)
                    UsageStatCard(title: "총 토큰", value: formatTokens(data.totalTokens), icon: "number.circle", color: .blue)
                    UsageStatCard(title: "캐시 히트", value: formatTokens(data.cacheReadTokens), icon: "bolt.circle", color: .orange)
                }

                // View Mode Picker
                Picker("View", selection: $viewMode) {
                    ForEach(UsageViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                // Content based on mode
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(viewMode.rawValue + " 사용량")
                            .font(.subheadline.bold())
                        Spacer()
                        Button(showAll ? "접기" : "전체 보기") {
                            withAnimation { showAll.toggle() }
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }

                    switch viewMode {
                    case .daily:
                        let items = showAll ? data.dailyUsage : Array(data.dailyUsage.prefix(7))
                        ForEach(items) { day in
                            DailyUsageRow(day: day, maxCost: data.maxDailyCost, isExpanded: selectedItemForBreakdown == day.date) {
                                withAnimation { selectedItemForBreakdown = selectedItemForBreakdown == day.date ? nil : day.date }
                            }
                        }

                    case .monthly:
                        let items = showAll ? data.monthlyUsage : Array(data.monthlyUsage.prefix(6))
                        ForEach(items) { month in
                            MonthlyUsageRow(month: month, maxCost: data.maxMonthlyCost, isExpanded: selectedItemForBreakdown == month.month) {
                                withAnimation { selectedItemForBreakdown = selectedItemForBreakdown == month.month ? nil : month.month }
                            }
                        }

                    case .blocks:
                        let items = showAll ? data.blockUsage : Array(data.blockUsage.prefix(10))
                        ForEach(items) { block in
                            BlockUsageRow(block: block, maxCost: data.maxBlockCost)
                        }
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if !isLoading {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("ccusage 실행 실패 - npm install -g ccusage로 설치하세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
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

    private func launchClaudeMonitor(plan: ClaudePlan, view: String? = nil) {
        // Build claude-monitor command with options
        var command = "claude-monitor --plan \(plan.rawValue)"
        if let view = view {
            command += " --view \(view)"
        }

        // Launch in Terminal
        let script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

// MARK: - Claude Plan Enum
enum ClaudePlan: String, CaseIterable {
    case pro = "pro"
    case max5 = "max5"
    case max20 = "max20"

    var displayName: String {
        switch self {
        case .pro: return "Pro ($18/월, 19K 토큰)"
        case .max5: return "Max5 ($35/월, 88K 토큰)"
        case .max20: return "Max20 ($140/월, 220K 토큰)"
        }
    }

    var shortName: String {
        switch self {
        case .pro: return "Pro"
        case .max5: return "Max5"
        case .max20: return "Max20"
        }
    }
}

struct UsageStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct DailyUsageRow: View {
    let day: UsageData.DailyUsage
    let maxCost: Double
    var isExpanded: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                // Expand button
                if !day.modelBreakdowns.isEmpty {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }

                // Date
                Text(formatDate(day.date))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)

                // Cost bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.quaternary)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.cost > 5 ? .orange : .blue)
                            .frame(width: max(4, geo.size.width * CGFloat(day.cost / maxCost)))
                    }
                }
                .frame(height: 8)

                // Cost value
                Text(String(format: "$%.2f", day.cost))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(day.cost > 5 ? .orange : .primary)
                    .frame(width: 50, alignment: .trailing)

                // Models
                HStack(spacing: 4) {
                    ForEach(day.modelsUsed, id: \.self) { model in
                        Text(shortModelName(model))
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(modelColor(model).opacity(0.2))
                            .foregroundStyle(modelColor(model))
                            .clipShape(Capsule())
                    }
                }
                .frame(width: 100, alignment: .trailing)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            // Model Breakdown (expanded)
            if isExpanded && !day.modelBreakdowns.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(day.modelBreakdowns) { breakdown in
                        ModelBreakdownRow(breakdown: breakdown)
                    }
                }
                .padding(.leading, 24)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let components = dateString.split(separator: "-")
        if components.count >= 3 {
            return "\(components[1])/\(components[2])"
        }
        return dateString
    }

    private func shortModelName(_ model: String) -> String {
        if model.contains("opus") { return "Opus" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("haiku") { return "Haiku" }
        return String(model.prefix(6))
    }

    private func modelColor(_ model: String) -> Color {
        if model.contains("opus") { return .purple }
        if model.contains("sonnet") { return .blue }
        if model.contains("haiku") { return .green }
        return .gray
    }
}

// MARK: - Monthly Usage Row
struct MonthlyUsageRow: View {
    let month: UsageData.MonthlyUsage
    let maxCost: Double
    var isExpanded: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                // Expand button
                if !month.modelBreakdowns.isEmpty {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }

                // Month
                Text(formatMonth(month.month))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)

                // Cost bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.quaternary)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(month.cost > 50 ? .red : month.cost > 20 ? .orange : .blue)
                            .frame(width: max(4, geo.size.width * CGFloat(month.cost / maxCost)))
                    }
                }
                .frame(height: 8)

                // Cost value
                Text(String(format: "$%.2f", month.cost))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(month.cost > 50 ? .red : month.cost > 20 ? .orange : .primary)
                    .frame(width: 55, alignment: .trailing)

                // Models
                HStack(spacing: 4) {
                    ForEach(month.modelsUsed.prefix(3), id: \.self) { model in
                        Text(shortModelName(model))
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(modelColor(model).opacity(0.2))
                            .foregroundStyle(modelColor(model))
                            .clipShape(Capsule())
                    }
                }
                .frame(width: 100, alignment: .trailing)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            // Model Breakdown (expanded)
            if isExpanded && !month.modelBreakdowns.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(month.modelBreakdowns) { breakdown in
                        ModelBreakdownRow(breakdown: breakdown)
                    }
                }
                .padding(.leading, 24)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func formatMonth(_ monthString: String) -> String {
        // "2025-12" -> "25/12"
        let components = monthString.split(separator: "-")
        if components.count >= 2 {
            let year = String(components[0].suffix(2))
            return "\(year)/\(components[1])"
        }
        return monthString
    }

    private func shortModelName(_ model: String) -> String {
        if model.contains("opus") { return "Opus" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("haiku") { return "Haiku" }
        return String(model.prefix(6))
    }

    private func modelColor(_ model: String) -> Color {
        if model.contains("opus") { return .purple }
        if model.contains("sonnet") { return .blue }
        if model.contains("haiku") { return .green }
        return .gray
    }
}

// MARK: - Block Usage Row (5-hour rolling window)
struct BlockUsageRow: View {
    let block: UsageData.BlockUsage
    let maxCost: Double

    var body: some View {
        HStack(spacing: 12) {
            // Active indicator
            Circle()
                .fill(block.isActive ? .green : .gray.opacity(0.3))
                .frame(width: 8, height: 8)

            // Time range
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(block.startTime))
                    .font(.system(size: 10, design: .monospaced))
                Text(formatTime(block.endTime))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 70, alignment: .leading)

            // Cost bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(block.isActive ? .green : .blue)
                        .frame(width: max(4, geo.size.width * CGFloat(block.cost / maxCost)))
                }
            }
            .frame(height: 8)

            // Cost value
            Text(String(format: "$%.3f", block.cost))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(block.isActive ? .green : .primary)
                .frame(width: 55, alignment: .trailing)

            // Models
            HStack(spacing: 4) {
                ForEach(block.models.prefix(2), id: \.self) { model in
                    Text(shortModelName(model))
                        .font(.system(size: 9))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(modelColor(model).opacity(0.2))
                        .foregroundStyle(modelColor(model))
                        .clipShape(Capsule())
                }
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ timeString: String) -> String {
        // "2025-12-13T10:00:00" -> "12/13 10:00"
        let parts = timeString.split(separator: "T")
        if parts.count == 2 {
            let dateParts = parts[0].split(separator: "-")
            let timeParts = parts[1].split(separator: ":")
            if dateParts.count >= 3 && timeParts.count >= 2 {
                return "\(dateParts[1])/\(dateParts[2]) \(timeParts[0]):\(timeParts[1])"
            }
        }
        return timeString
    }

    private func shortModelName(_ model: String) -> String {
        if model.contains("opus") { return "Opus" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("haiku") { return "Haiku" }
        return String(model.prefix(6))
    }

    private func modelColor(_ model: String) -> Color {
        if model.contains("opus") { return .purple }
        if model.contains("sonnet") { return .blue }
        if model.contains("haiku") { return .green }
        return .gray
    }
}

// MARK: - Model Breakdown Row
struct ModelBreakdownRow: View {
    let breakdown: UsageData.ModelBreakdown

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(modelColor(breakdown.modelName))
                .frame(width: 6, height: 6)

            Text(shortModelName(breakdown.modelName))
                .font(.system(size: 10, weight: .medium))
                .frame(width: 50, alignment: .leading)

            Text("In: \(formatTokens(breakdown.inputTokens))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("Out: \(formatTokens(breakdown.outputTokens))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Text(String(format: "$%.2f", breakdown.cost))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(modelColor(breakdown.modelName))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000.0)
        } else if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000.0)
        }
        return "\(n)"
    }

    private func shortModelName(_ model: String) -> String {
        if model.contains("opus") { return "Opus" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("haiku") { return "Haiku" }
        return String(model.prefix(8))
    }

    private func modelColor(_ model: String) -> Color {
        if model.contains("opus") { return .purple }
        if model.contains("sonnet") { return .blue }
        if model.contains("haiku") { return .green }
        return .gray
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

// MARK: - Usage Tools Section
struct UsageToolsSection: View {
    @State private var copiedCommand: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("사용량 분석 도구")
                    .font(.headline)
                Spacer()
                Link(destination: URL(string: "https://github.com/ryoppippi/ccusage")!) {
                    Image(systemName: "link")
                        .font(.caption)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                // ccusage Card
                UsageToolCard(
                    name: "ccusage",
                    description: "가볍고 빠른 CLI 보고서 도구",
                    language: "Node.js",
                    languageColor: .green,
                    commands: [
                        ("설치/실행", "npx ccusage@latest"),
                        ("일일 리포트", "npx ccusage daily"),
                        ("월간 리포트", "npx ccusage monthly"),
                        ("5시간 블록", "npx ccusage blocks"),
                        ("모델별 분석", "npx ccusage daily --breakdown")
                    ],
                    githubURL: "https://github.com/ryoppippi/ccusage",
                    copiedCommand: $copiedCommand
                )

                // claude-monitor Card
                UsageToolCard(
                    name: "claude-monitor",
                    description: "실시간 모니터링 + ML 예측",
                    language: "Python",
                    languageColor: .blue,
                    commands: [
                        ("설치 (uv)", "uv tool install claude-monitor"),
                        ("설치 (pip)", "pip install claude-monitor"),
                        ("실행", "claude-monitor"),
                        ("Pro 플랜", "claude-monitor --plan pro"),
                        ("Max5 플랜", "claude-monitor --plan max5")
                    ],
                    githubURL: "https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor",
                    copiedCommand: $copiedCommand
                )
            }

            // Quick Reference
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("플랜별 토큰 한도")
                        .font(.caption.bold())

                    HStack(spacing: 24) {
                        PlanBadge(name: "Pro", tokens: "19K", cost: "$18")
                        PlanBadge(name: "Max5", tokens: "88K", cost: "$35")
                        PlanBadge(name: "Max20", tokens: "220K", cost: "$140")
                    }

                    Divider()

                    Text("5시간 롤링 세션 윈도우 - 첫 메시지 전송 시 세션 시작, 5시간 후 만료")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct UsageToolCard: View {
    let name: String
    let description: String
    let language: String
    let languageColor: Color
    let commands: [(label: String, command: String)]
    let githubURL: String
    @Binding var copiedCommand: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name)
                    .font(.subheadline.bold())

                Text(language)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(languageColor.opacity(0.2))
                    .foregroundStyle(languageColor)
                    .clipShape(Capsule())

                Spacer()

                Link(destination: URL(string: githubURL)!) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(commands, id: \.command) { item in
                    HStack(spacing: 8) {
                        Text(item.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)

                        Text(item.command)
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)

                        Spacer()

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.command, forType: .string)
                            copiedCommand = item.command

                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if copiedCommand == item.command {
                                    copiedCommand = nil
                                }
                            }
                        } label: {
                            Image(systemName: copiedCommand == item.command ? "checkmark" : "doc.on.doc")
                                .font(.caption2)
                                .foregroundStyle(copiedCommand == item.command ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PlanBadge: View {
    let name: String
    let tokens: String
    let cost: String

    var body: some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption.bold())
            Text(tokens)
                .font(.caption2)
                .foregroundStyle(.blue)
            Text(cost)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 60)
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
enum UsageViewMode: String, CaseIterable {
    case daily = "일일"
    case monthly = "월간"
    case blocks = "5시간 블록"
}

struct UsageData {
    let totalCost: Double
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalTokens: Int
    let dailyUsage: [DailyUsage]
    let monthlyUsage: [MonthlyUsage]
    let blockUsage: [BlockUsage]
    var maxDailyCost: Double { dailyUsage.map { $0.cost }.max() ?? 1.0 }
    var maxMonthlyCost: Double { monthlyUsage.map { $0.cost }.max() ?? 1.0 }
    var maxBlockCost: Double { blockUsage.map { $0.cost }.max() ?? 1.0 }

    struct DailyUsage: Identifiable {
        let id = UUID()
        let date: String
        let cost: Double
        let inputTokens: Int
        let outputTokens: Int
        let totalTokens: Int
        let modelsUsed: [String]
        let modelBreakdowns: [ModelBreakdown]
    }

    struct MonthlyUsage: Identifiable {
        let id = UUID()
        let month: String
        let cost: Double
        let inputTokens: Int
        let outputTokens: Int
        let totalTokens: Int
        let modelsUsed: [String]
        let modelBreakdowns: [ModelBreakdown]
    }

    struct BlockUsage: Identifiable {
        let id = UUID()
        let blockId: String
        let startTime: String
        let endTime: String
        let isActive: Bool
        let cost: Double
        let totalTokens: Int
        let models: [String]
    }

    struct ModelBreakdown: Identifiable {
        let id = UUID()
        let modelName: String
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationTokens: Int
        let cacheReadTokens: Int
        let cost: Double
    }

    static func parseModelBreakdowns(_ breakdowns: [[String: Any]]?) -> [ModelBreakdown] {
        guard let breakdowns = breakdowns else { return [] }
        return breakdowns.map { b in
            ModelBreakdown(
                modelName: b["modelName"] as? String ?? "",
                inputTokens: b["inputTokens"] as? Int ?? 0,
                outputTokens: b["outputTokens"] as? Int ?? 0,
                cacheCreationTokens: b["cacheCreationTokens"] as? Int ?? 0,
                cacheReadTokens: b["cacheReadTokens"] as? Int ?? 0,
                cost: b["cost"] as? Double ?? 0
            )
        }
    }

    init(dailyJson: [String: Any]?, monthlyJson: [String: Any]?, blocksJson: [String: Any]?) {
        var totalCostSum: Double = 0
        var totalInputTokens: Int = 0
        var totalOutputTokens: Int = 0
        var totalCacheCreation: Int = 0
        var totalCacheRead: Int = 0
        var allTokens: Int = 0
        var dailyList: [DailyUsage] = []
        var monthlyList: [MonthlyUsage] = []
        var blockList: [BlockUsage] = []

        // Parse daily data
        if let daily = dailyJson?["daily"] as? [[String: Any]] {
            for day in daily {
                let date = day["date"] as? String ?? ""
                let cost = day["totalCost"] as? Double ?? 0
                let input = day["inputTokens"] as? Int ?? 0
                let output = day["outputTokens"] as? Int ?? 0
                let cacheCreation = day["cacheCreationTokens"] as? Int ?? 0
                let cacheRead = day["cacheReadTokens"] as? Int ?? 0
                let tokens = day["totalTokens"] as? Int ?? 0
                let models = day["modelsUsed"] as? [String] ?? []
                let breakdowns = Self.parseModelBreakdowns(day["modelBreakdowns"] as? [[String: Any]])

                totalCostSum += cost
                totalInputTokens += input
                totalOutputTokens += output
                totalCacheCreation += cacheCreation
                totalCacheRead += cacheRead
                allTokens += tokens

                dailyList.append(DailyUsage(
                    date: date, cost: cost, inputTokens: input, outputTokens: output,
                    totalTokens: tokens, modelsUsed: models, modelBreakdowns: breakdowns
                ))
            }
        }

        // Parse monthly data
        if let monthly = monthlyJson?["monthly"] as? [[String: Any]] {
            for month in monthly {
                let monthStr = month["month"] as? String ?? ""
                let cost = month["totalCost"] as? Double ?? 0
                let input = month["inputTokens"] as? Int ?? 0
                let output = month["outputTokens"] as? Int ?? 0
                let tokens = month["totalTokens"] as? Int ?? 0
                let models = month["modelsUsed"] as? [String] ?? []
                let breakdowns = Self.parseModelBreakdowns(month["modelBreakdowns"] as? [[String: Any]])

                monthlyList.append(MonthlyUsage(
                    month: monthStr, cost: cost, inputTokens: input, outputTokens: output,
                    totalTokens: tokens, modelsUsed: models, modelBreakdowns: breakdowns
                ))
            }
        }

        // Parse blocks data
        if let blocks = blocksJson?["blocks"] as? [[String: Any]] {
            for block in blocks {
                let blockId = block["id"] as? String ?? ""
                let startTime = block["startTime"] as? String ?? ""
                let endTime = block["endTime"] as? String ?? ""
                let isActive = block["isActive"] as? Bool ?? false
                let cost = block["costUSD"] as? Double ?? 0
                let tokens = block["totalTokens"] as? Int ?? 0
                let models = block["models"] as? [String] ?? []

                blockList.append(BlockUsage(
                    blockId: blockId, startTime: startTime, endTime: endTime,
                    isActive: isActive, cost: cost, totalTokens: tokens, models: models
                ))
            }
        }

        self.totalCost = totalCostSum
        self.inputTokens = totalInputTokens
        self.outputTokens = totalOutputTokens
        self.cacheCreationTokens = totalCacheCreation
        self.cacheReadTokens = totalCacheRead
        self.totalTokens = allTokens
        self.dailyUsage = dailyList
        self.monthlyUsage = monthlyList
        self.blockUsage = blockList
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

// MARK: - Native Monitor View
struct NativeMonitorView: View {
    let plan: ClaudePlan
    @State private var monitorData: MonitorData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var refreshTimer: Timer?
    @State private var refreshInterval: Double = 10.0
    @Environment(\.dismiss) private var dismiss

    // Customizable colors
    @State private var costBarColor: Color = .orange
    @State private var tokenBarColor: Color = .green
    @State private var messageBarColor: Color = .blue
    @State private var warningColor: Color = .red
    @State private var showColorPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("실시간 모니터링")
                        .font(.headline)
                    Text("\(plan.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Refresh interval
                HStack(spacing: 4) {
                    Text("새로고침:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $refreshInterval) {
                        Text("5초").tag(5.0)
                        Text("10초").tag(10.0)
                        Text("30초").tag(30.0)
                        Text("60초").tag(60.0)
                    }
                    .labelsHidden()
                    .frame(width: 70)
                    .onChange(of: refreshInterval) { _, _ in
                        setupTimer()
                    }
                }

                Button {
                    showColorPicker.toggle()
                } label: {
                    Image(systemName: "paintpalette")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showColorPicker) {
                    ColorCustomizationView(
                        costBarColor: $costBarColor,
                        tokenBarColor: $tokenBarColor,
                        messageBarColor: $messageBarColor,
                        warningColor: $warningColor
                    )
                }

                Button {
                    Task { await loadData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.regularMaterial)

            Divider()

            if isLoading && monitorData == nil {
                Spacer()
                ProgressView("데이터 로딩 중...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("다시 시도") {
                        Task { await loadData() }
                    }
                }
                Spacer()
            } else if let data = monitorData {
                ScrollView {
                    VStack(spacing: 20) {
                        // Plan Info
                        HStack {
                            Label(plan.shortName, systemImage: "person.badge.shield.checkmark")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("리셋까지: \(data.timeToReset)")
                                .font(.caption.monospaced())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(data.timeToResetMinutes < 30 ? warningColor.opacity(0.2) : Color.gray.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal)
                        .padding(.top)

                        // Usage Bars
                        VStack(spacing: 16) {
                            MonitorBarView(
                                title: "비용 사용량",
                                icon: "dollarsign.circle",
                                current: data.currentCost,
                                limit: data.costLimit,
                                formatValue: { String(format: "$%.2f", $0) },
                                barColor: costBarColor,
                                warningThreshold: 0.8
                            )

                            MonitorBarView(
                                title: "토큰 사용량",
                                icon: "number.circle",
                                current: Double(data.currentTokens),
                                limit: Double(data.tokenLimit),
                                formatValue: { formatTokensShort(Int($0)) },
                                barColor: tokenBarColor,
                                warningThreshold: 0.8
                            )

                            MonitorBarView(
                                title: "메시지 사용량",
                                icon: "message.circle",
                                current: Double(data.currentMessages),
                                limit: Double(data.messageLimit),
                                formatValue: { "\(Int($0))" },
                                barColor: messageBarColor,
                                warningThreshold: 0.8
                            )
                        }
                        .padding(.horizontal)

                        Divider()

                        // Model Distribution
                        if !data.modelDistribution.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("모델 분포")
                                    .font(.subheadline.bold())

                                HStack(spacing: 4) {
                                    ForEach(data.modelDistribution, id: \.model) { dist in
                                        GeometryReader { geo in
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(modelColor(dist.model))
                                                .frame(width: geo.size.width * CGFloat(dist.percentage / 100.0))
                                        }
                                    }
                                }
                                .frame(height: 20)
                                .background(.quaternary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                                HStack(spacing: 16) {
                                    ForEach(data.modelDistribution, id: \.model) { dist in
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(modelColor(dist.model))
                                                .frame(width: 8, height: 8)
                                            Text("\(shortModelName(dist.model)) \(String(format: "%.1f%%", dist.percentage))")
                                                .font(.caption2)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        Divider()

                        // Burn Rate & Predictions
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("🔥 번 레이트")
                                    .font(.caption.bold())
                                Text(String(format: "%.1f 토큰/분", data.burnRate))
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(data.burnRate > 100 ? warningColor : .primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.quaternary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("⏰ 예측")
                                    .font(.caption.bold())
                                if let exhaustTime = data.tokenExhaustionTime {
                                    Text("소진: \(exhaustTime)")
                                        .font(.caption)
                                        .foregroundStyle(warningColor)
                                } else {
                                    Text("충분한 여유")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                                Text("리셋: \(data.resetTime)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.quaternary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal)

                        Divider()

                        // Burn Rate Prediction Chart
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("📈 소비 예측 그래프")
                                    .font(.subheadline.bold())
                                Spacer()
                                if data.projectedTotalCost > 0 {
                                    Text("예상: $\(String(format: "%.2f", data.projectedTotalCost))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            BurnRateChartView(
                                currentTokens: data.currentTokens,
                                tokenLimit: data.tokenLimit,
                                currentCost: data.currentCost,
                                costLimit: data.costLimit,
                                burnRate: data.burnRate,
                                costPerHour: data.costPerHour,
                                remainingMinutes: data.timeToResetMinutes,
                                tokenBarColor: tokenBarColor,
                                costBarColor: costBarColor,
                                warningColor: warningColor
                            )
                            .frame(height: 200)
                        }
                        .padding(.horizontal)

                        // Last updated
                        HStack {
                            Spacer()
                            Text("마지막 업데이트: \(data.lastUpdated)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
        }
        .frame(width: 500, height: 700)
        .task {
            await loadData()
            setupTimer()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
    }

    private func setupTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { await loadData() }
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        // Use ccusage blocks --active for real-time 5-hour window data (same as claude-monitor)
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("ccusage_blocks_\(UUID().uuidString).json")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "ccusage blocks --active --json --breakdown 2>/dev/null > '\(tempFile.path)'"]

        do {
            try process.run()
            process.waitUntilExit()

            if FileManager.default.fileExists(atPath: tempFile.path) {
                let jsonData = try Data(contentsOf: tempFile)

                guard !jsonData.isEmpty else {
                    await MainActor.run {
                        self.errorMessage = "ccusage가 데이터를 반환하지 않았습니다"
                        self.isLoading = false
                    }
                    return
                }

                if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let blocks = json["blocks"] as? [[String: Any]],
                   let activeBlock = blocks.first(where: { $0["isActive"] as? Bool == true }) ?? blocks.last {

                    let cost = activeBlock["costUSD"] as? Double ?? 0
                    let tokens = activeBlock["totalTokens"] as? Int ?? 0
                    let models = activeBlock["models"] as? [String] ?? []

                    // Get burn rate from ccusage
                    let burnRateData = activeBlock["burnRate"] as? [String: Any]
                    let tokensPerMinute = burnRateData?["tokensPerMinute"] as? Double ?? 0
                    let costPerHour = burnRateData?["costPerHour"] as? Double ?? 0

                    // Get projection data
                    let projection = activeBlock["projection"] as? [String: Any]
                    let remainingMinutes = projection?["remainingMinutes"] as? Int ?? 0
                    let projectedTotalCost = projection?["totalCost"] as? Double ?? 0

                    // Calculate time to reset
                    let hours = remainingMinutes / 60
                    let mins = remainingMinutes % 60
                    let timeToReset = "\(hours)h \(mins)m"

                    // Get end time for reset time display
                    let endTimeStr = activeBlock["endTime"] as? String ?? ""
                    let resetTimeDisplay: String
                    if let endDate = ISO8601DateFormatter().date(from: endTimeStr) {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        resetTimeDisplay = formatter.string(from: endDate)
                    } else {
                        resetTimeDisplay = "--:--"
                    }

                    // Model distribution (simplified - equal distribution for now)
                    let modelDist = models.enumerated().map { index, model in
                        MonitorData.ModelDist(
                            model: model.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-20251101", with: ""),
                            percentage: 100.0 / Double(max(1, models.count))
                        )
                    }

                    // Calculate exhaustion time
                    var exhaustionTime: String? = nil
                    if tokensPerMinute > 0 {
                        let tokenLimit = plan.tokenLimit
                        let remaining = tokenLimit - tokens
                        if remaining > 0 && remaining < tokenLimit {
                            let minutesUntilExhaustion = Double(remaining) / tokensPerMinute
                            if minutesUntilExhaustion < Double(remainingMinutes) {
                                let exhaustionDate = Date().addingTimeInterval(minutesUntilExhaustion * 60)
                                let formatter = DateFormatter()
                                formatter.dateFormat = "HH:mm"
                                exhaustionTime = formatter.string(from: exhaustionDate)
                            }
                        }
                    }

                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm:ss"
                    let lastUpdatedStr = formatter.string(from: Date())

                    await MainActor.run {
                        self.monitorData = MonitorData(
                            currentCost: cost,
                            costLimit: plan.costLimit,
                            currentTokens: tokens,
                            tokenLimit: plan.tokenLimit,
                            currentMessages: activeBlock["entries"] as? Int ?? 0,
                            messageLimit: plan.messageLimit,
                            timeToReset: timeToReset,
                            timeToResetMinutes: remainingMinutes,
                            burnRate: tokensPerMinute,
                            costPerHour: costPerHour,
                            projectedTotalCost: projectedTotalCost,
                            tokenExhaustionTime: exhaustionTime,
                            resetTime: resetTimeDisplay,
                            modelDistribution: modelDist,
                            lastUpdated: lastUpdatedStr
                        )
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.monitorData = MonitorData(
                            currentCost: 0,
                            costLimit: plan.costLimit,
                            currentTokens: 0,
                            tokenLimit: plan.tokenLimit,
                            currentMessages: 0,
                            messageLimit: plan.messageLimit,
                            timeToReset: "활성 블록 없음",
                            timeToResetMinutes: 300,
                            burnRate: 0,
                            costPerHour: 0,
                            projectedTotalCost: 0,
                            tokenExhaustionTime: nil,
                            resetTime: "--:--",
                            modelDistribution: [],
                            lastUpdated: DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                        )
                        self.isLoading = false
                    }
                }
                try? FileManager.default.removeItem(at: tempFile)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "ccusage 실행 실패: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func formatTokensShort(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000.0)
        } else if n >= 1000 {
            return String(format: "%.0fK", Double(n) / 1000.0)
        }
        return "\(n)"
    }

    private func shortModelName(_ model: String) -> String {
        if model.contains("opus") { return "Opus" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("haiku") { return "Haiku" }
        return String(model.prefix(6))
    }

    private func modelColor(_ model: String) -> Color {
        if model.contains("opus") { return .purple }
        if model.contains("sonnet") { return .blue }
        if model.contains("haiku") { return .green }
        return .gray
    }
}

// MARK: - Monitor Data Model
struct MonitorData {
    let currentCost: Double
    let costLimit: Double
    let currentTokens: Int
    let tokenLimit: Int
    let currentMessages: Int
    let messageLimit: Int
    let timeToReset: String
    let timeToResetMinutes: Int
    let burnRate: Double // tokens per minute
    let costPerHour: Double // cost per hour (from ccusage)
    let projectedTotalCost: Double // projected cost by end of block
    let tokenExhaustionTime: String?
    let resetTime: String
    let modelDistribution: [ModelDist]
    let lastUpdated: String

    struct ModelDist {
        let model: String
        let percentage: Double
    }
}

// MARK: - Burn Rate Chart View
struct BurnRateChartView: View {
    let currentTokens: Int
    let tokenLimit: Int
    let currentCost: Double
    let costLimit: Double
    let burnRate: Double // tokens per minute
    let costPerHour: Double
    let remainingMinutes: Int
    let tokenBarColor: Color
    let costBarColor: Color
    let warningColor: Color

    @State private var chartMode: ChartMode = .tokens

    enum ChartMode: String, CaseIterable {
        case tokens = "토큰"
        case cost = "비용"
    }

    // Generate projection data points
    private var projectionData: [ProjectionPoint] {
        var points: [ProjectionPoint] = []
        let now = Date()

        // Current point
        points.append(ProjectionPoint(
            time: now,
            actual: chartMode == .tokens ? Double(currentTokens) : currentCost,
            projected: nil,
            isActual: true
        ))

        // Project into the future based on burn rate
        let projectionMinutes = min(remainingMinutes, 300) // Max 5 hours
        let intervals = 10 // Number of projection points

        for i in 1...intervals {
            let minutesAhead = (projectionMinutes * i) / intervals
            let futureTime = now.addingTimeInterval(Double(minutesAhead) * 60)

            let projectedValue: Double
            if chartMode == .tokens {
                projectedValue = Double(currentTokens) + (burnRate * Double(minutesAhead))
            } else {
                projectedValue = currentCost + (costPerHour / 60.0 * Double(minutesAhead))
            }

            points.append(ProjectionPoint(
                time: futureTime,
                actual: nil,
                projected: projectedValue,
                isActual: false
            ))
        }

        return points
    }

    private var limitValue: Double {
        chartMode == .tokens ? Double(tokenLimit) : costLimit
    }

    private var currentValue: Double {
        chartMode == .tokens ? Double(currentTokens) : currentCost
    }

    private var projectedEndValue: Double {
        if chartMode == .tokens {
            return Double(currentTokens) + (burnRate * Double(remainingMinutes))
        } else {
            return currentCost + (costPerHour / 60.0 * Double(remainingMinutes))
        }
    }

    private var willExceedLimit: Bool {
        projectedEndValue > limitValue
    }

    var body: some View {
        VStack(spacing: 8) {
            // Mode selector
            Picker("Mode", selection: $chartMode) {
                ForEach(ChartMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)

            // Chart
            Chart {
                // Limit line
                RuleMark(y: .value("Limit", limitValue))
                    .foregroundStyle(warningColor.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text(chartMode == .tokens ? "한도: \(formatTokens(Int(limitValue)))" : "한도: $\(String(format: "%.0f", limitValue))")
                            .font(.caption2)
                            .foregroundStyle(warningColor)
                    }

                // Current actual point
                PointMark(
                    x: .value("Time", Date()),
                    y: .value("Usage", currentValue)
                )
                .foregroundStyle(chartMode == .tokens ? tokenBarColor : costBarColor)
                .symbolSize(100)
                .annotation(position: .top) {
                    Text(chartMode == .tokens ? formatTokens(Int(currentValue)) : "$\(String(format: "%.2f", currentValue))")
                        .font(.caption2.bold())
                        .foregroundStyle(chartMode == .tokens ? tokenBarColor : costBarColor)
                }

                // Projection line
                ForEach(projectionData.filter { $0.projected != nil }, id: \.time) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Projected", point.projected ?? 0)
                    )
                    .foregroundStyle(willExceedLimit ? warningColor.opacity(0.7) : Color.gray.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                }

                // Area under projection
                ForEach(projectionData, id: \.time) { point in
                    AreaMark(
                        x: .value("Time", point.time),
                        y: .value("Value", point.actual ?? point.projected ?? 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                (chartMode == .tokens ? tokenBarColor : costBarColor).opacity(0.3),
                                (chartMode == .tokens ? tokenBarColor : costBarColor).opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            if chartMode == .tokens {
                                Text(formatTokensShort(Int(v)))
                            } else {
                                Text("$\(String(format: "%.0f", v))")
                            }
                        }
                    }
                }
            }
            .chartYScale(domain: 0...(max(limitValue * 1.2, projectedEndValue * 1.1)))

            // Projection summary
            HStack {
                if willExceedLimit {
                    Label("한도 초과 예상", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(warningColor)
                } else {
                    Label("한도 내 예상", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Spacer()
                Text(projectedEndText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var projectedEndText: String {
        let valueStr: String
        if chartMode == .tokens {
            valueStr = formatTokens(Int(projectedEndValue))
        } else {
            valueStr = String(format: "$%.2f", projectedEndValue)
        }
        return "예상 종료 시: \(valueStr)"
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.2fM", Double(n) / 1_000_000.0)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000.0)
        }
        return "\(n)"
    }

    private func formatTokensShort(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000.0)
        } else if n >= 1_000 {
            return String(format: "%.0fK", Double(n) / 1_000.0)
        }
        return "\(n)"
    }
}

// Projection data point
struct ProjectionPoint: Identifiable {
    let id = UUID()
    let time: Date
    let actual: Double?
    let projected: Double?
    let isActual: Bool
}

// MARK: - Monitor Bar View
struct MonitorBarView: View {
    let title: String
    let icon: String
    let current: Double
    let limit: Double
    let formatValue: (Double) -> String
    let barColor: Color
    let warningThreshold: Double

    private var percentage: Double {
        limit > 0 ? min(current / limit, 1.0) : 0
    }

    private var isWarning: Bool {
        percentage >= warningThreshold
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(barColor)
                Text(title)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(String(format: "%.1f%%", percentage * 100))")
                    .font(.caption.monospaced())
                    .foregroundStyle(isWarning ? .red : .secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(isWarning ? .red : barColor)
                        .frame(width: max(4, geo.size.width * CGFloat(percentage)))
                }
            }
            .frame(height: 16)

            HStack {
                Text(formatValue(current))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                Text("/")
                    .foregroundStyle(.secondary)
                Text(formatValue(limit))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Color Customization View
struct ColorCustomizationView: View {
    @Binding var costBarColor: Color
    @Binding var tokenBarColor: Color
    @Binding var messageBarColor: Color
    @Binding var warningColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("색상 커스터마이징")
                .font(.headline)

            VStack(spacing: 12) {
                ColorPickerRow(title: "비용 바", color: $costBarColor)
                ColorPickerRow(title: "토큰 바", color: $tokenBarColor)
                ColorPickerRow(title: "메시지 바", color: $messageBarColor)
                ColorPickerRow(title: "경고 색상", color: $warningColor)
            }

            Divider()

            Button("기본값으로 리셋") {
                costBarColor = .orange
                tokenBarColor = .green
                messageBarColor = .blue
                warningColor = .red
            }
            .font(.caption)
        }
        .padding()
        .frame(width: 250)
    }
}

struct ColorPickerRow: View {
    let title: String
    @Binding var color: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
            Spacer()
            ColorPicker("", selection: $color)
                .labelsHidden()
        }
    }
}

// MARK: - Claude Plan Extension
extension ClaudePlan {
    var costLimit: Double {
        switch self {
        case .pro: return 18.0
        case .max5: return 35.0
        case .max20: return 140.0
        }
    }

    var tokenLimit: Int {
        switch self {
        case .pro: return 19_000
        case .max5: return 88_000
        case .max20: return 220_000
        }
    }

    var messageLimit: Int {
        switch self {
        case .pro: return 500
        case .max5: return 1000
        case .max20: return 2000
        }
    }
}

#Preview {
    DetailView()
        .environment(AppState())
}
