import SwiftUI
import AppKit

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

    private static let sharedService = SessionService()
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
        
        do {
            sessionInsights = try await Self.sharedService.loadSessionInsights(for: session)
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

        guard let config = SummaryService.configFrom(settings: appState.settings) else {
            await MainActor.run { summaryError = "\(appState.settings.summaryProvider.rawValue) API 키가 설정되지 않았습니다" }
            return
        }

        var messages: [Message] = []
        do {
            messages = try await Self.sharedService.loadMessages(for: session, agent: appState.agentType)
        } catch {
            await MainActor.run { summaryError = "메시지 로드 실패: \(error.localizedDescription)" }
            return
        }

        do {
            let result = try await SummaryService.generateSummary(
                config: config,
                session: session,
                messages: messages
            )
            await MainActor.run {
                result.apply(to: appState, sessionId: session.id)
            }
        } catch {
            await MainActor.run { summaryError = error.localizedDescription }
        }
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

    private func generateFilename(displayName: String) -> String {
        FilenameGenerator.generateFilename(
            displayName: displayName,
            prefix: appState.settings.obsidianPrefix,
            suffix: appState.settings.obsidianSuffix,
            projectName: session.projectName,
            cliName: appState.selectedCLI.rawValue,
            resumeId: session.resumeId,
            messageCount: session.messageCount
        )
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
