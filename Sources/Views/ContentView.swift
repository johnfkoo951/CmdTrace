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
                
                ProjectsView()
                    .opacity(appState.selectedTab == .projects ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .projects)
                
                DashboardView()
                    .opacity(appState.selectedTab == .dashboard ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .dashboard)
                
                ConfigurationView()
                    .opacity(appState.selectedTab == .configuration ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .configuration)
                
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
        case .projects:
            ProjectsInspectorPanel()
        case .dashboard:
            DashboardInspectorPanel()
        case .configuration:
            ConfigurationInspectorPanel()
        case .interaction:
            AIInspectorPanel()
        }
    }
}

// MARK: - CLI Tool Picker (Spark Mail Style)
struct CLIToolPicker: View {
    @Environment(AppState.self) private var appState

    var enabledCLIs: [CLITool] {
        CLITool.allCases.filter { appState.settings.enabledCLIs.contains($0) }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(enabledCLIs, id: \.self) { cli in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        appState.selectedCLI = cli
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: appState.settings.iconFor(cli))
                            .font(.system(size: 11))
                        Text(cli.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(appState.selectedCLI == cli ? Color.accentColor : Color.clear)
                    .foregroundStyle(appState.selectedCLI == cli ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
