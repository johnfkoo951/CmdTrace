import SwiftUI
import Charts

struct StatisticsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overviewSection
                activityChartSection
                projectDistributionSection
                tagDistributionSection
            }
            .padding()
        }
    }
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Total Sessions",
                    value: "\(appState.sessions.count)",
                    icon: "bubble.left.and.bubble.right",
                    color: .blue
                )
                
                StatCard(
                    title: "Total Messages",
                    value: formatNumber(totalMessages),
                    icon: "text.bubble",
                    color: .green
                )
                
                StatCard(
                    title: "Projects",
                    value: "\(uniqueProjects.count)",
                    icon: "folder",
                    color: .orange
                )
                
                StatCard(
                    title: "Tags Used",
                    value: "\(appState.tagDatabase.count)",
                    icon: "tag",
                    color: .purple
                )
            }
        }
    }
    
    private var activityChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity (Last 30 Days)")
                .font(.headline)
            
            Chart(dailyActivity) { item in
                BarMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Sessions", item.count)
                )
                .foregroundStyle(.blue.gradient)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var projectDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sessions by Project")
                .font(.headline)
            
            if projectCounts.isEmpty {
                Text("No project data")
                    .foregroundStyle(.secondary)
            } else {
                Chart(projectCounts.prefix(10), id: \.0) { item in
                    BarMark(
                        x: .value("Sessions", item.1),
                        y: .value("Project", item.0)
                    )
                    .foregroundStyle(.green.gradient)
                    .annotation(position: .trailing) {
                        Text("\(item.1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: CGFloat(min(projectCounts.count, 10) * 30))
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var tagDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most Used Tags")
                .font(.headline)
            
            if tagCounts.isEmpty {
                Text("No tags used yet")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                    ForEach(tagCounts.prefix(12), id: \.0) { tag, count in
                        HStack {
                            if let tagInfo = appState.tagDatabase[tag] {
                                Circle()
                                    .fill(tagInfo.swiftUIColor)
                                    .frame(width: 8, height: 8)
                            }
                            Text(tag)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text("\(count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var totalMessages: Int {
        appState.sessions.reduce(0) { $0 + $1.messageCount }
    }
    
    private var uniqueProjects: Set<String> {
        Set(appState.sessions.map { $0.projectName })
    }
    
    private var dailyActivity: [DailyActivity] {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        
        var counts: [Date: Int] = [:]
        
        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let startOfDay = calendar.startOfDay(for: date)
                counts[startOfDay] = 0
            }
        }
        
        for session in appState.sessions {
            let startOfDay = calendar.startOfDay(for: session.lastActivity)
            if startOfDay >= thirtyDaysAgo {
                counts[startOfDay, default: 0] += 1
            }
        }
        
        return counts.map { DailyActivity(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    private var projectCounts: [(String, Int)] {
        var counts: [String: Int] = [:]
        for session in appState.sessions {
            counts[session.projectName, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }
    }
    
    private var tagCounts: [(String, Int)] {
        var counts: [String: Int] = [:]
        for (_, meta) in appState.sessionMetadata {
            for tag in meta.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }
    
    private func formatNumber(_ n: Int) -> String {
        if n >= 1000000 {
            return String(format: "%.1fM", Double(n) / 1000000)
        } else if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000)
        }
        return "\(n)"
    }
}

struct DailyActivity: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}
