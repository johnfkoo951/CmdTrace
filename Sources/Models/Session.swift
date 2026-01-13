import Foundation

struct Session: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let project: String
    let preview: String
    let messageCount: Int
    let lastActivity: Date
    let firstTimestamp: Date?
    let customName: String?
    let tags: [String]
    let projectFolder: String?
    let fileName: String?
    
    var displayTitle: String {
        customName ?? preview.prefix(50).description
    }
    
    var projectName: String {
        project.components(separatedBy: "/").last ?? project
    }
    
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastActivity, relativeTo: Date())
    }
    
    var duration: String? {
        guard let start = firstTimestamp else { return nil }
        let interval = lastActivity.timeIntervalSince(start)
        if interval < 60 {
            return "<1m"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            let mins = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        }
    }
    
    var lastMessageTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: lastActivity)
    }
    
    var startTime: String? {
        guard let start = firstTimestamp else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: start)
    }
    
    /// Date string for grouping (e.g., "Today", "Yesterday", "Jan 12")
    var dateGroup: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(lastActivity) {
            return "Today"
        } else if calendar.isDateInYesterday(lastActivity) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: lastActivity)
        }
    }
    
    /// Short date for display (e.g., "1/12")
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: lastActivity)
    }

    /// Session ID for resume command (without project folder prefix)
    var resumeId: String {
        // Extract from fileName (e.g., "b219c46c-3d27-4bcd-84ae-666c18411ae4.jsonl" -> "b219c46c-3d27-4bcd-84ae-666c18411ae4")
        if let name = fileName {
            return name.replacingOccurrences(of: ".jsonl", with: "")
        }
        // Fallback: extract from id (e.g., "projectFolder/sessionId" -> "sessionId")
        if id.contains("/") {
            return id.components(separatedBy: "/").last ?? id
        }
        return id
    }

    enum CodingKeys: String, CodingKey {
        case id = "sessionId"
        case title
        case project
        case preview
        case messageCount
        case lastActivity = "lastTimestamp"
        case firstTimestamp
        case customName
        case tags
        case projectFolder
        case fileName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        project = try container.decodeIfPresent(String.self, forKey: .project) ?? ""
        preview = try container.decodeIfPresent(String.self, forKey: .preview) ?? ""
        messageCount = try container.decodeIfPresent(Int.self, forKey: .messageCount) ?? 0
        customName = try container.decodeIfPresent(String.self, forKey: .customName)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        projectFolder = try container.decodeIfPresent(String.self, forKey: .projectFolder)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        
        if let timestamp = try container.decodeIfPresent(String.self, forKey: .lastActivity) {
            lastActivity = ISO8601DateFormatter().date(from: timestamp) ?? Date()
        } else {
            lastActivity = Date()
        }
        
        if let timestamp = try container.decodeIfPresent(String.self, forKey: .firstTimestamp) {
            firstTimestamp = ISO8601DateFormatter().date(from: timestamp)
        } else {
            firstTimestamp = nil
        }
    }
    
    init(id: String, title: String, project: String, preview: String, messageCount: Int, lastActivity: Date, firstTimestamp: Date? = nil, customName: String? = nil, tags: [String] = [], projectFolder: String? = nil, fileName: String? = nil) {
        self.id = id
        self.title = title
        self.project = project
        self.preview = preview
        self.messageCount = messageCount
        self.lastActivity = lastActivity
        self.firstTimestamp = firstTimestamp
        self.customName = customName
        self.tags = tags
        self.projectFolder = projectFolder
        self.fileName = fileName
    }
}
