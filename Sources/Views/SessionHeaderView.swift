import SwiftUI
import AppKit

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

        guard let config = SummaryService.configFrom(settings: appState.settings) else { return }

        do {
            let result = try await SummaryService.generateSummary(
                config: config,
                session: session,
                messages: messages
            )
            await MainActor.run {
                result.apply(to: appState, sessionId: session.id)
                if let summaryText = result.title ?? Optional(result.summary) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(summaryText, forType: .string)
                }
            }
        } catch {
            // Silently fail for header button (no UI error display available)
        }
    }
}
