import Foundation

actor SessionService {
    private let claudeBasePath: URL
    private let openCodeBasePath: URL
    private let fileManager = FileManager.default
    
    private let openCodeMessagePath: URL
    private let openCodePartPath: URL
    
    init() {
        let home = fileManager.homeDirectoryForCurrentUser
        claudeBasePath = home.appendingPathComponent(".claude/projects")
        openCodeBasePath = home.appendingPathComponent(".local/share/opencode/storage/message")
        openCodeMessagePath = openCodeBasePath
        openCodePartPath = home.appendingPathComponent(".local/share/opencode/storage/part")
    }
    
    func loadSessions(for agent: AgentType) async throws -> [Session] {
        switch agent {
        case .claude:
            return try await loadClaudeSessions()
        case .opencode:
            return try await loadOpenCodeSessions()
        }
    }
    
    // MARK: - Claude Code Sessions (JSONL format)
    
    private func loadClaudeSessions() async throws -> [Session] {
        var sessions: [Session] = []
        
        guard fileManager.fileExists(atPath: claudeBasePath.path) else {
            return sessions
        }
        
        let projectDirs = try fileManager.contentsOfDirectory(
            at: claudeBasePath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        
        for projectDir in projectDirs {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: projectDir.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }
            
            // Find .jsonl files (Claude Code session format)
            // Exclude agent-*.jsonl files (sub-agent/warmup sessions)
            let sessionFiles = try fileManager.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ).filter {
                $0.pathExtension == "jsonl" &&
                !$0.lastPathComponent.hasPrefix("agent-")
            }
            
            for sessionFile in sessionFiles {
                if let session = try? parseClaudeSession(at: sessionFile, projectDir: projectDir) {
                    sessions.append(session)
                }
            }
        }
        
        return sessions
            .filter { $0.messageCount > 0 }
            .sorted { $0.lastActivity > $1.lastActivity }
    }
    
    private func parseClaudeSession(at url: URL, projectDir: URL) throws -> Session {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        var sessionId = url.deletingPathExtension().lastPathComponent
        var preview = ""
        var cwd = ""
        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var messageCount = 0
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            // Get session ID from first line
            if let sid = json["sessionId"] as? String, sessionId.isEmpty || sessionId == url.deletingPathExtension().lastPathComponent {
                sessionId = sid
            }
            
            // Get working directory
            if cwd.isEmpty, let workDir = json["cwd"] as? String {
                cwd = workDir
            }
            
            // Parse timestamp
            if let ts = json["timestamp"] as? String {
                if let date = isoFormatter.date(from: ts) {
                    if firstTimestamp == nil { firstTimestamp = date }
                    lastTimestamp = date
                }
            }
            
            // Get message content for preview
            if preview.isEmpty,
               let msgType = json["type"] as? String, msgType == "user",
               let message = json["message"] as? [String: Any],
               let content = message["content"] as? String {
                preview = String(content.prefix(200))
            }
            
            // Count messages (user and assistant)
            if let msgType = json["type"] as? String, msgType == "user" || msgType == "assistant" {
                messageCount += 1
            }
        }
        
        // Extract project name from directory
        // Dynamically detect and remove user home path prefix (e.g., "-Users-username-")
        let username = NSUserName()
        let projectName = projectDir.lastPathComponent
            .replacingOccurrences(of: "-Users-\(username)-", with: "")
            .replacingOccurrences(of: "-", with: "/")

        // Create unique ID by combining project folder and session ID
        // This prevents duplicate IDs when same session exists in multiple projects
        let uniqueId = "\(projectDir.lastPathComponent)/\(sessionId)"

        return Session(
            id: uniqueId,
            title: preview.isEmpty ? sessionId : preview,
            project: cwd.isEmpty ? projectName : cwd,
            preview: preview.isEmpty ? "No preview available" : preview,
            messageCount: messageCount,
            lastActivity: lastTimestamp ?? Date(),
            firstTimestamp: firstTimestamp,
            projectFolder: projectDir.lastPathComponent,
            fileName: url.lastPathComponent
        )
    }
    
    private func loadOpenCodeSessions() async throws -> [Session] {
        var sessions: [Session] = []
        
        guard fileManager.fileExists(atPath: openCodeBasePath.path) else {
            return sessions
        }
        
        let sessionDirs = try fileManager.contentsOfDirectory(
            at: openCodeBasePath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.lastPathComponent.hasPrefix("ses_") }
        
        for sessionDir in sessionDirs {
            if let session = try? parseOpenCodeSession(sessionDir: sessionDir) {
                sessions.append(session)
            }
        }
        
        return sessions
            .filter { $0.messageCount > 0 }
            .sorted { $0.lastActivity > $1.lastActivity }
    }
    
    private func parseOpenCodeSession(sessionDir: URL) throws -> Session {
        let sessionId = sessionDir.lastPathComponent
        
        let messageFiles = try fileManager.contentsOfDirectory(
            at: sessionDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }
        
        var preview = ""
        var cwd = ""
        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var messageCount = 0
        
        for msgFile in messageFiles {
            guard let data = try? Data(contentsOf: msgFile),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            let role = json["role"] as? String ?? ""
            if role == "user" || role == "assistant" {
                messageCount += 1
            }
            
            if cwd.isEmpty, let path = json["path"] as? [String: Any], let cwdPath = path["cwd"] as? String {
                cwd = cwdPath
            }
            
            if let timeDict = json["time"] as? [String: Any], let created = timeDict["created"] as? Int64 {
                let date = Date(timeIntervalSince1970: Double(created) / 1000.0)
                if firstTimestamp == nil { firstTimestamp = date }
                lastTimestamp = date
            }
            
            if preview.isEmpty && role == "user", let msgId = json["id"] as? String {
                preview = loadMessagePreview(messageId: msgId)
            }
        }
        
        return Session(
            id: sessionId,
            title: preview.isEmpty ? sessionId : preview,
            project: cwd,
            preview: preview.isEmpty ? "OpenCode Session" : preview,
            messageCount: messageCount,
            lastActivity: lastTimestamp ?? Date(),
            firstTimestamp: firstTimestamp,
            projectFolder: sessionDir.path,
            fileName: sessionId
        )
    }
    
    private func loadMessagePreview(messageId: String) -> String {
        let partDir = openCodePartPath.appendingPathComponent(messageId)
        guard fileManager.fileExists(atPath: partDir.path) else { return "" }
        
        guard let partFiles = try? fileManager.contentsOfDirectory(
            at: partDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter({ $0.pathExtension == "json" }) else { return "" }
        
        for partFile in partFiles {
            guard let data = try? Data(contentsOf: partFile),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String, type == "text",
                  let text = json["text"] as? String,
                  json["synthetic"] as? Bool != true else {
                continue
            }
            return String(text.prefix(200))
        }
        return ""
    }
    
    // MARK: - Load Messages
    
    func loadMessages(for session: Session, agent: AgentType) async throws -> [Message] {
        switch agent {
        case .claude:
            return try await loadClaudeMessages(for: session)
        case .opencode:
            return try await loadOpenCodeMessages(for: session)
        }
    }
    
    private func loadClaudeMessages(for session: Session) async throws -> [Message] {
        guard let projectFolder = session.projectFolder,
              let fileName = session.fileName else { return [] }
        
        let url = claudeBasePath
            .appendingPathComponent(projectFolder)
            .appendingPathComponent(fileName)
        
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        var messages: [Message] = []
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let msgType = json["type"] as? String,
                  msgType == "user" || msgType == "assistant" else {
                continue
            }
            
            let timestamp: Date?
            if let ts = json["timestamp"] as? String {
                timestamp = isoFormatter.date(from: ts)
            } else {
                timestamp = nil
            }
            
            guard let messageObj = json["message"] as? [String: Any] else { continue }
            
            var content = ""
            var isToolUse = false
            
            if let textContent = messageObj["content"] as? String {
                content = textContent
            } else if let contentArray = messageObj["content"] as? [[String: Any]] {
                for item in contentArray {
                    if let type = item["type"] as? String {
                        if type == "text", let text = item["text"] as? String {
                            content += text
                        } else if type == "tool_use" {
                            isToolUse = true
                            if let toolName = item["name"] as? String {
                                content += "[Tool: \(toolName)]"
                            }
                        }
                    }
                }
            }
            
            guard !content.isEmpty else { continue }
            
            let modelId = messageObj["model"] as? String
            let agentId = json["agentId"] as? String
            
            messages.append(Message(
                role: msgType == "user" ? .user : .assistant,
                content: content,
                timestamp: timestamp,
                modelId: modelId,
                agentId: agentId,
                isToolUse: isToolUse
            ))
        }
        
        return messages
    }
    
    private func loadOpenCodeMessages(for session: Session) async throws -> [Message] {
        guard let projectFolder = session.projectFolder else { return [] }
        
        let sessionDir = URL(fileURLWithPath: projectFolder)
        guard fileManager.fileExists(atPath: sessionDir.path) else { return [] }
        
        let messageFiles = try fileManager.contentsOfDirectory(
            at: sessionDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }
        
        var messages: [(Date, Message)] = []
        
        for msgFile in messageFiles {
            guard let data = try? Data(contentsOf: msgFile),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let role = json["role"] as? String,
                  let msgId = json["id"] as? String else {
                continue
            }
            
            var timestamp: Date?
            if let timeDict = json["time"] as? [String: Any], let created = timeDict["created"] as? Int64 {
                timestamp = Date(timeIntervalSince1970: Double(created) / 1000.0)
            }
            
            let content = loadMessageContent(messageId: msgId)
            guard !content.isEmpty else { continue }
            
            var modelId: String?
            var agentId: String?
            if let model = json["model"] as? [String: Any] {
                modelId = model["modelID"] as? String
            }
            agentId = json["agent"] as? String
            
            let message = Message(
                role: role == "user" ? .user : .assistant,
                content: content,
                timestamp: timestamp,
                modelId: modelId,
                agentId: agentId
            )
            messages.append((timestamp ?? Date.distantPast, message))
        }
        
        return messages.sorted { $0.0 < $1.0 }.map { $0.1 }
    }
    
    private func loadMessageContent(messageId: String) -> String {
        let partDir = openCodePartPath.appendingPathComponent(messageId)
        guard fileManager.fileExists(atPath: partDir.path) else { return "" }
        
        guard let partFiles = try? fileManager.contentsOfDirectory(
            at: partDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter({ $0.pathExtension == "json" }) else { return "" }
        
        var textParts: [String] = []
        for partFile in partFiles {
            guard let data = try? Data(contentsOf: partFile),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String, type == "text",
                  let text = json["text"] as? String,
                  json["synthetic"] as? Bool != true else {
                continue
            }
            textParts.append(text)
        }
        return textParts.joined(separator: "\n")
    }
    
    // MARK: - Session Insights (Tool Usage, Tokens, Hooks)
    
    func loadSessionInsights(for session: Session) async throws -> SessionInsights {
        guard let projectFolder = session.projectFolder,
              let fileName = session.fileName else {
            return .empty
        }
        
        let url = claudeBasePath
            .appendingPathComponent(projectFolder)
            .appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: url.path) else {
            return .empty
        }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        var toolCalls: [ToolCall] = []
        var hookEvents: [HookEvent] = []
        var totalTokenUsage = TokenUsage.zero
        var modelUsageDict: [String: (count: Int, tokens: TokenUsage)] = [:]
        var totalDurationMs = 0
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let msgType = json["type"] as? String else {
                continue
            }
            
            let timestamp: Date?
            if let ts = json["timestamp"] as? String {
                timestamp = isoFormatter.date(from: ts)
            } else {
                timestamp = nil
            }
            
            switch msgType {
            case "assistant":
                guard let messageObj = json["message"] as? [String: Any] else { continue }
                
                if let contentArray = messageObj["content"] as? [[String: Any]] {
                    for item in contentArray {
                        if let type = item["type"] as? String, type == "tool_use",
                           let toolId = item["id"] as? String,
                           let toolName = item["name"] as? String {
                            var inputDict: [String: AnyCodable]? = nil
                            if let input = item["input"] as? [String: Any] {
                                inputDict = input.mapValues { AnyCodable($0) }
                            }
                            toolCalls.append(ToolCall(
                                id: toolId,
                                name: toolName,
                                timestamp: timestamp,
                                input: inputDict
                            ))
                        }
                    }
                }
                
                if let usage = messageObj["usage"] as? [String: Any] {
                    let inputTokens = usage["input_tokens"] as? Int ?? 0
                    let outputTokens = usage["output_tokens"] as? Int ?? 0
                    let cacheCreation = usage["cache_creation_input_tokens"] as? Int ?? 0
                    let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                    
                    let msgTokens = TokenUsage(
                        inputTokens: inputTokens,
                        outputTokens: outputTokens,
                        cacheCreationInputTokens: cacheCreation,
                        cacheReadInputTokens: cacheRead
                    )
                    totalTokenUsage = totalTokenUsage + msgTokens
                    
                    if let model = messageObj["model"] as? String {
                        let existing = modelUsageDict[model] ?? (count: 0, tokens: .zero)
                        modelUsageDict[model] = (
                            count: existing.count + 1,
                            tokens: existing.tokens + msgTokens
                        )
                    }
                }
                
            case "system":
                guard let subtype = json["subtype"] as? String else { continue }
                
                if subtype == "stop_hook_summary" {
                    let hookCount = json["hookCount"] as? Int ?? 0
                    var hookInfos: [HookEvent.HookInfo] = []
                    if let infos = json["hookInfos"] as? [[String: Any]] {
                        hookInfos = infos.compactMap { info in
                            guard let cmd = info["command"] as? String else { return nil }
                            return HookEvent.HookInfo(command: cmd)
                        }
                    }
                    let hookErrors = json["hookErrors"] as? [String] ?? []
                    let prevented = json["preventedContinuation"] as? Bool ?? false
                    
                    hookEvents.append(HookEvent(
                        id: json["uuid"] as? String ?? UUID().uuidString,
                        timestamp: timestamp ?? Date(),
                        hookCount: hookCount,
                        hookInfos: hookInfos,
                        hookErrors: hookErrors,
                        preventedContinuation: prevented
                    ))
                } else if subtype == "turn_duration" {
                    if let duration = json["durationMs"] as? Int {
                        totalDurationMs += duration
                    }
                }
                
            default:
                break
            }
        }
        
        var toolCountDict: [String: Int] = [:]
        for call in toolCalls {
            toolCountDict[call.name, default: 0] += 1
        }
        let toolStatistics = toolCountDict.map { name, count in
            ToolStatistics(
                toolName: name,
                count: count,
                category: ToolCategory.from(toolName: name)
            )
        }.sorted { $0.count > $1.count }
        
        let modelUsage = modelUsageDict.map { model, data in
            ModelUsage(model: model, messageCount: data.count, tokenUsage: data.tokens)
        }.sorted { $0.messageCount > $1.messageCount }
        
        return SessionInsights(
            sessionId: session.id,
            toolCalls: toolCalls,
            toolStatistics: toolStatistics,
            hookEvents: hookEvents,
            totalTokenUsage: totalTokenUsage,
            modelUsage: modelUsage,
            totalDurationMs: totalDurationMs,
            generatedAt: Date()
        )
    }
}
