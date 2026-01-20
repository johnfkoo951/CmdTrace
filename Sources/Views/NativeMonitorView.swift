import SwiftUI
import Charts

// MARK: - Native Monitor View
struct NativeMonitorView: View {
    let plan: ClaudePlan
    @State private var monitorData: MonitorData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var refreshTimer: Timer?
    @State private var refreshInterval: Double = 10.0
    @Environment(\.dismiss) private var dismiss

    // Customizable colors
    @State private var costBarColor: Color = .orange
    @State private var tokenBarColor: Color = .green
    @State private var messageBarColor: Color = .blue
    @State private var warningColor: Color = .red
    @State private var showColorPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("실시간 모니터링")
                        .font(.headline)
                    Text("\(plan.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Refresh interval
                HStack(spacing: 4) {
                    Text("새로고침:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $refreshInterval) {
                        Text("5초").tag(5.0)
                        Text("10초").tag(10.0)
                        Text("30초").tag(30.0)
                        Text("60초").tag(60.0)
                    }
                    .labelsHidden()
                    .frame(width: 70)
                    .onChange(of: refreshInterval) { _, _ in
                        setupTimer()
                    }
                }

                Button {
                    showColorPicker.toggle()
                } label: {
                    Image(systemName: "paintpalette")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showColorPicker) {
                    ColorCustomizationView(
                        costBarColor: $costBarColor,
                        tokenBarColor: $tokenBarColor,
                        messageBarColor: $messageBarColor,
                        warningColor: $warningColor
                    )
                }

                Button {
                    Task { await loadData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.regularMaterial)

            Divider()

            if isLoading && monitorData == nil {
                Spacer()
                ProgressView("데이터 로딩 중...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("다시 시도") {
                        Task { await loadData() }
                    }
                }
                Spacer()
            } else if let data = monitorData {
                ScrollView {
                    VStack(spacing: 20) {
                        // Plan Info
                        HStack {
                            Label(plan.shortName, systemImage: "person.badge.shield.checkmark")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("리셋까지: \(data.timeToReset)")
                                .font(.caption.monospaced())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(data.timeToResetMinutes < 30 ? warningColor.opacity(0.2) : Color.gray.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal)
                        .padding(.top)

                        // Usage Bars
                        VStack(spacing: 16) {
                            MonitorBarView(
                                title: "비용 사용량",
                                icon: "dollarsign.circle",
                                current: data.currentCost,
                                limit: data.costLimit,
                                formatValue: { String(format: "$%.2f", $0) },
                                barColor: costBarColor,
                                warningThreshold: 0.8
                            )

                            MonitorBarView(
                                title: "토큰 사용량",
                                icon: "number.circle",
                                current: Double(data.currentTokens),
                                limit: Double(data.tokenLimit),
                                formatValue: { ModelDisplayUtils.formatTokens(Int($0)) },
                                barColor: tokenBarColor,
                                warningThreshold: 0.8
                            )

                            MonitorBarView(
                                title: "메시지 사용량",
                                icon: "message.circle",
                                current: Double(data.currentMessages),
                                limit: Double(data.messageLimit),
                                formatValue: { "\(Int($0))" },
                                barColor: messageBarColor,
                                warningThreshold: 0.8
                            )
                        }
                        .padding(.horizontal)

                        Divider()

                        // Model Distribution
                        if !data.modelDistribution.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("모델 분포")
                                    .font(.subheadline.bold())

                                HStack(spacing: 4) {
                                    ForEach(data.modelDistribution, id: \.model) { dist in
                                        GeometryReader { geo in
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(ModelDisplayUtils.color(dist.model))
                                                .frame(width: geo.size.width * CGFloat(dist.percentage / 100.0))
                                        }
                                    }
                                }
                                .frame(height: 20)
                                .background(.quaternary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                                HStack(spacing: 16) {
                                    ForEach(data.modelDistribution, id: \.model) { dist in
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(ModelDisplayUtils.color(dist.model))
                                                .frame(width: 8, height: 8)
                                            Text("\(ModelDisplayUtils.shortName(dist.model)) \(String(format: "%.1f%%", dist.percentage))")
                                                .font(.caption2)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        Divider()

                        // Burn Rate & Predictions
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("🔥 번 레이트")
                                    .font(.caption.bold())
                                Text(String(format: "%.1f 토큰/분", data.burnRate))
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(data.burnRate > 100 ? warningColor : .primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.quaternary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("⏰ 예측")
                                    .font(.caption.bold())
                                if let exhaustTime = data.tokenExhaustionTime {
                                    Text("소진: \(exhaustTime)")
                                        .font(.caption)
                                        .foregroundStyle(warningColor)
                                } else {
                                    Text("충분한 여유")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                                Text("리셋: \(data.resetTime)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.quaternary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal)

                        Divider()

                        // Burn Rate Prediction Chart
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("📈 소비 예측 그래프")
                                    .font(.subheadline.bold())
                                Spacer()
                                if data.projectedTotalCost > 0 {
                                    Text("예상: $\(String(format: "%.2f", data.projectedTotalCost))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            BurnRateChartView(
                                currentTokens: data.currentTokens,
                                tokenLimit: data.tokenLimit,
                                currentCost: data.currentCost,
                                costLimit: data.costLimit,
                                burnRate: data.burnRate,
                                costPerHour: data.costPerHour,
                                remainingMinutes: data.timeToResetMinutes,
                                tokenBarColor: tokenBarColor,
                                costBarColor: costBarColor,
                                warningColor: warningColor
                            )
                            .frame(height: 200)
                        }
                        .padding(.horizontal)

                        // Last updated
                        HStack {
                            Spacer()
                            Text("마지막 업데이트: \(data.lastUpdated)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
        }
        .frame(width: 500, height: 700)
        .task {
            await loadData()
            setupTimer()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
    }

    private func setupTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { await loadData() }
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        // Use ccusage blocks --active for real-time 5-hour window data (same as claude-monitor)
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("ccusage_blocks_\(UUID().uuidString).json")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "ccusage blocks --active --json --breakdown 2>/dev/null > '\(tempFile.path)'"]

        do {
            try process.run()
            process.waitUntilExit()

            if FileManager.default.fileExists(atPath: tempFile.path) {
                let jsonData = try Data(contentsOf: tempFile)

                guard !jsonData.isEmpty else {
                    await MainActor.run {
                        self.errorMessage = "ccusage가 데이터를 반환하지 않았습니다"
                        self.isLoading = false
                    }
                    return
                }

                if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let blocks = json["blocks"] as? [[String: Any]],
                   let activeBlock = blocks.first(where: { $0["isActive"] as? Bool == true }) ?? blocks.last {

                    let cost = activeBlock["costUSD"] as? Double ?? 0
                    let tokens = activeBlock["totalTokens"] as? Int ?? 0
                    let models = activeBlock["models"] as? [String] ?? []

                    // Get burn rate from ccusage
                    let burnRateData = activeBlock["burnRate"] as? [String: Any]
                    let tokensPerMinute = burnRateData?["tokensPerMinute"] as? Double ?? 0
                    let costPerHour = burnRateData?["costPerHour"] as? Double ?? 0

                    // Get projection data
                    let projection = activeBlock["projection"] as? [String: Any]
                    let remainingMinutes = projection?["remainingMinutes"] as? Int ?? 0
                    let projectedTotalCost = projection?["totalCost"] as? Double ?? 0

                    // Calculate time to reset
                    let hours = remainingMinutes / 60
                    let mins = remainingMinutes % 60
                    let timeToReset = "\(hours)h \(mins)m"

                    // Get end time for reset time display
                    let endTimeStr = activeBlock["endTime"] as? String ?? ""
                    let resetTimeDisplay: String
                    if let endDate = ISO8601DateFormatter().date(from: endTimeStr) {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        resetTimeDisplay = formatter.string(from: endDate)
                    } else {
                        resetTimeDisplay = "--:--"
                    }

                    // Model distribution (simplified - equal distribution for now)
                    let modelDist = models.enumerated().map { index, model in
                        MonitorData.ModelDist(
                            model: model.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-20251101", with: ""),
                            percentage: 100.0 / Double(max(1, models.count))
                        )
                    }

                    // Calculate exhaustion time
                    var exhaustionTime: String? = nil
                    if tokensPerMinute > 0 {
                        let tokenLimit = plan.tokenLimit
                        let remaining = tokenLimit - tokens
                        if remaining > 0 && remaining < tokenLimit {
                            let minutesUntilExhaustion = Double(remaining) / tokensPerMinute
                            if minutesUntilExhaustion < Double(remainingMinutes) {
                                let exhaustionDate = Date().addingTimeInterval(minutesUntilExhaustion * 60)
                                let formatter = DateFormatter()
                                formatter.dateFormat = "HH:mm"
                                exhaustionTime = formatter.string(from: exhaustionDate)
                            }
                        }
                    }

                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm:ss"
                    let lastUpdatedStr = formatter.string(from: Date())

                    await MainActor.run {
                        self.monitorData = MonitorData(
                            currentCost: cost,
                            costLimit: plan.costLimit,
                            currentTokens: tokens,
                            tokenLimit: plan.tokenLimit,
                            currentMessages: activeBlock["entries"] as? Int ?? 0,
                            messageLimit: plan.messageLimit,
                            timeToReset: timeToReset,
                            timeToResetMinutes: remainingMinutes,
                            burnRate: tokensPerMinute,
                            costPerHour: costPerHour,
                            projectedTotalCost: projectedTotalCost,
                            tokenExhaustionTime: exhaustionTime,
                            resetTime: resetTimeDisplay,
                            modelDistribution: modelDist,
                            lastUpdated: lastUpdatedStr
                        )
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.monitorData = MonitorData(
                            currentCost: 0,
                            costLimit: plan.costLimit,
                            currentTokens: 0,
                            tokenLimit: plan.tokenLimit,
                            currentMessages: 0,
                            messageLimit: plan.messageLimit,
                            timeToReset: "활성 블록 없음",
                            timeToResetMinutes: 300,
                            burnRate: 0,
                            costPerHour: 0,
                            projectedTotalCost: 0,
                            tokenExhaustionTime: nil,
                            resetTime: "--:--",
                            modelDistribution: [],
                            lastUpdated: DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                        )
                        self.isLoading = false
                    }
                }
                try? FileManager.default.removeItem(at: tempFile)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "ccusage 실행 실패: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

// MARK: - Monitor Data Model
struct MonitorData {
    let currentCost: Double
    let costLimit: Double
    let currentTokens: Int
    let tokenLimit: Int
    let currentMessages: Int
    let messageLimit: Int
    let timeToReset: String
    let timeToResetMinutes: Int
    let burnRate: Double // tokens per minute
    let costPerHour: Double // cost per hour (from ccusage)
    let projectedTotalCost: Double // projected cost by end of block
    let tokenExhaustionTime: String?
    let resetTime: String
    let modelDistribution: [ModelDist]
    let lastUpdated: String

    struct ModelDist {
        let model: String
        let percentage: Double
    }
}

// MARK: - Burn Rate Chart View
struct BurnRateChartView: View {
    let currentTokens: Int
    let tokenLimit: Int
    let currentCost: Double
    let costLimit: Double
    let burnRate: Double // tokens per minute
    let costPerHour: Double
    let remainingMinutes: Int
    let tokenBarColor: Color
    let costBarColor: Color
    let warningColor: Color

    @State private var chartMode: ChartMode = .tokens

    enum ChartMode: String, CaseIterable {
        case tokens = "토큰"
        case cost = "비용"
    }

    // Generate projection data points
    private var projectionData: [ProjectionPoint] {
        var points: [ProjectionPoint] = []
        let now = Date()

        // Current point
        points.append(ProjectionPoint(
            time: now,
            actual: chartMode == .tokens ? Double(currentTokens) : currentCost,
            projected: nil,
            isActual: true
        ))

        // Project into the future based on burn rate
        let projectionMinutes = min(remainingMinutes, 300) // Max 5 hours
        let intervals = 10 // Number of projection points

        for i in 1...intervals {
            let minutesAhead = (projectionMinutes * i) / intervals
            let futureTime = now.addingTimeInterval(Double(minutesAhead) * 60)

            let projectedValue: Double
            if chartMode == .tokens {
                projectedValue = Double(currentTokens) + (burnRate * Double(minutesAhead))
            } else {
                projectedValue = currentCost + (costPerHour / 60.0 * Double(minutesAhead))
            }

            points.append(ProjectionPoint(
                time: futureTime,
                actual: nil,
                projected: projectedValue,
                isActual: false
            ))
        }

        return points
    }

    private var limitValue: Double {
        chartMode == .tokens ? Double(tokenLimit) : costLimit
    }

    private var currentValue: Double {
        chartMode == .tokens ? Double(currentTokens) : currentCost
    }

    private var projectedEndValue: Double {
        if chartMode == .tokens {
            return Double(currentTokens) + (burnRate * Double(remainingMinutes))
        } else {
            return currentCost + (costPerHour / 60.0 * Double(remainingMinutes))
        }
    }

    private var willExceedLimit: Bool {
        projectedEndValue > limitValue
    }

    var body: some View {
        VStack(spacing: 8) {
            // Mode selector
            Picker("Mode", selection: $chartMode) {
                ForEach(ChartMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)

            // Chart
            Chart {
                // Limit line
                RuleMark(y: .value("Limit", limitValue))
                    .foregroundStyle(warningColor.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text(chartMode == .tokens ? "한도: \(ModelDisplayUtils.formatTokens(Int(limitValue)))" : "한도: $\(String(format: "%.0f", limitValue))")
                            .font(.caption2)
                            .foregroundStyle(warningColor)
                    }

                // Current actual point
                PointMark(
                    x: .value("Time", Date()),
                    y: .value("Usage", currentValue)
                )
                .foregroundStyle(chartMode == .tokens ? tokenBarColor : costBarColor)
                .symbolSize(100)
                .annotation(position: .top) {
                    Text(chartMode == .tokens ? ModelDisplayUtils.formatTokens(Int(currentValue)) : "$\(String(format: "%.2f", currentValue))")
                        .font(.caption2.bold())
                        .foregroundStyle(chartMode == .tokens ? tokenBarColor : costBarColor)
                }

                // Projection line
                ForEach(projectionData.filter { $0.projected != nil }, id: \.time) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Projected", point.projected ?? 0)
                    )
                    .foregroundStyle(willExceedLimit ? warningColor.opacity(0.7) : Color.gray.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                }

                // Area under projection
                ForEach(projectionData, id: \.time) { point in
                    AreaMark(
                        x: .value("Time", point.time),
                        y: .value("Value", point.actual ?? point.projected ?? 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                (chartMode == .tokens ? tokenBarColor : costBarColor).opacity(0.3),
                                (chartMode == .tokens ? tokenBarColor : costBarColor).opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            if chartMode == .tokens {
                                Text(ModelDisplayUtils.formatTokens(Int(v)))
                            } else {
                                Text("$\(String(format: "%.0f", v))")
                            }
                        }
                    }
                }
            }
            .chartYScale(domain: 0...(max(limitValue * 1.2, projectedEndValue * 1.1)))

            // Projection summary
            HStack {
                if willExceedLimit {
                    Label("한도 초과 예상", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(warningColor)
                } else {
                    Label("한도 내 예상", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Spacer()
                Text(projectedEndText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var projectedEndText: String {
        let valueStr: String
        if chartMode == .tokens {
            valueStr = ModelDisplayUtils.formatTokens(Int(projectedEndValue))
        } else {
            valueStr = String(format: "$%.2f", projectedEndValue)
        }
        return "예상 종료 시: \(valueStr)"
    }
}

// Projection data point
struct ProjectionPoint: Identifiable {
    let id = UUID()
    let time: Date
    let actual: Double?
    let projected: Double?
    let isActual: Bool
}

// MARK: - Monitor Bar View
struct MonitorBarView: View {
    let title: String
    let icon: String
    let current: Double
    let limit: Double
    let formatValue: (Double) -> String
    let barColor: Color
    let warningThreshold: Double

    private var percentage: Double {
        limit > 0 ? min(current / limit, 1.0) : 0
    }

    private var isWarning: Bool {
        percentage >= warningThreshold
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(barColor)
                Text(title)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(String(format: "%.1f%%", percentage * 100))")
                    .font(.caption.monospaced())
                    .foregroundStyle(isWarning ? .red : .secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(isWarning ? .red : barColor)
                        .frame(width: max(4, geo.size.width * CGFloat(percentage)))
                }
            }
            .frame(height: 16)

            HStack {
                Text(formatValue(current))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                Text("/")
                    .foregroundStyle(.secondary)
                Text(formatValue(limit))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Color Customization View
struct ColorCustomizationView: View {
    @Binding var costBarColor: Color
    @Binding var tokenBarColor: Color
    @Binding var messageBarColor: Color
    @Binding var warningColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("색상 커스터마이징")
                .font(.headline)

            VStack(spacing: 12) {
                ColorPickerRow(title: "비용 바", color: $costBarColor)
                ColorPickerRow(title: "토큰 바", color: $tokenBarColor)
                ColorPickerRow(title: "메시지 바", color: $messageBarColor)
                ColorPickerRow(title: "경고 색상", color: $warningColor)
            }

            Divider()

            Button("기본값으로 리셋") {
                costBarColor = .orange
                tokenBarColor = .green
                messageBarColor = .blue
                warningColor = .red
            }
            .font(.caption)
        }
        .padding()
        .frame(width: 250)
    }
}

struct ColorPickerRow: View {
    let title: String
    @Binding var color: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
            Spacer()
            ColorPicker("", selection: $color)
                .labelsHidden()
        }
    }
}

