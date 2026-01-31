import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var tagSearchText: String = ""
    
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
                    .padding(2)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
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
                                title: "AI",
                                icon: "sparkles",
                                isSelected: appState.selectedTab == .interaction
                            ) {
                                appState.selectedTab = .interaction
                            }
                        }
                        
                        HStack(spacing: 8) {
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
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                if appState.sidebarViewMode == .list {
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
                } else {
                    TagSearchBar(tagSearchText: $tagSearchText)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                }
                
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
                TagBrowserView(tagSearchText: $tagSearchText)
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
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
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

#Preview {
    SidebarView()
        .environment(AppState())
        .frame(width: 300)
}
