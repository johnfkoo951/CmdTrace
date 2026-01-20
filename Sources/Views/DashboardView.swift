import SwiftUI

// MARK: - Dashboard View
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var usageData: UsageData?
    @State private var isLoadingUsage = false
    @State private var showStatisticsSheet = false
    
    @State private var cachedTotalMessages: Int = 0
    @State private var cachedUniqueProjects: Int = 0
    @State private var cachedTodaySessions: Int = 0
    @State private var cachedProjectStats: [(project: String, sessions: Int, messages: Int)] = []
    @State private var cachedRecentActivity: [(date: String, count: Int)] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(title: "Sessions", value: "\(appState.sessions.count)", icon: "bubble.left.and.bubble.right", color: .blue)
                    StatCard(title: "Messages", value: formatNumber(cachedTotalMessages), icon: "text.bubble", color: .purple)
                    StatCard(title: "Projects", value: "\(cachedUniqueProjects)", icon: "folder", color: .orange)
                    StatCard(title: "Today", value: "\(cachedTodaySessions)", icon: "sun.max", color: .yellow)
                }
                
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activity (14 days)")
                            .font(.headline)
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(cachedRecentActivity, id: \.date) { item in
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.blue.opacity(0.8))
                                        .frame(width: 24, height: max(4, CGFloat(item.count) * 8))
                                    Text(item.date)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(height: 120, alignment: .bottom)
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Projects")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            ForEach(cachedProjectStats.prefix(8), id: \.project) { stat in
                                HStack {
                                    Text(stat.project)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(stat.sessions)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if appState.selectedCLI == .claude {
                    UsageSection(usageData: $usageData, isLoading: $isLoadingUsage)
                    UsageToolsSection()
                }
                
                Button {
                    showStatisticsSheet = true
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.doc.horizontal")
                        Text("View Full Statistics")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .sheet(isPresented: $showStatisticsSheet) {
            NavigationStack {
                StatisticsView()
                    .navigationTitle("Statistics")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showStatisticsSheet = false
                            }
                        }
                    }
            }
            .frame(minWidth: 700, minHeight: 500)
        }
        .task {
            recalculateStats()
            if appState.selectedCLI == .claude {
                await loadUsageData()
            }
        }
        .onChange(of: appState.sessions.count) { _, _ in
            recalculateStats()
        }
    }
    
    private func recalculateStats() {
        let sessions = appState.sessions
        cachedTotalMessages = sessions.reduce(0) { $0 + $1.messageCount }
        cachedUniqueProjects = Set(sessions.map { $0.project }).count
        
        let calendar = Calendar.current
        cachedTodaySessions = sessions.filter { calendar.isDateInToday($0.lastActivity) }.count
        
        let grouped = Dictionary(grouping: sessions) { $0.projectName }
        cachedProjectStats = grouped.map { (project: $0.key, sessions: $0.value.count, messages: $0.value.reduce(0) { $0 + $1.messageCount }) }
            .sorted { $0.sessions > $1.sessions }
            .prefix(10)
            .map { $0 }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        var activity: [String: Int] = [:]
        for i in 0..<14 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            activity[formatter.string(from: date)] = 0
        }
        for session in sessions {
            let key = formatter.string(from: session.lastActivity)
            if activity[key] != nil {
                activity[key]! += 1
            }
        }
        cachedRecentActivity = activity.sorted {
            formatter.date(from: $0.key)! > formatter.date(from: $1.key)!
        }.reversed().map { ($0.key, $0.value) }
    }
    
    private func loadUsageData() async {
        isLoadingUsage = true

        // Run ccusage for daily, monthly, and blocks data
        let result = await Task.detached(priority: .userInitiated) { () -> UsageData? in
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

            func runCcusage(_ command: String, outputFile: String) -> [String: Any]? {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/zsh")
                let script = """
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
                ccusage \(command) --json -o desc > "\(outputFile)" 2>&1
                """
                task.arguments = ["-c", script]
                task.currentDirectoryURL = URL(fileURLWithPath: homeDir)

                do {
                    try task.run()
                    let deadline = Date().addingTimeInterval(15)
                    while task.isRunning && Date() < deadline {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    if task.isRunning {
                        task.terminate()
                        return nil
                    }

                    if let output = try? String(contentsOfFile: outputFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                       !output.isEmpty,
                       let jsonData = output.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        try? FileManager.default.removeItem(atPath: outputFile)
                        return json
                    }
                } catch {}
                return nil
            }

            // Load all three types of data
            let dailyJson = runCcusage("daily", outputFile: "\(homeDir)/.cmdtrace-daily.json")
            let monthlyJson = runCcusage("monthly", outputFile: "\(homeDir)/.cmdtrace-monthly.json")
            let blocksJson = runCcusage("blocks", outputFile: "\(homeDir)/.cmdtrace-blocks.json")

            if dailyJson != nil || monthlyJson != nil || blocksJson != nil {
                return UsageData(dailyJson: dailyJson, monthlyJson: monthlyJson, blocksJson: blocksJson)
            }
            return nil
        }.value

        usageData = result
        isLoadingUsage = false
    }
    
    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000.0)
        }
        return "\(n)"
    }
}

// MARK: - Dashboard Inspector Panel
struct DashboardInspectorPanel: View {
    @Environment(AppState.self) private var appState
    
    @State private var cachedTagStats: [(tag: String, count: Int)] = []
    @State private var cachedFavoriteCount: Int = 0
    @State private var cachedPinnedCount: Int = 0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Overview") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("CLI", value: appState.selectedCLI.rawValue)
                        LabeledContent("Total Sessions", value: "\(appState.sessions.count)")
                        LabeledContent("Favorites", value: "\(cachedFavoriteCount)")
                        LabeledContent("Pinned", value: "\(cachedPinnedCount)")
                    }
                    .font(.caption)
                }
                
                GroupBox("Tag Distribution") {
                    VStack(alignment: .leading, spacing: 8) {
                        if cachedTagStats.isEmpty {
                            Text("No tags yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(cachedTagStats.prefix(10), id: \.tag) { stat in
                                HStack {
                                    if let tagInfo = appState.tagDatabase[stat.tag] {
                                        Circle()
                                            .fill(tagInfo.swiftUIColor)
                                            .frame(width: 8, height: 8)
                                    }
                                    Text(stat.tag)
                                        .font(.caption)
                                    Spacer()
                                    Text("\(stat.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                GroupBox("Display Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Chart Range", selection: .constant(14)) {
                            Text("7 days").tag(7)
                            Text("14 days").tag(14)
                            Text("30 days").tag(30)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .padding()
        }
        .task { recalculateStats() }
        .onChange(of: appState.sessionMetadata.count) { _, _ in recalculateStats() }
    }
    
    private func recalculateStats() {
        var counts: [String: Int] = [:]
        for (_, meta) in appState.sessionMetadata {
            for tag in meta.tags {
                counts[tag, default: 0] += 1
            }
        }
        cachedTagStats = counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
        cachedFavoriteCount = appState.sessionMetadata.values.filter { $0.isFavorite }.count
        cachedPinnedCount = appState.sessionMetadata.values.filter { $0.isPinned }.count
    }
}

