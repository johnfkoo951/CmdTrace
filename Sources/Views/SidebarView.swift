import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var tagSearchText: String = ""

    var body: some View {
        HStack(spacing: 0) {
            // LEFT: Vertical Icon Strip (cmux-style activity bar)
            SidebarActivityBar()

            Divider()

            // RIGHT: Content area
            SidebarContentArea(tagSearchText: $tagSearchText)
        }
    }
}

// MARK: - Activity Bar (Vertical Icon Strip)
struct SidebarActivityBar: View {
    @Environment(AppState.self) private var appState

    private var sessionBadge: Int? {
        let count = appState.filteredSessions.count
        return count > 0 ? count : nil
    }

    var body: some View {
        VStack(spacing: 2) {
            // Top tabs
            ForEach(AppTab.allCases, id: \.self) { tab in
                SidebarIconButton(
                    tab: tab,
                    isSelected: appState.selectedTab == tab,
                    badge: tab == .sessions ? sessionBadge : nil
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        appState.selectedTab = tab
                    }
                }
            }

            Spacer()

            // Loading indicator at bottom of activity bar
            if appState.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.bottom, 8)
            }
        }
        .padding(.vertical, 8)
        .frame(width: 44)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Sidebar Icon Button (cmux-style)
struct SidebarIconButton: View {
    let tab: AppTab
    let isSelected: Bool
    let badge: Int?
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                    .frame(width: 34, height: 34)

                // Icon
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : (isHovered ? .primary : .secondary))

                // Badge
                if let badge = badge, badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.accentColor, in: Capsule())
                        .offset(x: 10, y: -10)
                }
            }
            .frame(width: 38, height: 38)
            .overlay(alignment: .leading) {
                // Left accent bar when selected
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.accentColor)
                        .frame(width: 3, height: 18)
                        .offset(x: -2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tab.shortLabel)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Sidebar Content Area
struct SidebarContentArea: View {
    @Environment(AppState.self) private var appState
    @Binding var tagSearchText: String

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            // FIXED HEADER
            VStack(spacing: 0) {
                // Tab title + view mode toggle (sessions only)
                HStack {
                    Text(appState.selectedTab.shortLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    if appState.selectedTab == .sessions {
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
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

                // Search & filter bar (sessions tab, list mode)
                if appState.selectedTab == .sessions && appState.sidebarViewMode == .list {
                    HStack(spacing: 6) {
                        SearchField(text: $state.searchText)

                        Button {
                            Task { await appState.loadSessions() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Refresh Sessions")

                        Button {
                            state.showFavoritesOnly.toggle()
                            appState.filterSessions()
                        } label: {
                            Image(systemName: state.showFavoritesOnly ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundStyle(state.showFavoritesOnly ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(state.showFavoritesOnly ? "Show All" : "Show Favorites Only")

                        Button {
                            state.showArchivedSessions.toggle()
                            appState.filterSessions()
                        } label: {
                            Image(systemName: state.showArchivedSessions ? "archivebox.fill" : "archivebox")
                                .font(.system(size: 12))
                                .foregroundStyle(state.showArchivedSessions ? .orange : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(state.showArchivedSessions ? "Hide Archived" : "Show Archived")
                    }
                    .padding(.horizontal, 12)
                }

                // Tag search bar (sessions tab, tags mode)
                if appState.selectedTab == .sessions && appState.sidebarViewMode == .tags {
                    TagSearchBar(tagSearchText: $tagSearchText)
                        .padding(.horizontal, 12)
                }

                // Selected Tag Chip
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

                // Tag Filter Pills (sessions tab, list mode, no selected tag)
                if appState.selectedTab == .sessions && appState.sidebarViewMode == .list && appState.selectedTag == nil {
                    TagFilterPills()
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                }

                Divider()
                    .padding(.top, 8)
            }
            // END FIXED HEADER

            // Bulk action bar
            if appState.isMultiSelectMode {
                BulkActionBar()
            }

            // Main content
            if appState.selectedTab == .sessions {
                if appState.sidebarViewMode == .list {
                    if appState.isLoading {
                        Spacer()
                        ProgressView("Loading sessions...")
                            .controlSize(.small)
                        Spacer()
                    } else if appState.filteredSessions.isEmpty {
                        EmptySessionsView()
                    } else {
                        SessionListView()
                    }
                } else {
                    TagBrowserView(tagSearchText: $tagSearchText)
                }
            } else {
                // Non-session tabs show a placeholder or nothing
                // (content handled by main detail area)
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: appState.selectedTab.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text(appState.selectedTab.shortLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }

            Spacer(minLength: 0)

            // Stats bar at bottom
            StatsBar()
        }
    }
}

// MARK: - Sidebar Toggle Button (Compact)
struct SidebarToggleButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 5)
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

// MARK: - Search Field
struct SearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(isFocused ? .primary : .tertiary)

            TextField("Search...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.fill.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
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
