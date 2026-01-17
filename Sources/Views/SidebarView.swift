import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 0) {
            // FIXED HEADER - These controls never scroll
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        SidebarToggleButton(
                            title: "List",
                            icon: "list.bullet",
                            isSelected: appState.sidebarViewMode == .list
                        ) {
                            appState.sidebarViewMode = .list
                        }
                        
                        SidebarToggleButton(
                            title: "Tags",
                            icon: "tag",
                            isSelected: appState.sidebarViewMode == .tags
                        ) {
                            appState.sidebarViewMode = .tags
                        }
                    }
                    
                    HStack(spacing: 0) {
                        SidebarToggleButton(
                            title: "Sessions",
                            icon: "bubble.left.and.bubble.right",
                            isSelected: appState.selectedTab == .sessions
                        ) {
                            appState.selectedTab = .sessions
                        }
                        
                        SidebarToggleButton(
                            title: "Projects",
                            icon: "folder",
                            isSelected: appState.selectedTab == .projects
                        ) {
                            appState.selectedTab = .projects
                        }
                        
                        SidebarToggleButton(
                            title: "Stats",
                            icon: "chart.bar",
                            isSelected: appState.selectedTab == .dashboard
                        ) {
                            appState.selectedTab = .dashboard
                        }
                        
                        SidebarToggleButton(
                            title: "Config",
                            icon: "gearshape.2",
                            isSelected: appState.selectedTab == .configuration
                        ) {
                            appState.selectedTab = .configuration
                        }
                        
                        SidebarToggleButton(
                            title: "AI",
                            icon: "sparkles",
                            isSelected: appState.selectedTab == .interaction
                        ) {
                            appState.selectedTab = .interaction
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                // Search and Filter Bar
                HStack(spacing: 8) {
                    SearchField(text: $state.searchText)
                    
                    Button {
                        Task { await appState.loadSessions() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh Sessions")
                    
                    Button {
                        state.showFavoritesOnly.toggle()
                        appState.filterSessions()
                    } label: {
                        Image(systemName: state.showFavoritesOnly ? "star.fill" : "star")
                            .font(.system(size: 13))
                            .foregroundStyle(state.showFavoritesOnly ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(state.showFavoritesOnly ? "Show All" : "Show Favorites Only")
                    
                    Button {
                        state.showArchivedSessions.toggle()
                        appState.filterSessions()
                    } label: {
                        Image(systemName: state.showArchivedSessions ? "archivebox.fill" : "archivebox")
                            .font(.system(size: 13))
                            .foregroundStyle(state.showArchivedSessions ? .orange : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(state.showArchivedSessions ? "Hide Archived" : "Show Archived")
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                
                // Selected Tag Chip (search query style)
                if let selectedTag = appState.selectedTag {
                    HStack {
                        HStack(spacing: 4) {
                            Text("tag:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(selectedTag)
                                .font(.caption)
                                .fontWeight(.medium)
                            Button {
                                appState.selectedTag = nil
                                appState.filterSessions()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                }
                
                // Tag Filter Pills (only in list mode without selected tag)
                if appState.sidebarViewMode == .list && appState.selectedTag == nil {
                    TagFilterPills()
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                }
                
                Divider()
                    .padding(.top, 8)
            }
            // END FIXED HEADER
            
            if appState.isMultiSelectMode {
                BulkActionBar()
            }
            
            if appState.sidebarViewMode == .list {
                if appState.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if appState.filteredSessions.isEmpty {
                    EmptySessionsView()
                } else {
                    SessionListView()
                }
            } else {
                TagBrowserView()
            }
            
            Spacer(minLength: 0)
            
            StatsBar()
        }
    }
}

// MARK: - Sidebar Toggle Button (Obsidian-style)
struct SidebarToggleButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                }
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(isSelected ? Color.accentColor : .clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Tag Browser View (Obsidian Style)
struct TagBrowserView: View {
    @Environment(AppState.self) private var appState
    @State private var expandedFolders: Set<String> = []
    @State private var showNested: Bool = true
    @State private var tagSearchText: String = ""
    
    var tagHierarchy: TagHierarchyNode {
        buildHierarchy(from: filteredTags)
    }
    
    var filteredTags: [TagInfo] {
        if tagSearchText.isEmpty {
            return appState.allTags
        }
        return appState.allTags.filter { $0.name.localizedCaseInsensitiveContains(tagSearchText) }
    }
    
    func buildHierarchy(from tags: [TagInfo]) -> TagHierarchyNode {
        let root = TagHierarchyNode(name: "", fullPath: "")
        
        for tag in tags {
            let parts = tag.name.split(separator: "/").map(String.init)
            var currentNode = root
            var currentPath = ""
            
            for (index, part) in parts.enumerated() {
                currentPath = currentPath.isEmpty ? part : "\(currentPath)/\(part)"
                
                if let existingChild = currentNode.children.first(where: { $0.name == part }) {
                    currentNode = existingChild
                } else {
                    let isLeaf = index == parts.count - 1
                    let newNode = TagHierarchyNode(
                        name: part,
                        fullPath: currentPath,
                        tagInfo: isLeaf ? tag : nil
                    )
                    currentNode.children.append(newNode)
                    currentNode = newNode
                }
            }
        }
        
        // Sort all children recursively: folders first, then alphabetically
        sortChildren(root)
        
        return root
    }
    
    private func sortChildren(_ node: TagHierarchyNode) {
        // Sort children: folders (has children) first, then leaf nodes, both alphabetically
        node.children.sort { a, b in
            let aIsFolder = !a.children.isEmpty
            let bIsFolder = !b.children.isEmpty
            
            if aIsFolder != bIsFolder {
                return aIsFolder // folders first
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        
        // Recursively sort children of children
        for child in node.children {
            sortChildren(child)
        }
    }
    
    func tagCount(for tagName: String) -> Int {
        appState.sessions.filter { session in
            appState.sessionMetadata[session.id]?.tags.contains(tagName) == true
        }.count
    }
    
    func folderCount(for node: TagHierarchyNode) -> Int {
        var count = 0
        if let tagInfo = node.tagInfo {
            count += tagCount(for: tagInfo.name)
        }
        for child in node.children {
            count += folderCount(for: child)
        }
        return count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tag Browser Toolbar
            HStack(spacing: 6) {
                // Search
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    TextField("Search tags...", text: $tagSearchText)
                        .textFieldStyle(.plain)
                        .font(.caption)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Spacer()
                
                // Nested toggle
                Button {
                    showNested.toggle()
                } label: {
                    Image(systemName: showNested ? "list.bullet.indent" : "list.bullet")
                        .font(.system(size: 11))
                        .foregroundStyle(showNested ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(showNested ? "Show Flat" : "Show Nested")
                
                // Expand/Collapse all
                Button {
                    if expandedFolders.isEmpty {
                        expandAllFolders(tagHierarchy)
                    } else {
                        expandedFolders.removeAll()
                    }
                } label: {
                    Image(systemName: expandedFolders.isEmpty ? "chevron.down.2" : "chevron.up.2")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(expandedFolders.isEmpty ? "Expand All" : "Collapse All")
                
                // Sort menu
                Menu {
                    ForEach(TagSortMode.allCases, id: \.self) { mode in
                        Button {
                            appState.settings.tagSortMode = mode
                            appState.saveUserData()
                        } label: {
                            HStack {
                                Text(mode.rawValue)
                                if appState.settings.tagSortMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Sort Tags")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Tag List
            if appState.allTags.isEmpty {
                ContentUnavailableView {
                    Label("No Tags", systemImage: "tag")
                } description: {
                    Text("Add tags to sessions to organize them")
                }
            } else if showNested {
                // Nested view (Obsidian style)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(tagHierarchy.children, id: \.fullPath) { node in
                            TagTreeNodeView(
                                node: node,
                                expandedFolders: $expandedFolders,
                                tagCount: tagCount,
                                folderCount: folderCount,
                                level: 0
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            } else {
                // Flat view
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredTags) { tagInfo in
                            TagFlatRowView(tagInfo: tagInfo, count: tagCount(for: tagInfo.name))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    func expandAllFolders(_ node: TagHierarchyNode) {
        for child in node.children {
            if !child.children.isEmpty {
                expandedFolders.insert(child.fullPath)
                expandAllFolders(child)
            }
        }
    }
}

// MARK: - Tag Hierarchy Node
class TagHierarchyNode: Identifiable {
    let id = UUID()
    var name: String
    var fullPath: String
    var tagInfo: TagInfo?
    var children: [TagHierarchyNode] = []
    
    init(name: String, fullPath: String, tagInfo: TagInfo? = nil) {
        self.name = name
        self.fullPath = fullPath
        self.tagInfo = tagInfo
    }
}

// MARK: - Tag Tree Node View (Recursive) - Fixed consistent sizing
struct TagTreeNodeView: View {
    @Environment(AppState.self) private var appState
    let node: TagHierarchyNode
    @Binding var expandedFolders: Set<String>
    let tagCount: (String) -> Int
    let folderCount: (TagHierarchyNode) -> Int
    let level: Int
    
    var isExpanded: Bool {
        expandedFolders.contains(node.fullPath)
    }
    
    var hasChildren: Bool {
        !node.children.isEmpty
    }
    
    var isSelected: Bool {
        if let tagInfo = node.tagInfo {
            return appState.selectedTag == tagInfo.name
        }
        return false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Node row - consistent height for all items
            HStack(spacing: 6) {
                // Expand/collapse chevron for folders
                if hasChildren {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if isExpanded {
                                expandedFolders.remove(node.fullPath)
                            } else {
                                expandedFolders.insert(node.fullPath)
                            }
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 12)
                }
                
                // Content
                if let tagInfo = node.tagInfo {
                    // Leaf tag - clickable with context menu
                    TagRowContent(tagInfo: tagInfo, displayName: node.name, count: tagCount(tagInfo.name), isSelected: isSelected)
                } else {
                    // Folder header
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "folder.fill" : "folder")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        
                        Text(node.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(folderCount(node))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .padding(.leading, CGFloat(level) * 16)
            .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Children (recursive)
            if isExpanded {
                ForEach(node.children, id: \.fullPath) { child in
                    TagTreeNodeView(
                        node: child,
                        expandedFolders: $expandedFolders,
                        tagCount: tagCount,
                        folderCount: folderCount,
                        level: level + 1
                    )
                }
            }
        }
    }
}

// MARK: - Tag Row Content (Extracted for reuse)
struct TagRowContent: View {
    @Environment(AppState.self) private var appState
    let tagInfo: TagInfo
    let displayName: String
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        Button {
            if appState.selectedTag == tagInfo.name {
                appState.selectedTag = nil
            } else {
                appState.selectedTag = tagInfo.name
            }
            appState.sidebarViewMode = .list
            appState.filterSessions()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(tagInfo.swiftUIColor)
                    .frame(width: 8, height: 8)
                
                if tagInfo.isImportant {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
                
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Spacer()
                
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            TagContextMenu(tagInfo: tagInfo)
        }
    }
}

// MARK: - Tag Flat Row View
struct TagFlatRowView: View {
    @Environment(AppState.self) private var appState
    let tagInfo: TagInfo
    let count: Int
    
    var isSelected: Bool {
        appState.selectedTag == tagInfo.name
    }
    
    var body: some View {
        Button {
            if appState.selectedTag == tagInfo.name {
                appState.selectedTag = nil
            } else {
                appState.selectedTag = tagInfo.name
            }
            appState.sidebarViewMode = .list
            appState.filterSessions()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(tagInfo.swiftUIColor)
                    .frame(width: 8, height: 8)
                
                if tagInfo.isImportant {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
                
                Text(tagInfo.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Spacer()
                
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contextMenu {
            TagContextMenu(tagInfo: tagInfo)
        }
    }
}

// MARK: - Tag Context Menu (Color & Important) - Fixed to use passed tagInfo
struct TagContextMenu: View {
    @Environment(AppState.self) private var appState
    let tagInfo: TagInfo
    
    var body: some View {
        Menu {
            ForEach(TagColors.presets, id: \.hex) { preset in
                Button {
                    let updated = TagInfo(
                        name: tagInfo.name,
                        color: preset.hex,
                        isImportant: tagInfo.isImportant,
                        parentTag: tagInfo.parentTag
                    )
                    appState.updateTagInfo(updated)
                } label: {
                    // Use SF Symbol circle.fill with foregroundColor for menu compatibility
                    Label(preset.name, systemImage: "circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color(hex: preset.hex) ?? .blue)
                }
            }
        } label: {
            Label("Change Color", systemImage: "paintpalette")
        }
        
        // Important toggle
        Button {
            let updated = TagInfo(
                name: tagInfo.name,
                color: tagInfo.color,
                isImportant: !tagInfo.isImportant,
                parentTag: tagInfo.parentTag
            )
            appState.updateTagInfo(updated)
        } label: {
            Label(
                tagInfo.isImportant ? "Remove Important" : "Mark as Important",
                systemImage: tagInfo.isImportant ? "star.slash" : "star.fill"
            )
        }
        
        Divider()
        
        // Delete
        Button(role: .destructive) {
            appState.deleteTag(tagInfo.name)
        } label: {
            Label("Delete Tag", systemImage: "trash")
        }
    }
}

// MARK: - Tag Filter Pills (Important or frequency-based)
struct TagFilterPills: View {
    @Environment(AppState.self) private var appState
    
    var visibleTags: [TagInfo] {
        // First try important tags
        let importantTags = appState.allTags.filter { $0.isImportant }
        if !importantTags.isEmpty {
            return importantTags
        }
        
        // Fallback: frequency-based (most used tags)
        let tagCounts = appState.allTags.map { tag -> (TagInfo, Int) in
            let count = appState.sessionMetadata.values.filter { $0.tags.contains(tag.name) }.count
            return (tag, count)
        }
        
        return tagCounts
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0.0 }
    }
    
    var body: some View {
        if !visibleTags.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(visibleTags) { tagInfo in
                    Button {
                        appState.selectedTag = tagInfo.name
                        appState.filterSessions()
                    } label: {
                        Text(tagInfo.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(tagInfo.swiftUIColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(tagInfo.swiftUIColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - FlowLayout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        
        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

// MARK: - Search Field (Website-inspired)
struct SearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(isFocused ? .primary : .tertiary)

            TextField("Search sessions...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.fill.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Empty Sessions View
struct EmptySessionsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ContentUnavailableView {
            Label("No Sessions", systemImage: "bubble.left.and.bubble.right")
        } description: {
            if !appState.searchText.isEmpty {
                Text("No sessions match '\(appState.searchText)'")
            } else {
                Text("No sessions found for \(appState.selectedCLI.rawValue)")
            }
        }
    }
}

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
    @State private var isHovered = false

    var isFavorite: Bool { appState.isFavorite(session.id) }
    var isPinned: Bool { appState.isPinned(session.id) }
    var isArchived: Bool { appState.isArchived(session.id) }
    var isSelected: Bool { appState.selectedSessionIds.contains(session.id) }

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
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                appState.toggleSessionSelection(session.id)
            }
        }
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
        .sheet(isPresented: $showTagSheet) {
            TagSheet(sessionId: session.id)
        }
    }
}

private func resumeSession(_ session: Session, terminal: TerminalType, bypass: Bool) {
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
            
            if !appState.allTags.isEmpty {
                Text("Existing tags:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                FlowLayout(spacing: 6) {
                    ForEach(appState.allTags.filter { !tags.contains($0.name) }) { tagInfo in
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

#Preview {
    SidebarView()
        .environment(AppState())
        .frame(width: 300)
}
