import SwiftUI
import Charts

// MARK: - Model Display Utilities

/// Shared utilities for displaying Claude model names and colors
/// Used by DailyUsageRow, MonthlyUsageRow, BlockUsageRow, ModelBreakdownRow, NativeMonitorView
enum ModelDisplayUtils {
    /// Returns a short, human-readable model name
    static func shortName(_ model: String) -> String {
        if model.contains("opus") { return "Opus" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("haiku") { return "Haiku" }
        return String(model.prefix(6))
    }
    
    /// Returns the color associated with a model
    static func color(_ model: String) -> Color {
        if model.contains("opus") { return .purple }
        if model.contains("sonnet") { return .blue }
        if model.contains("haiku") { return .green }
        return .gray
    }
    
    /// Formats a token count with K/M suffix
    static func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000)
        }
        return "\(n)"
    }
}

struct DetailView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        switch appState.selectedTab {
        case .sessions:
            SessionDetailView()
        case .projects:
            ProjectsView()
        case .dashboard:
            DashboardView()
        case .configuration:
            ConfigurationView()
        case .interaction:
            InteractionView()
        }
    }
}

struct SessionDetailView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        if let session = appState.selectedSession {
            ConversationView(session: session)
        } else {
            ContentUnavailableView {
                Label("Select a Session", systemImage: "bubble.left.and.bubble.right")
            } description: {
                Text("Choose a session from the sidebar to view the conversation")
            }
        }
    }
}

struct ConversationView: View {
    let session: Session
    @Environment(AppState.self) private var appState
    @State private var messages: [Message] = []
    @State private var isLoading = true
    @State private var showRenameAlert = false
    @State private var newName = ""
    @State private var copySuccess = false
    
    var body: some View {
        VStack(spacing: 0) {
            SessionHeader(
                session: session,
                messages: messages,
                showRenameAlert: $showRenameAlert,
                newName: $newName,
                copySuccess: $copySuccess
            )
            
            if isLoading {
                ProgressView("Loading messages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messages.isEmpty {
                ContentUnavailableView {
                    Label("No Messages", systemImage: "bubble.left")
                } description: {
                    Text("This session has no messages")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        let filteredMessages = appState.settings.showToolCalls 
                            ? messages 
                            : messages.filter { !$0.isToolUse }
                        ForEach(filteredMessages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadMessages()
        }
        .onChange(of: session) { _, _ in
            Task { await loadMessages() }
        }
        .alert("Rename Session", isPresented: $showRenameAlert) {
            TextField("Session name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                appState.setSessionName(newName, for: session.id)
            }
        }
    }
    
    private static let sharedService = SessionService()

    private func loadMessages() async {
        isLoading = true
        do {
            messages = try await Self.sharedService.loadMessages(for: session, agent: appState.agentType)
        } catch {
            messages = []
        }
        isLoading = false
    }
}
