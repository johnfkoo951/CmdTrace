import SwiftUI

struct ProjectsView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selectedProject: String?
    
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
        ZStack {
            if let project = selectedProject {
                ProjectDetailView(projectPath: project) {
                    withAnimation(.spring(duration: 0.35)) {
                        selectedProject = nil
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            } else {
                projectsGridView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
    }
    
    private var projectsGridView: some View {
        VStack(spacing: 0) {
            // Header with Search
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Projects")
                            .font(.system(size: 28, weight: .bold))
                        Text("\(filteredProjects.count) projects found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Compact Search Bar
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(width: 250)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.primary.opacity(0.1), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            
            if filteredProjects.isEmpty {
                ContentUnavailableView("No Projects", systemImage: "folder.badge.questionmark", description: Text("No projects found matching your search"))
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 300, maximum: 450), spacing: 20)
                    ], spacing: 20) {
                        ForEach(filteredProjects, id: \.self) { project in
                            ProjectCard(projectPath: project)
                                .onTapGesture {
                                    withAnimation(.spring(duration: 0.35)) {
                                        selectedProject = project
                                    }
                                }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct ProjectCard: View {
    let projectPath: String
    @Environment(AppState.self) private var appState
    @State private var isHovered = false
    
    private var metadata: ProjectMetadata {
        appState.getProjectMetadata(projectPath)
    }
    
    private var stats: ProjectStats {
        appState.projectStats(for: projectPath)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(metadata.swiftUIColor.gradient)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "folder.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(metadata.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                        
                        if metadata.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                        }
                        if metadata.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.yellow)
                        }
                    }
                    
                    Text(projectPath.components(separatedBy: "/").dropLast().last ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stats.totalSessions)")
                        .font(.headline)
                    Text("Sessions")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Divider().frame(height: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stats.totalMessages)")
                        .font(.headline)
                    Text("Messages")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let last = stats.lastSession {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(last.formatted(.dateTime.month().day()))
                            .font(.headline)
                        Text("Last Active")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if !metadata.languages.isEmpty || !metadata.frameworks.isEmpty {
                HStack(spacing: 4) {
                    ForEach(metadata.languages.prefix(3), id: \.self) { lang in
                        let info = LanguageInfo.info(for: lang)
                        Text(info.name)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(info.color.opacity(0.15))
                            .foregroundStyle(info.color)
                            .clipShape(Capsule())
                    }
                    
                    ForEach(metadata.frameworks.prefix(2), id: \.self) { fw in
                        let info = FrameworkInfo.info(for: fw)
                        Text(info.name)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(info.color.opacity(0.15))
                            .foregroundStyle(info.color)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isHovered ? metadata.swiftUIColor.opacity(0.3) : .clear, lineWidth: 2)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(color: .black.opacity(isHovered ? 0.1 : 0), radius: 10, x: 0, y: 5)
        .onHover { isHovered = $0 }
        .animation(.spring(duration: 0.3), value: isHovered)
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
        }
    }
    
    private func openInFinder() {
        let url = URL(fileURLWithPath: metadata.fullPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}

struct ProjectDetailView: View {
    let projectPath: String
    var onBack: (() -> Void)?
    
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
        VStack(spacing: 0) {
            // Custom Toolbar
            HStack {
                Button {
                    onBack?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Projects")
                    }
                    .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button { showEditSheet = true } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
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
                            .font(.title3)
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.bar)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    projectHeader
                    statsCards
                    techStackSection
                    sessionsSection
                }
                .padding(24)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showEditSheet) {
            ProjectEditSheet(projectPath: projectPath)
        }
    }
    
    private var projectHeader: some View {
        HStack(alignment: .top, spacing: 20) {
            RoundedRectangle(cornerRadius: 16)
                .fill(metadata.swiftUIColor.gradient)
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(metadata.displayName)
                        .font(.system(size: 32, weight: .bold))
                    
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
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if let description = metadata.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var statsCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ProjectStatCard(title: "Sessions", value: "\(stats.totalSessions)", icon: "bubble.left.and.bubble.right", color: .blue)
            ProjectStatCard(title: "Messages", value: "\(stats.totalMessages)", icon: "text.bubble", color: .green)
            ProjectStatCard(title: "Active Days", value: "\(stats.activeDays)", icon: "calendar", color: .orange)
            ProjectStatCard(title: "Avg/Session", value: String(format: "%.1f", stats.averageMessagesPerSession), icon: "chart.bar", color: .purple)
        }
    }
    
    private var techStackSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tech Stack")
                    .font(.title3.bold())
                Spacer()
                Button("Edit") { showEditSheet = true }
                    .font(.caption)
            }
            
            if metadata.languages.isEmpty && metadata.frameworks.isEmpty {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.secondary)
                    Text("No tech stack defined. Click Edit to add languages and frameworks.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                HStack(alignment: .top, spacing: 32) {
                    if !metadata.languages.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Languages")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            FlowLayout(spacing: 8) {
                                ForEach(metadata.languages, id: \.self) { lang in
                                    let info = LanguageInfo.info(for: lang)
                                    HStack(spacing: 6) {
                                        Image(systemName: info.icon)
                                            .font(.caption)
                                        Text(info.name)
                                            .font(.subheadline.bold())
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(info.color.opacity(0.15))
                                    .foregroundStyle(info.color)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    if !metadata.frameworks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Frameworks")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            FlowLayout(spacing: 8) {
                                ForEach(metadata.frameworks, id: \.self) { fw in
                                    let info = FrameworkInfo.info(for: fw)
                                    Text(info.name)
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
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
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sessions")
                    .font(.title3.bold())
                Text("\(sessions.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
                Spacer()
            }
            
            if sessions.isEmpty {
                Text("No sessions for this project")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                LazyVStack(spacing: 12) {
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
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.getDisplayName(for: session))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label(session.relativeTime, systemImage: "clock")
                    Label("\(session.messageCount) messages", systemImage: "bubble.left")
                    if let duration = session.duration {
                        Label(duration, systemImage: "timer")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(isHovered ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

struct ProjectStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
