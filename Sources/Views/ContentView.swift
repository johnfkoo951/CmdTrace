import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        NavigationSplitView {
            SidebarView()
        } detail: {
            ZStack {
                SessionDetailView()
                    .opacity(appState.selectedTab == .sessions ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .sessions)
                
                DashboardView()
                    .opacity(appState.selectedTab == .dashboard ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .dashboard)
                
                InteractionView()
                    .opacity(appState.selectedTab == .interaction ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .interaction)
            }
            .inspector(isPresented: $state.showInspector) {
                InspectorContent()
                    .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                CLIToolPicker()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.showInspector.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                }
            }
        }
        .preferredColorScheme(colorScheme)
    }
    
    var colorScheme: ColorScheme? {
        switch appState.settings.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct InspectorContent: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        switch appState.selectedTab {
        case .sessions:
            if let session = appState.selectedSession {
                InspectorPanel(session: session)
            } else {
                ContentUnavailableView("No Session", systemImage: "sidebar.right", description: Text("Select a session to view details"))
            }
        case .dashboard:
            DashboardInspectorPanel()
        case .interaction:
            AIInspectorPanel()
        }
    }
}

// MARK: - CLI Tool Picker (Spark Mail Style)
struct CLIToolPicker: View {
    @Environment(AppState.self) private var appState

    var enabledCLIs: [CLITool] {
        appState.settings.enabledCLIs
    }

    var body: some View {
        Menu {
            ForEach(enabledCLIs, id: \.self) { cli in
                Button {
                    withAnimation(.none) {
                        appState.selectedCLI = cli
                    }
                } label: {
                    HStack {
                        Image(systemName: appState.settings.iconFor(cli))
                        Text(cli.rawValue)
                        if cli == .antigravity {
                            Text("Beta")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.orange.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        if appState.selectedCLI == cli {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: appState.settings.iconFor(appState.selectedCLI))
                    .font(.system(size: 13))
                Text(appState.selectedCLI.rawValue)
                    .font(.system(size: 13, weight: .medium))
                if appState.selectedCLI == .antigravity {
                    Text("Beta")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
