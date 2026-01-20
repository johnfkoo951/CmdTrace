import SwiftUI

struct UsageSection: View {
    @Binding var usageData: UsageData?
    @Binding var isLoading: Bool
    @State private var viewMode: UsageViewMode = .daily
    @State private var showAll = false
    @State private var selectedItemForBreakdown: String?
    @State private var selectedPlan: ClaudePlan = .max20
    @State private var showNativeMonitor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("API Usage")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                // claude-monitor menu
                Menu {
                    Section("플랜 선택") {
                        ForEach(ClaudePlan.allCases, id: \.self) { plan in
                            Button {
                                selectedPlan = plan
                            } label: {
                                HStack {
                                    Text(plan.displayName)
                                    if selectedPlan == plan {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    Divider()
                    Button {
                        launchClaudeMonitor(plan: selectedPlan, view: "realtime")
                    } label: {
                        Label("실시간 모니터링", systemImage: "waveform.path.ecg")
                    }
                    Button {
                        launchClaudeMonitor(plan: selectedPlan, view: "daily")
                    } label: {
                        Label("일일 리포트", systemImage: "calendar")
                    }
                    Button {
                        launchClaudeMonitor(plan: selectedPlan, view: "monthly")
                    } label: {
                        Label("월간 리포트", systemImage: "calendar.badge.clock")
                    }
                    Button {
                        launchClaudeMonitor(plan: selectedPlan, view: "session")
                    } label: {
                        Label("세션별 리포트", systemImage: "clock.arrow.circlepath")
                    }
                    Divider()
                    Button {
                        showNativeMonitor = true
                    } label: {
                        Label("내장 모니터링", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    }
                } label: {
                    Label("모니터링 (\(selectedPlan.shortName))", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .sheet(isPresented: $showNativeMonitor) {
                NativeMonitorView(plan: selectedPlan)
            }

            if let data = usageData {
                // Summary Cards
                HStack(spacing: 12) {
                    UsageStatCard(title: "총 비용", value: String(format: "$%.2f", data.totalCost), icon: "dollarsign.circle", color: .green)
                    UsageStatCard(title: "총 토큰", value: ModelDisplayUtils.formatTokens(data.totalTokens), icon: "number.circle", color: .blue)
                    UsageStatCard(title: "캐시 히트", value: ModelDisplayUtils.formatTokens(data.cacheReadTokens), icon: "bolt.circle", color: .orange)
                }

                // View Mode Picker
                Picker("View", selection: $viewMode) {
                    ForEach(UsageViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                // Content based on mode
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(viewMode.rawValue + " 사용량")
                            .font(.subheadline.bold())
                        Spacer()
                        Button(showAll ? "접기" : "전체 보기") {
                            withAnimation { showAll.toggle() }
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }

                    switch viewMode {
                    case .daily:
                        let items = showAll ? data.dailyUsage : Array(data.dailyUsage.prefix(7))
                        ForEach(items) { day in
                            DailyUsageRow(day: day, maxCost: data.maxDailyCost, isExpanded: selectedItemForBreakdown == day.date) {
                                withAnimation { selectedItemForBreakdown = selectedItemForBreakdown == day.date ? nil : day.date }
                            }
                        }

                    case .monthly:
                        let items = showAll ? data.monthlyUsage : Array(data.monthlyUsage.prefix(6))
                        ForEach(items) { month in
                            MonthlyUsageRow(month: month, maxCost: data.maxMonthlyCost, isExpanded: selectedItemForBreakdown == month.month) {
                                withAnimation { selectedItemForBreakdown = selectedItemForBreakdown == month.month ? nil : month.month }
                            }
                        }

                    case .blocks:
                        let items = showAll ? data.blockUsage : Array(data.blockUsage.prefix(10))
                        ForEach(items) { block in
                            BlockUsageRow(block: block, maxCost: data.maxBlockCost)
                        }
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if !isLoading {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("ccusage 실행 실패 - npm install -g ccusage로 설치하세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func launchClaudeMonitor(plan: ClaudePlan, view: String? = nil) {
        // Build claude-monitor command with options
        var command = "claude-monitor --plan \(plan.rawValue)"
        if let view = view {
            command += " --view \(view)"
        }

        // Launch in Terminal
        let script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

// MARK: - Claude Plan Enum
enum ClaudePlan: String, CaseIterable {
    case pro = "pro"
    case max5 = "max5"
    case max20 = "max20"

    var displayName: String {
        switch self {
        case .pro: return "Pro ($18/월, 19K 토큰)"
        case .max5: return "Max5 ($35/월, 88K 토큰)"
        case .max20: return "Max20 ($140/월, 220K 토큰)"
        }
    }

    var shortName: String {
        switch self {
        case .pro: return "Pro"
        case .max5: return "Max5"
        case .max20: return "Max20"
        }
    }
}

struct UsageStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct DailyUsageRow: View {
    let day: UsageData.DailyUsage
    let maxCost: Double
    var isExpanded: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                // Expand button
                if !day.modelBreakdowns.isEmpty {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }

                // Date
                Text(formatDate(day.date))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)

                // Cost bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.quaternary)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.cost > 5 ? .orange : .blue)
                            .frame(width: max(4, geo.size.width * CGFloat(day.cost / maxCost)))
                    }
                }
                .frame(height: 8)

                // Cost value
                Text(String(format: "$%.2f", day.cost))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(day.cost > 5 ? .orange : .primary)
                    .frame(width: 50, alignment: .trailing)

                // Models
                HStack(spacing: 4) {
                    ForEach(day.modelsUsed, id: \.self) { model in
                        Text(ModelDisplayUtils.shortName(model))
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(ModelDisplayUtils.color(model).opacity(0.2))
                            .foregroundStyle(ModelDisplayUtils.color(model))
                            .clipShape(Capsule())
                    }
                }
                .frame(width: 100, alignment: .trailing)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            // Model Breakdown (expanded)
            if isExpanded && !day.modelBreakdowns.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(day.modelBreakdowns) { breakdown in
                        ModelBreakdownRow(breakdown: breakdown)
                    }
                }
                .padding(.leading, 24)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let components = dateString.split(separator: "-")
        if components.count >= 3 {
            return "\(components[1])/\(components[2])"
        }
        return dateString
    }

}

// MARK: - Monthly Usage Row
struct MonthlyUsageRow: View {
    let month: UsageData.MonthlyUsage
    let maxCost: Double
    var isExpanded: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                // Expand button
                if !month.modelBreakdowns.isEmpty {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }

                // Month
                Text(formatMonth(month.month))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)

                // Cost bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.quaternary)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(month.cost > 50 ? .red : month.cost > 20 ? .orange : .blue)
                            .frame(width: max(4, geo.size.width * CGFloat(month.cost / maxCost)))
                    }
                }
                .frame(height: 8)

                // Cost value
                Text(String(format: "$%.2f", month.cost))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(month.cost > 50 ? .red : month.cost > 20 ? .orange : .primary)
                    .frame(width: 55, alignment: .trailing)

                // Models
                HStack(spacing: 4) {
                    ForEach(month.modelsUsed.prefix(3), id: \.self) { model in
                        Text(ModelDisplayUtils.shortName(model))
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(ModelDisplayUtils.color(model).opacity(0.2))
                            .foregroundStyle(ModelDisplayUtils.color(model))
                            .clipShape(Capsule())
                    }
                }
                .frame(width: 100, alignment: .trailing)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            // Model Breakdown (expanded)
            if isExpanded && !month.modelBreakdowns.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(month.modelBreakdowns) { breakdown in
                        ModelBreakdownRow(breakdown: breakdown)
                    }
                }
                .padding(.leading, 24)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func formatMonth(_ monthString: String) -> String {
        // "2025-12" -> "25/12"
        let components = monthString.split(separator: "-")
        if components.count >= 2 {
            let year = String(components[0].suffix(2))
            return "\(year)/\(components[1])"
        }
        return monthString
    }
}

// MARK: - Block Usage Row (5-hour rolling window)
struct BlockUsageRow: View {
    let block: UsageData.BlockUsage
    let maxCost: Double

    var body: some View {
        HStack(spacing: 12) {
            // Active indicator
            Circle()
                .fill(block.isActive ? .green : .gray.opacity(0.3))
                .frame(width: 8, height: 8)

            // Time range
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(block.startTime))
                    .font(.system(size: 10, design: .monospaced))
                Text(formatTime(block.endTime))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 70, alignment: .leading)

            // Cost bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(block.isActive ? .green : .blue)
                        .frame(width: max(4, geo.size.width * CGFloat(block.cost / maxCost)))
                }
            }
            .frame(height: 8)

            // Cost value
            Text(String(format: "$%.3f", block.cost))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(block.isActive ? .green : .primary)
                .frame(width: 55, alignment: .trailing)

            // Models
            HStack(spacing: 4) {
                ForEach(block.models.prefix(2), id: \.self) { model in
                    Text(ModelDisplayUtils.shortName(model))
                        .font(.system(size: 9))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(ModelDisplayUtils.color(model).opacity(0.2))
                        .foregroundStyle(ModelDisplayUtils.color(model))
                        .clipShape(Capsule())
                }
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ timeString: String) -> String {
        // "2025-12-13T10:00:00" -> "12/13 10:00"
        let parts = timeString.split(separator: "T")
        if parts.count == 2 {
            let dateParts = parts[0].split(separator: "-")
            let timeParts = parts[1].split(separator: ":")
            if dateParts.count >= 3 && timeParts.count >= 2 {
                return "\(dateParts[1])/\(dateParts[2]) \(timeParts[0]):\(timeParts[1])"
            }
        }
        return timeString
    }
}

// MARK: - Model Breakdown Row
struct ModelBreakdownRow: View {
    let breakdown: UsageData.ModelBreakdown

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ModelDisplayUtils.color(breakdown.modelName))
                .frame(width: 6, height: 6)

            Text(ModelDisplayUtils.shortName(breakdown.modelName))
                .font(.system(size: 10, weight: .medium))
                .frame(width: 50, alignment: .leading)

            Text("In: \(ModelDisplayUtils.formatTokens(breakdown.inputTokens))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("Out: \(ModelDisplayUtils.formatTokens(breakdown.outputTokens))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Text(String(format: "$%.2f", breakdown.cost))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(ModelDisplayUtils.color(breakdown.modelName))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Usage Tools Section
struct UsageToolsSection: View {
    @State private var copiedCommand: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("사용량 분석 도구")
                    .font(.headline)
                Spacer()
                Link(destination: URL(string: "https://github.com/ryoppippi/ccusage")!) {
                    Image(systemName: "link")
                        .font(.caption)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                // ccusage Card
                UsageToolCard(
                    name: "ccusage",
                    description: "가볍고 빠른 CLI 보고서 도구",
                    language: "Node.js",
                    languageColor: .green,
                    commands: [
                        ("설치/실행", "npx ccusage@latest"),
                        ("일일 리포트", "npx ccusage daily"),
                        ("월간 리포트", "npx ccusage monthly"),
                        ("5시간 블록", "npx ccusage blocks"),
                        ("모델별 분석", "npx ccusage daily --breakdown")
                    ],
                    githubURL: "https://github.com/ryoppippi/ccusage",
                    copiedCommand: $copiedCommand
                )

                // claude-monitor Card
                UsageToolCard(
                    name: "claude-monitor",
                    description: "실시간 모니터링 + ML 예측",
                    language: "Python",
                    languageColor: .blue,
                    commands: [
                        ("설치 (uv)", "uv tool install claude-monitor"),
                        ("설치 (pip)", "pip install claude-monitor"),
                        ("실행", "claude-monitor"),
                        ("Pro 플랜", "claude-monitor --plan pro"),
                        ("Max5 플랜", "claude-monitor --plan max5")
                    ],
                    githubURL: "https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor",
                    copiedCommand: $copiedCommand
                )
            }

            // Quick Reference
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("플랜별 토큰 한도")
                        .font(.caption.bold())

                    HStack(spacing: 24) {
                        PlanBadge(name: "Pro", tokens: "19K", cost: "$18")
                        PlanBadge(name: "Max5", tokens: "88K", cost: "$35")
                        PlanBadge(name: "Max20", tokens: "220K", cost: "$140")
                    }

                    Divider()

                    Text("5시간 롤링 세션 윈도우 - 첫 메시지 전송 시 세션 시작, 5시간 후 만료")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct UsageToolCard: View {
    let name: String
    let description: String
    let language: String
    let languageColor: Color
    let commands: [(label: String, command: String)]
    let githubURL: String
    @Binding var copiedCommand: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name)
                    .font(.subheadline.bold())

                Text(language)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(languageColor.opacity(0.2))
                    .foregroundStyle(languageColor)
                    .clipShape(Capsule())

                Spacer()

                Link(destination: URL(string: githubURL)!) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(commands, id: \.command) { item in
                    HStack(spacing: 8) {
                        Text(item.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)

                        Text(item.command)
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)

                        Spacer()

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.command, forType: .string)
                            copiedCommand = item.command

                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if copiedCommand == item.command {
                                    copiedCommand = nil
                                }
                            }
                        } label: {
                            Image(systemName: copiedCommand == item.command ? "checkmark" : "doc.on.doc")
                                .font(.caption2)
                                .foregroundStyle(copiedCommand == item.command ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PlanBadge: View {
    let name: String
    let tokens: String
    let cost: String

    var body: some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption.bold())
            Text(tokens)
                .font(.caption2)
                .foregroundStyle(.blue)
            Text(cost)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 60)
    }
}
// MARK: - Claude Plan Extension
extension ClaudePlan {
    var costLimit: Double {
        switch self {
        case .pro: return 18.0
        case .max5: return 35.0
        case .max20: return 140.0
        }
    }

    var tokenLimit: Int {
        switch self {
        case .pro: return 19_000
        case .max5: return 88_000
        case .max20: return 220_000
        }
    }

    var messageLimit: Int {
        switch self {
        case .pro: return 500
        case .max5: return 1000
        case .max20: return 2000
        }
    }
}

