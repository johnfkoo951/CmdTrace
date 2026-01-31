import Foundation

struct ProjectManager {
    static func allProjects(from sessions: [Session]) -> [String] {
        Array(Set(sessions.map { $0.project })).sorted()
    }

    static func sessionsForProject(_ projectPath: String, in sessions: [Session]) -> [Session] {
        sessions.filter { $0.project == projectPath }
    }

    static func stats(for projectPath: String, in sessions: [Session]) -> ProjectStats {
        let projectSessions = sessionsForProject(projectPath, in: sessions)
        let totalMessages = projectSessions.reduce(0) { $0 + $1.messageCount }
        let dates = projectSessions.map { $0.lastActivity }
        let uniqueDays = Set(dates.map { Calendar.current.startOfDay(for: $0) }).count

        return ProjectStats(
            totalSessions: projectSessions.count,
            totalMessages: totalMessages,
            firstSession: projectSessions.map { $0.firstTimestamp ?? $0.lastActivity }.min(),
            lastSession: dates.max(),
            averageMessagesPerSession: projectSessions.isEmpty ? 0 : Double(totalMessages) / Double(projectSessions.count),
            activeDays: uniqueDays
        )
    }

    static func toggleFavorite(_ path: String, in projectMetadata: inout [String: ProjectMetadata]) {
        var meta = projectMetadata[path] ?? ProjectMetadata(path: path)
        meta = ProjectMetadata(
            path: meta.path,
            customName: meta.customName,
            description: meta.description,
            languages: meta.languages,
            frameworks: meta.frameworks,
            tags: meta.tags,
            color: meta.color,
            isFavorite: !meta.isFavorite,
            isPinned: meta.isPinned,
            notes: meta.notes,
            lastOpened: meta.lastOpened,
            createdAt: meta.createdAt
        )
        projectMetadata[path] = meta
    }

    static func togglePinned(_ path: String, in projectMetadata: inout [String: ProjectMetadata]) {
        var meta = projectMetadata[path] ?? ProjectMetadata(path: path)
        meta = ProjectMetadata(
            path: meta.path,
            customName: meta.customName,
            description: meta.description,
            languages: meta.languages,
            frameworks: meta.frameworks,
            tags: meta.tags,
            color: meta.color,
            isFavorite: meta.isFavorite,
            isPinned: !meta.isPinned,
            notes: meta.notes,
            lastOpened: meta.lastOpened,
            createdAt: meta.createdAt
        )
        projectMetadata[path] = meta
    }

    static func setLanguages(_ path: String, languages: [String], in projectMetadata: inout [String: ProjectMetadata]) {
        var meta = projectMetadata[path] ?? ProjectMetadata(path: path)
        meta = ProjectMetadata(
            path: meta.path,
            customName: meta.customName,
            description: meta.description,
            languages: languages,
            frameworks: meta.frameworks,
            tags: meta.tags,
            color: meta.color,
            isFavorite: meta.isFavorite,
            isPinned: meta.isPinned,
            notes: meta.notes,
            lastOpened: meta.lastOpened,
            createdAt: meta.createdAt
        )
        projectMetadata[path] = meta
    }

    static func setFrameworks(_ path: String, frameworks: [String], in projectMetadata: inout [String: ProjectMetadata]) {
        var meta = projectMetadata[path] ?? ProjectMetadata(path: path)
        meta = ProjectMetadata(
            path: meta.path,
            customName: meta.customName,
            description: meta.description,
            languages: meta.languages,
            frameworks: frameworks,
            tags: meta.tags,
            color: meta.color,
            isFavorite: meta.isFavorite,
            isPinned: meta.isPinned,
            notes: meta.notes,
            lastOpened: meta.lastOpened,
            createdAt: meta.createdAt
        )
        projectMetadata[path] = meta
    }
}
