import SwiftUI

struct SessionInsightsSection: View {
    let session: Session
    let insights: SessionInsights?
    let isLoading: Bool
    
    private let labelFont: Font = .system(size: 11)
    private let smallFont: Font = .system(size: 10)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Session Insights")
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading insights...")
                        .font(smallFont)
                        .foregroundStyle(.secondary)
                }
            } else if let insights = insights, insights.totalToolCalls > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        InsightMetricView(
                            label: "Duration",
                            value: insights.formattedDuration,
                            icon: "clock",
                            color: .blue
                        )
                        
                        InsightMetricView(
                            label: "Cost",
                            value: String(format: "$%.2f", insights.estimatedCost),
                            icon: "dollarsign.circle",
                            color: .green
                        )
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    TokenUsageView(usage: insights.totalTokenUsage)
                    
                    if !insights.toolStatistics.isEmpty {
                        Divider().padding(.vertical, 4)
                        ToolUsageView(statistics: insights.toolStatistics)
                    }
                    
                    if !insights.modelUsage.isEmpty {
                        Divider().padding(.vertical, 4)
                        ModelUsageView(models: insights.modelUsage)
                    }
                    
                    if !insights.fileChanges.isEmpty {
                        Divider().padding(.vertical, 4)
                        FileChangesView(changes: insights.fileChanges)
                    }
                    
                    if !insights.errorEvents.isEmpty {
                        Divider().padding(.vertical, 4)
                        ErrorEventsView(errors: insights.errorEvents)
                    }
                    
                    if !insights.timelineEvents.isEmpty {
                        Divider().padding(.vertical, 4)
                        TimelinePreviewView(events: insights.timelineEvents)
                    }
                }
            } else {
                Text("No insights available")
                    .font(labelFont)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct InsightMetricView: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TokenUsageView: View {
    let usage: TokenUsage
    
    private var formattedTotal: String {
        formatTokenCount(usage.totalTokens)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Token Usage")
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                Text(formattedTotal)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.purple)
            }
            
            HStack(spacing: 12) {
                TokenMetric(label: "Input", value: usage.inputTokens, color: .blue)
                TokenMetric(label: "Output", value: usage.outputTokens, color: .green)
                TokenMetric(label: "Cache", value: usage.cacheCreationInputTokens, color: .orange)
            }
        }
    }
    
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

struct TokenMetric: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(formatTokenCount(value))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
        }
    }
    
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

struct ToolUsageView: View {
    let statistics: [ToolStatistics]
    @State private var isExpanded = false
    
    private var displayStats: [ToolStatistics] {
        isExpanded ? statistics : Array(statistics.prefix(5))
    }
    
    private var totalCalls: Int {
        statistics.reduce(0) { $0 + $1.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Tool Usage")
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                Text("\(statistics.count) tools · \(totalCalls) calls")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            
            ForEach(displayStats, id: \.toolName) { stat in
                ToolStatRow(stat: stat, maxCount: statistics.first?.count ?? 1)
            }
            
            if statistics.count > 5 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show Less" : "Show All (\(statistics.count))")
                            .font(.system(size: 9))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ToolStatRow: View {
    let stat: ToolStatistics
    let maxCount: Int
    
    private var progress: Double {
        guard maxCount > 0 else { return 0 }
        return Double(stat.count) / Double(maxCount)
    }
    
    private var categoryColor: Color {
        switch stat.category {
        case .fileSystem: return .blue
        case .codeEdit: return .orange
        case .search: return .purple
        case .execution: return .green
        case .web: return .cyan
        case .task: return .yellow
        case .mcp: return .pink
        case .other: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: stat.category.icon)
                .font(.system(size: 9))
                .foregroundStyle(categoryColor)
                .frame(width: 14)
            
            Text(stat.toolName)
                .font(.system(size: 10))
                .lineLimit(1)
            
            Spacer()
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(categoryColor.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(categoryColor)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(width: 60, height: 6)
            
            Text("\(stat.count)")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
        }
    }
}

struct ModelUsageView: View {
    let models: [ModelUsage]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Model Usage")
                .font(.system(size: 10, weight: .medium))
            
            ForEach(models, id: \.model) { model in
                HStack {
                    Text(model.displayName)
                        .font(.system(size: 10))
                    Spacer()
                    Text("\(model.messageCount) msgs")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct SessionConfigUsageSection: View {
    let usage: SessionConfigUsage
    
    private let smallFont: Font = .system(size: 10)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Used in Session")
            
            VStack(alignment: .leading, spacing: 8) {
                if !usage.usedCommands.isEmpty {
                    ConfigUsageRow(
                        icon: "terminal",
                        color: .blue,
                        title: "Commands",
                        items: usage.usedCommands
                    )
                }
                
                if !usage.usedSkills.isEmpty {
                    ConfigUsageRow(
                        icon: "sparkles",
                        color: .purple,
                        title: "Skills",
                        items: usage.usedSkills
                    )
                }
                
                if !usage.triggeredHooks.isEmpty {
                    ConfigUsageRow(
                        icon: "link",
                        color: .orange,
                        title: "Hooks",
                        items: usage.triggeredHooks
                    )
                }
                
                if !usage.invokedAgents.isEmpty {
                    ConfigUsageRow(
                        icon: "person.2",
                        color: .green,
                        title: "Agents",
                        items: usage.invokedAgents
                    )
                }
            }
        }
    }
}

struct ConfigUsageRow: View {
    let icon: String
    let color: Color
    let title: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                Text("(\(items.count))")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            
            FlowLayout(spacing: 4) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.15))
                        .foregroundStyle(color)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

#Preview {
    DetailView()
        .environment(AppState())
}
