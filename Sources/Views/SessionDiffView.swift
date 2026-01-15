import SwiftUI

struct SessionDiffView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let baseSession: Session
    @State private var compareSession: Session?
    @State private var baseMessages: [Message] = []
    @State private var compareMessages: [Message] = []
    @State private var isLoading = false
    @State private var diffMode: DiffMode = .sideBySide
    
    enum DiffMode: String, CaseIterable {
        case sideBySide = "Side by Side"
        case unified = "Unified"
        case stats = "Statistics"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            if compareSession == nil {
                sessionPicker
            } else if isLoading {
                ProgressView("Loading sessions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                diffContent
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private var header: some View {
        HStack {
            Text("Session Comparison")
                .font(.headline)
            
            Spacer()
            
            if compareSession != nil {
                Picker("View", selection: $diffMode) {
                    ForEach(DiffMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            
            Spacer()
            
            Button("Done") { dismiss() }
        }
        .padding()
    }
    
    private var sessionPicker: some View {
        VStack(spacing: 20) {
            Text("Select a session to compare with")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Text("Base: \(appState.getDisplayName(for: baseSession))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(appState.sessions.filter { $0.id != baseSession.id }) { session in
                        SessionPickerRow(session: session) {
                            compareSession = session
                            Task { await loadBothSessions() }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var diffContent: some View {
        Group {
            switch diffMode {
            case .sideBySide:
                sideBySideView
            case .unified:
                unifiedView
            case .stats:
                statsView
            }
        }
    }
    
    private var sideBySideView: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                sessionInfoHeader(baseSession, label: "Base", color: .blue)
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(baseMessages) { msg in
                            CompactMessageRow(message: msg, highlightColor: .blue)
                        }
                    }
                    .padding()
                }
            }
            
            Divider()
            
            VStack(spacing: 0) {
                if let compare = compareSession {
                    sessionInfoHeader(compare, label: "Compare", color: .green)
                }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(compareMessages) { msg in
                            CompactMessageRow(message: msg, highlightColor: .green)
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var unifiedView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(mergedMessages, id: \.id) { item in
                    UnifiedDiffRow(item: item)
                }
            }
            .padding()
        }
    }
    
    private var statsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 40) {
                    StatComparisonCard(
                        title: "Messages",
                        baseValue: baseMessages.count,
                        compareValue: compareMessages.count
                    )
                    
                    StatComparisonCard(
                        title: "User Messages",
                        baseValue: baseMessages.filter { $0.role == .user }.count,
                        compareValue: compareMessages.filter { $0.role == .user }.count
                    )
                    
                    StatComparisonCard(
                        title: "Assistant Messages",
                        baseValue: baseMessages.filter { $0.role == .assistant }.count,
                        compareValue: compareMessages.filter { $0.role == .assistant }.count
                    )
                    
                    StatComparisonCard(
                        title: "Tool Calls",
                        baseValue: baseMessages.filter { $0.isToolUse }.count,
                        compareValue: compareMessages.filter { $0.isToolUse }.count
                    )
                }
                .padding()
                
                Divider()
                
                HStack(alignment: .top, spacing: 40) {
                    ToolUsageComparison(
                        title: "Base Session Tools",
                        messages: baseMessages,
                        color: .blue
                    )
                    
                    ToolUsageComparison(
                        title: "Compare Session Tools",
                        messages: compareMessages,
                        color: .green
                    )
                }
                .padding()
            }
        }
    }
    
    private func sessionInfoHeader(_ session: Session, label: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
            Text(appState.getDisplayName(for: session))
                .font(.caption)
                .lineLimit(1)
            Spacer()
            Text("\(session.messageCount) msgs")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
    }
    
    private var mergedMessages: [UnifiedDiffItem] {
        var items: [UnifiedDiffItem] = []
        
        let baseSet = Set(baseMessages.map { $0.content.prefix(100) })
        let compareSet = Set(compareMessages.map { $0.content.prefix(100) })
        
        for msg in baseMessages {
            let prefix = msg.content.prefix(100)
            if compareSet.contains(prefix) {
                items.append(UnifiedDiffItem(message: msg, diffType: .unchanged))
            } else {
                items.append(UnifiedDiffItem(message: msg, diffType: .removed))
            }
        }
        
        for msg in compareMessages {
            let prefix = msg.content.prefix(100)
            if !baseSet.contains(prefix) {
                items.append(UnifiedDiffItem(message: msg, diffType: .added))
            }
        }
        
        return items.sorted { ($0.message.timestamp ?? Date.distantPast) < ($1.message.timestamp ?? Date.distantPast) }
    }
    
    private func loadBothSessions() async {
        isLoading = true
        let service = SessionService()
        
        do {
            baseMessages = try await service.loadMessages(for: baseSession, agent: appState.agentType)
            if let compare = compareSession {
                compareMessages = try await service.loadMessages(for: compare, agent: appState.agentType)
            }
        } catch {
            baseMessages = []
            compareMessages = []
        }
        
        isLoading = false
    }
}

struct SessionPickerRow: View {
    let session: Session
    let onSelect: () -> Void
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.getDisplayName(for: session))
                        .font(.system(size: 13, weight: .medium))
                    HStack(spacing: 8) {
                        Text(session.projectName)
                        Text("•")
                        Text("\(session.messageCount) messages")
                        Text("•")
                        Text(session.relativeTime)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct CompactMessageRow: View {
    let message: Message
    let highlightColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: message.role == .user ? "person.circle.fill" : "sparkles")
                .font(.system(size: 12))
                .foregroundStyle(message.role == .user ? .blue : .purple)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.role.rawValue.capitalized)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Text(message.content.prefix(200) + (message.content.count > 200 ? "..." : ""))
                    .font(.system(size: 11))
                    .lineLimit(4)
            }
            
            Spacer()
        }
        .padding(8)
        .background(highlightColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct UnifiedDiffItem: Identifiable {
    let id = UUID()
    let message: Message
    let diffType: DiffType
    
    enum DiffType {
        case added, removed, unchanged
    }
}

struct UnifiedDiffRow: View {
    let item: UnifiedDiffItem
    
    var backgroundColor: Color {
        switch item.diffType {
        case .added: return .green.opacity(0.15)
        case .removed: return .red.opacity(0.15)
        case .unchanged: return .clear
        }
    }
    
    var prefix: String {
        switch item.diffType {
        case .added: return "+"
        case .removed: return "-"
        case .unchanged: return " "
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(prefix)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(item.diffType == .added ? .green : (item.diffType == .removed ? .red : .secondary))
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.message.role.rawValue.capitalized)
                        .font(.system(size: 10, weight: .semibold))
                    Spacer()
                    if let timestamp = item.message.timestamp {
                        Text(timestamp, style: .time)
                            .font(.system(size: 9))
                    }
                }
                .foregroundStyle(.secondary)
                
                Text(item.message.content.prefix(300) + (item.message.content.count > 300 ? "..." : ""))
                    .font(.system(size: 11))
            }
        }
        .padding(8)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct StatComparisonCard: View {
    let title: String
    let baseValue: Int
    let compareValue: Int
    
    var diff: Int { compareValue - baseValue }
    var diffColor: Color {
        if diff > 0 { return .green }
        if diff < 0 { return .red }
        return .secondary
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                VStack {
                    Text("\(baseValue)")
                        .font(.title2.bold())
                        .foregroundStyle(.blue)
                    Text("Base")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                VStack {
                    Text("\(compareValue)")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                    Text("Compare")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            if diff != 0 {
                Text(diff > 0 ? "+\(diff)" : "\(diff)")
                    .font(.caption.bold())
                    .foregroundStyle(diffColor)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ToolUsageComparison: View {
    let title: String
    let messages: [Message]
    let color: Color
    
    var toolCounts: [(String, Int)] {
        var counts: [String: Int] = [:]
        for msg in messages where msg.isToolUse {
            if let toolUses = msg.toolUses {
                for tool in toolUses {
                    counts[tool.name, default: 0] += 1
                }
            } else {
                counts["Unknown", default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
            
            if toolCounts.isEmpty {
                Text("No tool calls")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(toolCounts.prefix(10), id: \.0) { tool, count in
                    HStack {
                        Text(tool)
                            .font(.system(size: 11))
                            .lineLimit(1)
                        Spacer()
                        Text("\(count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(color)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
