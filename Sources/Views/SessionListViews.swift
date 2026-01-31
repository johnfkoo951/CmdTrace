import SwiftUI

// MARK: - Session List View
struct SessionListView: View {
    @Environment(AppState.self) private var appState
    
    private var groupedSessions: [(date: String, sessions: [Session])] {
        let grouped = Dictionary(grouping: appState.filteredSessions) { $0.dateGroup }
        let order = ["Today", "Yesterday"]
        return grouped.sorted { first, second in
            let firstIndex = order.firstIndex(of: first.key) ?? Int.max
            let secondIndex = order.firstIndex(of: second.key) ?? Int.max
            if firstIndex != secondIndex {
                return firstIndex < secondIndex
            }
            guard let firstDate = first.value.first?.lastActivity,
                  let secondDate = second.value.first?.lastActivity else { return false }
            return firstDate > secondDate
        }.map { ($0.key, $0.value) }
    }
    
    private var flatSessions: [Session] {
        groupedSessions.flatMap { $0.sessions }
    }
    
    var body: some View {
        @Bindable var state = appState
        
        List(selection: $state.selectedSession) {
            ForEach(groupedSessions, id: \.date) { group in
                Section {
                    ForEach(group.sessions) { session in
                        SessionRow(session: session)
                            .tag(session)
                    }
                } header: {
                    Text(group.date)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .onKeyPress(.upArrow) {
            selectPreviousSession()
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectNextSession()
            return .handled
        }
        .onKeyPress(.return) {
            return .handled
        }
    }
    
    private func selectNextSession() {
        let sessions = flatSessions
        guard !sessions.isEmpty else { return }
        
        if let current = appState.selectedSession,
           let index = sessions.firstIndex(of: current),
           index < sessions.count - 1 {
            appState.selectedSession = sessions[index + 1]
        } else if appState.selectedSession == nil {
            appState.selectedSession = sessions.first
        }
    }
    
    private func selectPreviousSession() {
        let sessions = flatSessions
        guard !sessions.isEmpty else { return }
        
        if let current = appState.selectedSession,
           let index = sessions.firstIndex(of: current),
           index > 0 {
            appState.selectedSession = sessions[index - 1]
        } else if appState.selectedSession == nil {
            appState.selectedSession = sessions.last
        }
    }
}

// MARK: - Session Row (Website-inspired design)
struct SessionRow: View {
    let session: Session
    @Environment(AppState.self) private var appState
    @State private var showRenameSheet = false
    @State private var showTagSheet = false
    @State private var newName = ""

    private var isFavorite: Bool { appState.isFavorite(session.id) }
    private var isPinned: Bool { appState.isPinned(session.id) }
    private var isArchived: Bool { appState.isArchived(session.id) }
    private var isSelected: Bool { appState.selectedSessionIds.contains(session.id) }

    var body: some View {
        HStack(spacing: 8) {
            if appState.isMultiSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .onTapGesture {
                        appState.toggleSessionSelection(session.id)
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
            // Row 1: Title with favorite star on left + message count badge
            HStack(spacing: 8) {
                // Favorite star indicator (prominent, left side like website)
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                }

                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }

                Text(appState.getDisplayName(for: session))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                // Message count badge (cleaner style)
                Text("\(session.messageCount)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.fill.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Row 2: Preview (slightly better contrast)
            Text(session.preview)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Row 3: Project + Time info (aligned, cleaner spacing)
            HStack(spacing: 8) {
                // Project badge (website style)
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 9))
                    Text(session.projectName)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.fill.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 5))

                Spacer()

                // Duration badge (accent color like website)
                if let duration = session.duration {
                    Text(duration)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: "#6366f1") ?? .blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background((Color(hex: "#6366f1") ?? .blue).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                // Time info
                HStack(spacing: 4) {
                    Text(session.shortDate)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    if let startTime = session.startTime {
                        Text("\(startTime)→\(session.lastMessageTime)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .fixedSize()
            }

            // Row 4: Tags (website-style colored pills)
            let tags = appState.getTags(for: session.id)
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags.prefix(4), id: \.self) { tag in
                        let tagInfo = appState.tagDatabase[tag]
                        let tagColor = tagInfo?.swiftUIColor ?? Color(hex: "#6366f1") ?? .blue
                        Button {
                            appState.selectedTag = tag
                            appState.filterSessions()
                        } label: {
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(tagColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(tagColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }
                    if tags.count > 4 {
                        Text("+\(tags.count - 4)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contextMenu {
            Button {
                appState.toggleFavorite(for: session.id)
            } label: {
                Label(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                      systemImage: isFavorite ? "star.slash" : "star")
            }
            
            Button {
                appState.togglePinned(for: session.id)
            } label: {
                Label(isPinned ? "Unpin" : "Pin to Top",
                      systemImage: isPinned ? "pin.slash" : "pin")
            }
            
            Button {
                appState.toggleArchive(for: session.id)
            } label: {
                Label(isArchived ? "Unarchive" : "Archive",
                      systemImage: isArchived ? "arrow.uturn.backward" : "archivebox")
            }
            
            Divider()
            
            Button {
                newName = appState.sessionMetadata[session.id]?.customName ?? ""
                showRenameSheet = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            
            Button {
                showTagSheet = true
            } label: {
                Label("Manage Tags", systemImage: "tag")
            }
            
            Divider()
            
            if appState.selectedCLI == .claude {
                Menu {
                    Button {
                        resumeSession(session, terminal: .terminal, bypass: false)
                    } label: {
                        Label("Terminal", systemImage: "terminal")
                    }
                    
                    Button {
                        resumeSession(session, terminal: .terminal, bypass: true)
                    } label: {
                        Label("Terminal (Bypass)", systemImage: "terminal.fill")
                    }
                    
                    Divider()
                    
                    Button {
                        resumeSession(session, terminal: .iterm, bypass: false)
                    } label: {
                        Label("iTerm2", systemImage: "apple.terminal")
                    }
                    
                    Button {
                        resumeSession(session, terminal: .iterm, bypass: true)
                    } label: {
                        Label("iTerm2 (Bypass)", systemImage: "apple.terminal.fill")
                    }
                    
                    Divider()
                    
                    Button {
                        resumeSession(session, terminal: .warp, bypass: false)
                    } label: {
                        Label("Warp", systemImage: "bolt.horizontal")
                    }
                    
                    Button {
                        resumeSession(session, terminal: .warp, bypass: true)
                    } label: {
                        Label("Warp (Bypass)", systemImage: "bolt.horizontal.fill")
                    }
                } label: {
                    Label("Resume Session", systemImage: "play.circle")
                }
            }
            
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(session.id, forType: .string)
            } label: {
                Label("Copy Session ID", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button {
                appState.toggleSessionSelection(session.id)
            } label: {
                Label(isSelected ? "Deselect" : "Select for Bulk Action",
                      systemImage: isSelected ? "checkmark.circle.fill" : "circle")
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameSheet(sessionId: session.id, currentName: $newName)
        }
        .popover(isPresented: $showTagSheet, arrowEdge: .leading) {
            TagSheet(sessionId: session.id)
        }
    }
}

func resumeSession(_ session: Session, terminal: TerminalType, bypass: Bool) {
    let command = bypass ? "claude --resume \(session.id) --dangerously-skip-permissions" : "claude --resume \(session.id)"
    
    let script: String
    switch terminal {
    case .terminal:
        script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
    case .iterm:
        script = """
        tell application "iTerm2"
            activate
            create window with default profile
            tell current session of current window
                write text "\(command)"
            end tell
        end tell
        """
    case .warp:
        script = """
        tell application "Warp"
            activate
        end tell
        delay 0.5
        tell application "System Events"
            tell process "Warp"
                keystroke "t" using command down
                delay 0.2
                keystroke "\(command)"
                keystroke return
            end tell
        end tell
        """
    }
    
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
        scriptObject.executeAndReturnError(&error)
    }
}

// MARK: - Rename Sheet
struct RenameSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let sessionId: String
    @Binding var currentName: String
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Rename Session")
                .font(.headline)
            
            TextField("Session name", text: $currentName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                
                Button("Save") {
                    appState.setSessionName(currentName, for: sessionId)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - Tag Sheet
struct TagSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let sessionId: String
    @State private var newTag = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Manage Tags")
                .font(.headline)
            
            let tags = appState.getTags(for: sessionId)
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        let tagInfo = appState.tagDatabase[tag]
                        HStack(spacing: 4) {
                            Circle()
                                .fill(tagInfo?.swiftUIColor ?? .blue)
                                .frame(width: 8, height: 8)
                            
                            Text(tag)
                            
                            Button {
                                appState.removeTag(tag, from: sessionId)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((tagInfo?.swiftUIColor ?? .blue).opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
                .frame(width: 350)
            }
            
            HStack {
                TextField("New tag (use folder/tag for nesting)", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTag() }
                
                Button { addTag() } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newTag.isEmpty)
            }
            .frame(width: 350)
            
            let availableTags = appState.allTags.filter { !tags.contains($0.name) }
            let filteredTags = newTag.isEmpty 
                ? availableTags 
                : availableTags.filter { $0.name.localizedCaseInsensitiveContains(newTag) }
            
            if !availableTags.isEmpty {
                HStack {
                    Text("Existing tags")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("(\(filteredTags.count)/\(availableTags.count))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(width: 350)
                
                ScrollView {
                    FlowLayout(spacing: 6) {
                        ForEach(filteredTags) { tagInfo in
                            Button {
                                appState.addTag(tagInfo.name, to: sessionId)
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(tagInfo.swiftUIColor)
                                        .frame(width: 8, height: 8)
                                    Text(tagInfo.name)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tagInfo.swiftUIColor.opacity(0.2))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 350)
                }
                .frame(maxHeight: 120)
                .frame(width: 350)
            }
            
            Button("Done") { dismiss() }
        }
        .padding()
    }
    
    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces)
        if !tag.isEmpty {
            appState.addTag(tag, to: sessionId)
            newTag = ""
        }
    }
}

struct BulkActionBar: View {
    @Environment(AppState.self) private var appState
    @State private var showTagMenu = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("\(appState.selectedSessionIds.count) selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    appState.selectAllFilteredSessions()
                } label: {
                    Text("Select All")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                
                Button {
                    appState.clearSelection()
                } label: {
                    Text("Clear")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            HStack(spacing: 8) {
                Button {
                    appState.bulkToggleFavorite()
                } label: {
                    Image(systemName: "star")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Toggle Favorites")
                
                Menu {
                    ForEach(appState.allTags) { tag in
                        Button {
                            appState.bulkAddTag(tag.name)
                        } label: {
                            Label(tag.name, systemImage: "tag")
                        }
                    }
                    
                    if !appState.allTags.isEmpty {
                        Divider()
                    }
                    
                    ForEach(appState.allTags) { tag in
                        Button(role: .destructive) {
                            appState.bulkRemoveTag(tag.name)
                        } label: {
                            Label("Remove \(tag.name)", systemImage: "tag.slash")
                        }
                    }
                } label: {
                    Image(systemName: "tag")
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Manage Tags")
                
                if appState.showArchivedSessions {
                    Button {
                        appState.bulkUnarchive()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("Unarchive Selected")
                } else {
                    Button {
                        appState.bulkArchive()
                    } label: {
                        Image(systemName: "archivebox")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("Archive Selected")
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
            Divider()
        }
        .background(Color.accentColor.opacity(0.1))
    }
}

struct StatsBar: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 16) {
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")

            Divider()
                .frame(height: 18)

            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                Text("Sessions")
                    .font(.system(size: 12))
                Text("\(appState.filteredSessions.count)")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.secondary)

            Spacer()

            let totalMessages = appState.filteredSessions.reduce(0) { $0 + $1.messageCount }
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 12))
                Text("Messages")
                    .font(.system(size: 12))
                Text(formatNumber(totalMessages))
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000 {
            let thousands = Double(num) / 1000.0
            return String(format: "%.1fK", thousands)
        }
        return "\(num)"
    }
}
