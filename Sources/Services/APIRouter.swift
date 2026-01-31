import Foundation

// MARK: - APIRouter

final class APIRouter {
    private weak var appState: AppState?
    private let sessionService = SessionService()
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        if request.method == "OPTIONS" {
            return .cors()
        }
        
        let components = request.pathComponents
        guard components.first == "api" else {
            return .notFound("Use /api/* endpoints")
        }
        
        let subpath = Array(components.dropFirst())
        
        guard request.method == "GET" else {
            return .notFound("Only GET supported")
        }
        
        if subpath == ["health"] { return handleHealth() }
        if subpath == ["sessions"] { return await handleGetSessions(request) }
        if subpath == ["search"] { return handleSearch(request) }
        if subpath == ["tags"] { return handleGetTags() }
        if subpath == ["metadata"] { return handleGetMetadata() }
        if subpath == ["usage"] { return await handleGetUsage() }
        if subpath == ["stats"] { return handleGetStats() }
        
        if subpath.count == 2 && subpath[0] == "sessions" {
            return await handleGetSession(id: subpath[1])
        }
        if subpath.count == 3 && subpath[0] == "sessions" && subpath[2] == "messages" {
            return await handleGetMessages(sessionId: subpath[1])
        }
        
        return .notFound("Unknown endpoint: /api/\(subpath.joined(separator: "/"))")
    }
    
    // MARK: - Handlers
    
    private func handleHealth() -> HTTPResponse {
        .json([
            "status": "ok",
            "version": "2.4.1",
            "uptime": ProcessInfo.processInfo.systemUptime
        ])
    }
    
    private func handleGetSessions(_ request: HTTPRequest) async -> HTTPResponse {
        guard let state = appState else { return .error("AppState unavailable") }
        
        let limit = Int(request.query("limit") ?? "50") ?? 50
        let offset = Int(request.query("offset") ?? "0") ?? 0
        let cli = request.query("cli")
        
        let sessions: [Session]
        if let cli = cli, let tool = CLITool(rawValue: cli) {
            let agentType: AgentType = tool == .claude ? .claude : .opencode
            sessions = (try? await sessionService.loadSessions(for: agentType)) ?? []
        } else {
            sessions = await MainActor.run { state.filteredSessions }
        }
        
        let total = sessions.count
        let paged = Array(sessions.dropFirst(offset).prefix(limit))
        
        let items = paged.map { sessionToDict($0, state: state) }
        
        return .json([
            "total": total,
            "offset": offset,
            "limit": limit,
            "items": items
        ])
    }
    
    private func handleGetSession(id: String) async -> HTTPResponse {
        guard let state = appState else { return .error("AppState unavailable") }
        
        let decodedId = id.removingPercentEncoding ?? id
        let session = await MainActor.run {
            state.sessions.first { $0.id == decodedId || $0.resumeId == decodedId }
        }
        
        guard let session = session else {
            return .notFound("Session not found: \(decodedId)")
        }
        
        var dict = sessionToDict(session, state: state)
        
        if let summary = await MainActor.run(body: { state.getSummary(for: session.id) }) {
            dict["summary"] = [
                "text": summary.summary,
                "keyPoints": summary.keyPoints,
                "nextSteps": summary.suggestedNextSteps,
                "tags": summary.tags,
                "generatedAt": ISO8601DateFormatter().string(from: summary.generatedAt)
            ] as [String: Any]
        }
        
        return .json(dict)
    }
    
    private func handleGetMessages(sessionId: String) async -> HTTPResponse {
        guard let state = appState else { return .error("AppState unavailable") }
        
        let decodedId = sessionId.removingPercentEncoding ?? sessionId
        let (session, agentType) = await MainActor.run {
            let s = state.sessions.first { $0.id == decodedId || $0.resumeId == decodedId }
            return (s, state.agentType)
        }
        
        guard let session = session else {
            return .notFound("Session not found")
        }
        
        do {
            let messages = try await sessionService.loadMessages(for: session, agent: agentType)
            let items: [[String: Any]] = messages.map { msg in
                var dict: [String: Any] = [
                    "id": msg.id.uuidString,
                    "role": msg.role.rawValue,
                    "content": msg.content,
                    "isToolUse": msg.isToolUse
                ]
                if let ts = msg.timestamp {
                    dict["timestamp"] = ISO8601DateFormatter().string(from: ts)
                }
                if let model = msg.modelId {
                    dict["model"] = model
                    dict["modelDisplay"] = msg.modelDisplayName
                }
                if let agent = msg.agentId {
                    dict["agent"] = agent
                    dict["agentDisplay"] = msg.agentDisplayName
                }
                return dict
            }
            return .json(["sessionId": decodedId, "count": items.count, "messages": items])
        } catch {
            return .error("Failed to load messages: \(error.localizedDescription)")
        }
    }
    
    private func handleSearch(_ request: HTTPRequest) -> HTTPResponse {
        guard let state = appState else { return .error("AppState unavailable") }
        guard let query = request.query("q"), !query.isEmpty else {
            return .badRequest("Missing 'q' parameter")
        }
        
        let limit = Int(request.query("limit") ?? "20") ?? 20
        
        let results = SessionFilter.filter(
            sessions: state.sessions,
            searchText: query,
            selectedTag: nil,
            showArchivedSessions: false,
            showFavoritesOnly: false,
            sessionMetadata: state.sessionMetadata
        )
        
        let items = Array(results.sessions.prefix(limit)).map { sessionToDict($0, state: state) }
        
        return .json([
            "query": query,
            "total": results.sessions.count,
            "items": items
        ])
    }
    
    private func handleGetTags() -> HTTPResponse {
        guard let state = appState else { return .error("AppState unavailable") }
        
        let tags: [[String: Any]] = state.allTags.map { tag in
            [
                "name": tag.name,
                "color": tag.color,
                "isImportant": tag.isImportant,
                "parentTag": tag.parentTag as Any,
                "count": state.tagCount(for: tag.name)
            ]
        }
        
        return .json(["tags": tags, "total": tags.count])
    }
    
    private func handleGetMetadata() -> HTTPResponse {
        guard let state = appState else { return .error("AppState unavailable") }
        
        return .json([
            "cli": state.settings.selectedCLI.rawValue,
            "theme": state.settings.theme.rawValue,
            "totalSessions": state.sessions.count,
            "totalTags": state.tagDatabase.count,
            "totalFavorites": state.sessionMetadata.values.filter { $0.isFavorite }.count,
            "totalArchived": state.sessionMetadata.values.filter { $0.isArchived }.count,
            "serverPort": 19840
        ])
    }
    
    private func handleGetUsage() async -> HTTPResponse {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "ccusage blocks --active --json --breakdown 2>/dev/null"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try? JSONSerialization.jsonObject(with: data) {
                return .json(["source": "ccusage", "data": json])
            } else {
                return .json(["source": "ccusage", "data": NSNull(), "error": "No ccusage data"])
            }
        } catch {
            return .json(["source": "ccusage", "data": NSNull(), "error": error.localizedDescription])
        }
    }
    
    private func handleGetStats() -> HTTPResponse {
        guard let state = appState else { return .error("AppState unavailable") }
        
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
        
        let recentSessions = state.sessions.filter { $0.lastActivity >= thirtyDaysAgo }
        
        var dailyCounts: [String: Int] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for session in recentSessions {
            let key = dateFormatter.string(from: session.lastActivity)
            dailyCounts[key, default: 0] += 1
        }
        
        var projectCounts: [String: Int] = [:]
        for session in state.sessions {
            projectCounts[session.projectName, default: 0] += 1
        }
        
        let topProjects = projectCounts.sorted { $0.value > $1.value }.prefix(10).map { ["name": $0.key, "count": $0.value] as [String: Any] }
        
        return .json([
            "totalSessions": state.sessions.count,
            "last30Days": recentSessions.count,
            "dailyActivity": dailyCounts,
            "topProjects": topProjects,
            "totalMessages": state.sessions.reduce(0) { $0 + $1.messageCount }
        ])
    }
    
    // MARK: - Helpers
    
    private func sessionToDict(_ session: Session, state: AppState) -> [String: Any] {
        let meta = state.sessionMetadata[session.id]
        let isoFormatter = ISO8601DateFormatter()
        
        var dict: [String: Any] = [
            "id": session.id,
            "resumeId": session.resumeId,
            "title": state.getDisplayName(for: session),
            "project": session.project,
            "projectName": session.projectName,
            "preview": session.preview,
            "messageCount": session.messageCount,
            "lastActivity": isoFormatter.string(from: session.lastActivity),
            "relativeTime": session.relativeTime,
            "dateGroup": session.dateGroup,
            "tags": state.getTags(for: session.id),
            "isFavorite": meta?.isFavorite ?? false,
            "isPinned": meta?.isPinned ?? false,
            "isArchived": meta?.isArchived ?? false,
        ]
        
        if let first = session.firstTimestamp {
            dict["firstTimestamp"] = isoFormatter.string(from: first)
        }
        if let duration = session.duration {
            dict["duration"] = duration
        }
        
        return dict
    }
}
