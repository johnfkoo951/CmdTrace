import SwiftUI

// MARK: - Tag Browser View (Obsidian Style)
struct TagBrowserView: View {
    @Environment(AppState.self) private var appState
    @State private var expandedFolders: Set<String> = []
    @State private var showNested: Bool = true
    @Binding var tagSearchText: String
    
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
            HStack(spacing: 6) {
                Button {
                    showNested.toggle()
                } label: {
                    Image(systemName: showNested ? "list.bullet.indent" : "list.bullet")
                        .font(.system(size: 11))
                        .foregroundStyle(showNested ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(showNested ? "Show Flat" : "Show Nested")
                
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
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
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
    @State private var showRenameSheet = false
    @State private var newTagName = ""
    
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
            TagContextMenu(tagInfo: tagInfo, showRenameSheet: $showRenameSheet, newTagName: $newTagName)
        }
        .sheet(isPresented: $showRenameSheet) {
            TagRenameSheet(oldName: tagInfo.name, newName: $newTagName)
        }
    }
}

// MARK: - Tag Flat Row View
struct TagFlatRowView: View {
    @Environment(AppState.self) private var appState
    let tagInfo: TagInfo
    let count: Int
    @State private var showRenameSheet = false
    @State private var newTagName = ""
    
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
            TagContextMenu(tagInfo: tagInfo, showRenameSheet: $showRenameSheet, newTagName: $newTagName)
        }
        .sheet(isPresented: $showRenameSheet) {
            TagRenameSheet(oldName: tagInfo.name, newName: $newTagName)
        }
    }
}

// MARK: - Tag Context Menu (Color & Important)
struct TagContextMenu: View {
    @Environment(AppState.self) private var appState
    let tagInfo: TagInfo
    @Binding var showRenameSheet: Bool
    @Binding var newTagName: String
    
    var body: some View {
        Button {
            newTagName = tagInfo.name
            showRenameSheet = true
        } label: {
            Label("Rename Tag", systemImage: "pencil")
        }
        
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
                    Label(preset.name, systemImage: "circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color(hex: preset.hex) ?? .blue)
                }
            }
        } label: {
            Label("Change Color", systemImage: "paintpalette")
        }
        
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
        
        Button(role: .destructive) {
            appState.deleteTag(tagInfo.name)
        } label: {
            Label("Delete Tag", systemImage: "trash")
        }
    }
}

struct TagRenameSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let oldName: String
    @Binding var newName: String
    
    var affectedSessionCount: Int {
        appState.sessionMetadata.values.filter { $0.tags.contains(oldName) }.count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Rename Tag")
                .font(.headline)
            
            TextField("Tag name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            if affectedSessionCount > 0 {
                Text("\(affectedSessionCount) session(s) will be updated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                
                Button("Rename") {
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && trimmed != oldName {
                        appState.renameTag(from: oldName, to: trimmed)
                    }
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || newName == oldName)
            }
        }
        .padding()
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

// MARK: - Tag Search Bar
struct TagSearchBar: View {
    @Binding var tagSearchText: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(isFocused ? .primary : .tertiary)
            
            TextField("Search tags...", text: $tagSearchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
            
            if !tagSearchText.isEmpty {
                Button {
                    tagSearchText = ""
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
