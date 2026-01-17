import SwiftUI

struct ProjectsView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selectedProject: String?
    @State private var showEditSheet = false
    
    private var filteredProjects: [String] {
        let projects = appState.allProjects
        if searchText.isEmpty {
            return sortedProjects(projects)
        }
        return sortedProjects(projects.filter { project in
            let meta = appState.getProjectMetadata(project)
            return meta.displayName.localizedCaseInsensitiveContains(searchText) ||
                   project.localizedCaseInsensitiveContains(searchText) ||
                   meta.languages.joined().localizedCaseInsensitiveContains(searchText) ||
                   meta.frameworks.joined().localizedCaseInsensitiveContains(searchText)
        })
    }
    
    private func sortedProjects(_ projects: [String]) -> [String] {
        projects.sorted { p1, p2 in
            let m1 = appState.getProjectMetadata(p1)
            let m2 = appState.getProjectMetadata(p2)
            if m1.isPinned != m2.isPinned { return m1.isPinned }
            if m1.isFavorite != m2.isFavorite { return m1.isFavorite }
            let s1 = appState.projectStats(for: p1)
            let s2 = appState.projectStats(for: p2)
            return (s1.lastSession ?? Date.distantPast) > (s2.lastSession ?? Date.distantPast)
        }
    }
    
    var body: some View {
        HSplitView {
            projectList
                .frame(minWidth: 280, maxWidth: 350)
            
            if let project = selectedProject {
                ProjectDetailView(projectPath: project)
            } else {
                ContentUnavailableView("Select a Project", systemImage: "folder", description: Text("Choose a project from the list to view details"))
            }
        }
    }
    
    private var projectList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search projects...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.regularMaterial)
            
            Divider()
            
            if filteredProjects.isEmpty {
                ContentUnavailableView("No Projects", systemImage: "folder.badge.questionmark", description: Text("No projects found matching your search"))
                    .frame(maxHeight: .infinity)
            } else {
                List(filteredProjects, id: \.self, selection: $selectedProject) { project in
                    ProjectListRow(projectPath: project)
                        .tag(project)
                }
                .listStyle(.sidebar)
            }
            
            Divider()
            
            HStack {
                Text("\(filteredProjects.count) projects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}

struct ProjectListRow: View {
    let projectPath: String
    @Environment(AppState.self) private var appState
    
    private var metadata: ProjectMetadata {
        appState.getProjectMetadata(projectPath)
    }
    
    private var stats: ProjectStats {
        appState.projectStats(for: projectPath)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(metadata.swiftUIColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if metadata.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }
                    if metadata.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                    }
                    Text(metadata.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
                
                HStack(spacing: 6) {
                    Text("\(stats.totalSessions) sessions")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if !metadata.languages.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 2) {
                            ForEach(metadata.languages.prefix(2), id: \.self) { lang in
                                Text(lang)
                                    .font(.system(size: 9))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(LanguageInfo.info(for: lang).color.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button { appState.toggleProjectPinned(projectPath) } label: {
                Label(metadata.isPinned ? "Unpin" : "Pin", systemImage: metadata.isPinned ? "pin.slash" : "pin")
            }
            Button { appState.toggleProjectFavorite(projectPath) } label: {
                Label(metadata.isFavorite ? "Unfavorite" : "Favorite", systemImage: metadata.isFavorite ? "star.slash" : "star")
            }
            Divider()
            Button { openInFinder() } label: {
                Label("Show in Finder", systemImage: "folder")
            }
            Button { openInTerminal() } label: {
                Label("Open in Terminal", systemImage: "terminal")
            }
        }
    }
    
    private func openInFinder() {
        let url = URL(fileURLWithPath: metadata.fullPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
    
    private func openInTerminal() {
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(metadata.fullPath)'"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

struct ProjectDetailView: View {
    let projectPath: String
    @Environment(AppState.self) private var appState
    @State private var showEditSheet = false
    @State private var selectedSession: Session?
    
    private var metadata: ProjectMetadata {
        appState.getProjectMetadata(projectPath)
    }
    
    private var stats: ProjectStats {
        appState.projectStats(for: projectPath)
    }
    
    private var sessions: [Session] {
        appState.sessionsForProject(projectPath).sorted { $0.lastActivity > $1.lastActivity }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                projectHeader
                statsCards
                techStackSection
                sessionsSection
            }
            .padding()
        }
        .sheet(isPresented: $showEditSheet) {
            ProjectEditSheet(projectPath: projectPath)
        }
    }
    
    private var projectHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(metadata.swiftUIColor.gradient)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "folder.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(metadata.displayName)
                        .font(.title2.bold())
                    
                    if metadata.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.orange)
                    }
                    if metadata.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                
                Text(projectPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if let description = metadata.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button { showEditSheet = true } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                
                Menu {
                    Button { openInFinder() } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    Divider()
                    Button { startSession(in: .terminal) } label: {
                        Label("New Session in Terminal", systemImage: "terminal")
                    }
                    Button { startSession(in: .iterm) } label: {
                        Label("New Session in iTerm", systemImage: "terminal.fill")
                    }
                    Button { startSession(in: .warp) } label: {
                        Label("New Session in Warp", systemImage: "bolt.horizontal")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var statsCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ProjectStatCard(title: "Sessions", value: "\(stats.totalSessions)", icon: "bubble.left.and.bubble.right", color: .blue)
            ProjectStatCard(title: "Messages", value: "\(stats.totalMessages)", icon: "text.bubble", color: .green)
            ProjectStatCard(title: "Active Days", value: "\(stats.activeDays)", icon: "calendar", color: .orange)
            ProjectStatCard(title: "Avg/Session", value: String(format: "%.1f", stats.averageMessagesPerSession), icon: "chart.bar", color: .purple)
        }
    }
    
    private var techStackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tech Stack")
                    .font(.headline)
                Spacer()
                Button("Edit") { showEditSheet = true }
                    .font(.caption)
            }
            
            if metadata.languages.isEmpty && metadata.frameworks.isEmpty {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.secondary)
                    Text("No tech stack defined. Click Edit to add languages and frameworks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                HStack(spacing: 16) {
                    if !metadata.languages.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Languages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            FlowLayout(spacing: 6) {
                                ForEach(metadata.languages, id: \.self) { lang in
                                    let info = LanguageInfo.info(for: lang)
                                    HStack(spacing: 4) {
                                        Image(systemName: info.icon)
                                            .font(.caption2)
                                        Text(info.name)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(info.color.opacity(0.15))
                                    .foregroundStyle(info.color)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    if !metadata.frameworks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Frameworks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            FlowLayout(spacing: 6) {
                                ForEach(metadata.frameworks, id: \.self) { fw in
                                    let info = FrameworkInfo.info(for: fw)
                                    Text(info.name)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(info.color.opacity(0.15))
                                        .foregroundStyle(info.color)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sessions")
                    .font(.headline)
                Text("(\(sessions.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            if sessions.isEmpty {
                Text("No sessions for this project")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(sessions) { session in
                        ProjectSessionRow(session: session)
                            .onTapGesture {
                                appState.selectedSession = session
                                appState.selectedTab = .sessions
                            }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func openInFinder() {
        let url = URL(fileURLWithPath: metadata.fullPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
    
    private func startSession(in terminal: TerminalType) {
        let path = metadata.fullPath
        let claudeCommand = "cd '\(path)' && claude"
        
        let script: String
        switch terminal {
        case .terminal:
            script = """
            tell application "Terminal"
                activate
                do script "\(claudeCommand)"
            end tell
            """
        case .iterm:
            script = """
            tell application "iTerm"
                activate
                create window with default profile
                tell current session of current window
                    write text "\(claudeCommand)"
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
                keystroke "\(claudeCommand)"
                keystroke return
            end tell
            """
        }
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

struct ProjectSessionRow: View {
    let session: Session
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.getDisplayName(for: session))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(session.relativeTime)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(session.messageCount) messages")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let duration = session.duration {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(duration)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}

struct ProjectStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
                Text(value)
                    .font(.title2.bold())
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ProjectEditSheet: View {
    let projectPath: String
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var customName: String = ""
    @State private var description: String = ""
    @State private var languagesText: String = ""
    @State private var frameworksText: String = ""
    @State private var selectedColor: String = "#3B82F6"
    @State private var notes: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Project")
                    .font(.headline)
                Spacer()
                Button("Done") { save(); dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.bar)
            
            Form {
                Section("Basic Info") {
                    TextField("Custom Name", text: $customName, prompt: Text(projectPath.components(separatedBy: "/").last ?? ""))
                    TextField("Description", text: $description, prompt: Text("Project description..."))
                }
                
                Section("Tech Stack") {
                    TextField("Languages", text: $languagesText, prompt: Text("swift, typescript, python..."))
                    TextField("Frameworks", text: $frameworksText, prompt: Text("swiftui, react, django..."))
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                        ForEach(TagColors.presets, id: \.hex) { preset in
                            Circle()
                                .fill(Color(hex: preset.hex) ?? .blue)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if selectedColor == preset.hex {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .font(.caption.bold())
                                    }
                                }
                                .onTapGesture { selectedColor = preset.hex }
                        }
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 500)
        .onAppear { loadData() }
    }
    
    private func loadData() {
        let meta = appState.getProjectMetadata(projectPath)
        customName = meta.customName ?? ""
        description = meta.description ?? ""
        languagesText = meta.languages.joined(separator: ", ")
        frameworksText = meta.frameworks.joined(separator: ", ")
        selectedColor = meta.color
        notes = meta.notes ?? ""
    }
    
    private func save() {
        let languages = languagesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let frameworks = frameworksText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        let existingMeta = appState.getProjectMetadata(projectPath)
        let newMeta = ProjectMetadata(
            path: projectPath,
            customName: customName.isEmpty ? nil : customName,
            description: description.isEmpty ? nil : description,
            languages: languages,
            frameworks: frameworks,
            tags: existingMeta.tags,
            color: selectedColor,
            isFavorite: existingMeta.isFavorite,
            isPinned: existingMeta.isPinned,
            notes: notes.isEmpty ? nil : notes,
            lastOpened: existingMeta.lastOpened,
            createdAt: existingMeta.createdAt
        )
        appState.updateProjectMetadata(newMeta)
    }
}

struct ProjectsInspectorPanel: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Projects")
                    .font(.headline)
                
                GroupBox("Statistics") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Total Projects", value: "\(appState.allProjects.count)")
                        LabeledContent("Total Sessions", value: "\(appState.sessions.count)")
                        LabeledContent("Favorites", value: "\(appState.projectMetadata.values.filter { $0.isFavorite }.count)")
                        LabeledContent("Pinned", value: "\(appState.projectMetadata.values.filter { $0.isPinned }.count)")
                    }
                    .font(.caption)
                }
                
                GroupBox("Quick Actions") {
                    VStack(spacing: 8) {
                        Button {
                            let url = URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.path)
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("Open Home Folder", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(12)
        }
    }
}
