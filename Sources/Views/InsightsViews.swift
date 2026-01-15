import SwiftUI

struct FileChangesView: View {
    let changes: [FileChange]
    @State private var isExpanded = false
    
    private var displayChanges: [FileChange] {
        isExpanded ? changes : Array(changes.prefix(5))
    }
    
    private var modifiedCount: Int {
        changes.filter { $0.changeType == .modified || $0.changeType == .created }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("File Changes")
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                Text("\(modifiedCount) modified")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            
            ForEach(displayChanges) { change in
                FileChangeRow(change: change)
            }
            
            if changes.count > 5 {
                ExpandButton(isExpanded: $isExpanded, totalCount: changes.count)
            }
        }
    }
}

struct FileChangeRow: View {
    let change: FileChange
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: change.changeType == .read ? "eye" : "pencil")
                .font(.system(size: 9))
                .foregroundStyle(change.changeType == .read ? Color.secondary : Color.orange)
                .frame(width: 14)
            
            Text(change.fileName)
                .font(.system(size: 10))
                .lineLimit(1)
            
            Spacer()
            
            Text(change.changeType.rawValue)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }
}

struct ErrorEventsView: View {
    let errors: [ErrorEvent]
    @State private var isExpanded = false
    
    private var totalErrors: Int {
        errors.reduce(0) { $0 + $1.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                Text("Errors")
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                Text("\(totalErrors) total")
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
            }
            
            ForEach(isExpanded ? errors : Array(errors.prefix(3))) { error in
                ErrorEventRow(error: error)
            }
            
            if errors.count > 3 {
                ExpandButton(isExpanded: $isExpanded, totalCount: errors.count)
            }
        }
    }
}

struct ErrorEventRow: View {
    let error: ErrorEvent
    
    var body: some View {
        HStack(spacing: 6) {
            Text(error.shortMessage)
                .font(.system(size: 9))
                .lineLimit(2)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if error.count > 1 {
                Text("×\(error.count)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
        .padding(6)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct TimelinePreviewView: View {
    let events: [TimelineEvent]
    @State private var showFullTimeline = false
    
    private var recentEvents: [TimelineEvent] {
        Array(events.suffix(5).reversed())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Timeline")
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                Button {
                    showFullTimeline = true
                } label: {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.system(size: 9))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            
            ForEach(recentEvents) { event in
                TimelineEventRow(event: event)
            }
        }
        .sheet(isPresented: $showFullTimeline) {
            TimelineFullView(events: events)
        }
    }
}

struct TimelineEventRow: View {
    let event: TimelineEvent
    
    private var eventColor: Color {
        switch event.eventType {
        case .toolCall: return categoryColor
        case .hookTrigger: return .orange
        case .error: return .red
        case .fileChange: return .green
        }
    }
    
    private var categoryColor: Color {
        guard let cat = event.category else { return .gray }
        switch cat.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "green": return .green
        case "cyan": return .cyan
        case "yellow": return .yellow
        case "pink": return .pink
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(eventColor)
                .frame(width: 6, height: 6)
            
            Image(systemName: event.eventType.icon)
                .font(.system(size: 9))
                .foregroundStyle(eventColor)
                .frame(width: 14)
            
            Text(event.title)
                .font(.system(size: 9))
                .lineLimit(1)
            
            Spacer()
            
            Text(formatTime(event.timestamp))
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct TimelineFullView: View {
    let events: [TimelineEvent]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Session Timeline")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            .background(.bar)
            
            if events.isEmpty {
                ContentUnavailableView("No Events", systemImage: "clock", description: Text("No timeline events recorded"))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(events) { event in
                            TimelineFullRow(event: event)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct TimelineFullRow: View {
    let event: TimelineEvent
    
    private var eventColor: Color {
        switch event.eventType {
        case .toolCall:
            guard let cat = event.category else { return .gray }
            switch cat.color {
            case "blue": return .blue
            case "orange": return .orange
            case "purple": return .purple
            case "green": return .green
            case "cyan": return .cyan
            case "yellow": return .yellow
            case "pink": return .pink
            default: return .gray
            }
        case .hookTrigger: return .orange
        case .error: return .red
        case .fileChange: return .green
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(eventColor)
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 2)
            }
            .frame(width: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: event.eventType.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(eventColor)
                    
                    Text(event.title)
                        .font(.system(size: 12, weight: .medium))
                    
                    Spacer()
                    
                    Text(formatTimestamp(event.timestamp))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                
                if let detail = event.detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 16)
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

struct ExpandButton: View {
    @Binding var isExpanded: Bool
    let totalCount: Int
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Text(isExpanded ? "Show Less" : "Show All (\(totalCount))")
                    .font(.system(size: 9))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
    }
}
