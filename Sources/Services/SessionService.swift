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
        guard fileManager.fileExists(atPath: claudeBasePath.path) else {
            return []
        }

        let projectDirs = try fileManager.contentsOfDirectory(
            at: claudeBasePath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        // Collect all session file URLs first
        var sessionFiles: [(url: URL, projectDir: URL)] = []
        for projectDir in projectDirs {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: projectDir.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            let files = try fileManager.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ).filter {
                $0.pathExtension == "jsonl" &&
                !$0.lastPathComponent.hasPrefix("agent-")
            }

            for file in files {
                sessionFiles.append((file, projectDir))
            }
        }

        // Parse sessions concurrently using TaskGroup
        return await withTaskGroup(of: Session?.self, returning: [Session].self) { group in
            for (file, projectDir) in sessionFiles {
                group.addTask {
                    try? self.parseClaudeSessionFast(at: file, projectDir: projectDir)
                }
            }

            var sessions: [Session] = []
            sessions.reserveCapacity(sessionFiles.count)
            for await session in group {
                if let s = session, s.messageCount > 0 {
                    sessions.append(s)
                }
            }
            return sessions.sorted { $0.lastActivity > $1.lastActivity }
        }
    }

    /// Optimized session parser: reads only head + tail of file instead of full content
    private nonisolated func parseClaudeSessionFast(at url: URL, projectDir: URL) throws -> Session {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }

        var sessionId = url.deletingPathExtension().lastPathComponent
        var preview = ""
        var cwd = ""
        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var messageCount = 0

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Get file size
        let fileSize = try fileHandle.seekToEnd()
        fileHandle.seek(toFileOffset: 0)

        let headSize: UInt64 = min(fileSize, 32_768)  // First 32KB for preview + first timestamp
        let tailSize: UInt64 = min(fileSize, 16_384)  // Last 16KB for last timestamp

        // --- HEAD: Read first 32KB for preview, cwd, sessionId, firstTimestamp ---
        let headData = fileHandle.readData(ofLength: Int(headSize))
        if let headContent = String(data: headData, encoding: .utf8) {
            headContent.enumerateSubstrings(in: headContent.startIndex..., options: [.byLines]) { substring, _, _, stop in
                guard let line = substring, !line.isEmpty,
                      let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

                if let sid = json["sessionId"] as? String, sessionId == url.deletingPathExtension().lastPathComponent {
                    sessionId = sid
                }
                if cwd.isEmpty, let workDir = json["cwd"] as? String {
                    cwd = workDir
                }
                if let ts = json["timestamp"] as? String, firstTimestamp == nil {
                    firstTimestamp = isoFormatter.date(from: ts)
                }
                if preview.isEmpty,
                   let msgType = json["type"] as? String, msgType == "user",
                   let message = json["message"] as? [String: Any],
                   let msgContent = message["content"] as? String {
                    preview = String(msgContent.prefix(200))
                }
                if let msgType = json["type"] as? String, msgType == "user" || msgType == "assistant" {
                    messageCount += 1
                }

                // Stop early if we have everything from head
                if !preview.isEmpty && !cwd.isEmpty && firstTimestamp != nil {
                    // Don't stop - still need message count from head portion
                }
            }
        }

        // --- MIDDLE: Fast line count for message count (if file is larger than head) ---
        if fileSize > headSize {
            // Count message-type lines in the remaining content
            let midStart = headSize
            let midEnd = fileSize > tailSize ? fileSize - tailSize : fileSize
            if midEnd > midStart {
                fileHandle.seek(toFileOffset: midStart)
                let midData = fileHandle.readData(ofLength: Int(midEnd - midStart))
                if let midContent = String(data: midData, encoding: .utf8) {
                    // Fast counting: check for "type":"user" or "type":"assistant" substrings
                    midContent.enumerateSubstrings(in: midContent.startIndex..., options: [.byLines]) { substring, _, _, _ in
                        guard let line = substring, !line.isEmpty else { return }
                        if line.contains("\"type\":\"user\"") || line.contains("\"type\":\"assistant\"") {
                            messageCount += 1
                        }
                    }
                }
            }

            // --- TAIL: Read last 16KB for lastTimestamp ---
            let tailStart = fileSize > tailSize ? fileSize - tailSize : 0
            if tailStart > headSize {
                fileHandle.seek(toFileOffset: tailStart)
                let tailData = fileHandle.readData(ofLength: Int(tailSize))
                if let tailContent = String(data: tailData, encoding: .utf8) {
                    tailContent.enumerateSubstrings(in: tailContent.startIndex..., options: [.byLines]) { substring, _, _, _ in
                        guard let line = substring, !line.isEmpty else { return }
                        if line.contains("\"type\":\"user\"") || line.contains("\"type\":\"assistant\"") {
                            messageCount += 1
                        }
                        guard let data = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let ts = json["timestamp"] as? String,
                              let date = isoFormatter.date(from: ts) else { return }
                        lastTimestamp = date
                    }
                }
            }
        }

        // If file was small enough to read entirely in head, last timestamp may already be set
        if lastTimestamp == nil {
            // Re-scan head for last timestamp
            if let headContent = String(data: headData, encoding: .utf8) {
                headContent.enumerateSubstrings(in: headContent.startIndex..., options: [.byLines]) { substring, _, _, _ in
                    guard let line = substring, !line.isEmpty,
                          let data = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let ts = json["timestamp"] as? String,
                          let date = isoFormatter.date(from: ts) else { return }
                    lastTimestamp = date
                }
            }
        }

        let username = NSUserName()
        let projectName = projectDir.lastPathComponent
            .replacingOccurrences(of: "-Users-\(username)-", with: "")
            .replacingOccurrences(of: "-", with: "/")

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
    
    // MARK: - Tool Detail Extraction

    /// Extracts human-readable detail from tool_use input for display in conversation
    private static func extractToolDetail(name: String, input: [String: Any]?) -> String {
        guard let input = input else { return "[Tool: \(name)]" }

        switch name {
        // File operations
        case "Read":
            if let path = input["file_path"] as? String {
                let file = (path as NSString).lastPathComponent
                let dir = ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent
                if let offset = input["offset"] as? Int, let limit = input["limit"] as? Int {
                    return "[Tool: Read] \(dir)/\(file) (lines \(offset)-\(offset+limit))"
                }
                return "[Tool: Read] \(dir)/\(file)"
            }

        case "Write":
            if let path = input["file_path"] as? String {
                let file = (path as NSString).lastPathComponent
                let dir = ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent
                let lines = (input["content"] as? String)?.components(separatedBy: "\n").count ?? 0
                return "[Tool: Write] \(dir)/\(file) (\(lines) lines)"
            }

        case "Edit":
            if let path = input["file_path"] as? String {
                let file = (path as NSString).lastPathComponent
                let oldStr = input["old_string"] as? String ?? ""
                let preview = String(oldStr.prefix(40)).replacingOccurrences(of: "\n", with: "↵")
                return "[Tool: Edit] \(file) → \"\(preview)...\""
            }

        // Search
        case "Grep":
            let pattern = input["pattern"] as? String ?? ""
            let path = (input["path"] as? String).map { ($0 as NSString).lastPathComponent } ?? ""
            return "[Tool: Grep] \"\(pattern)\" in \(path)"

        case "Glob":
            let pattern = input["pattern"] as? String ?? ""
            return "[Tool: Glob] \(pattern)"

        // Execution
        case "Bash":
            let cmd = input["command"] as? String ?? ""
            let firstLine = cmd.components(separatedBy: "\n").first ?? cmd
            let preview = firstLine.count > 80 ? String(firstLine.prefix(77)) + "..." : firstLine
            return "[Tool: Bash] $ \(preview)"

        // Web
        case "WebFetch":
            let url = input["url"] as? String ?? ""
            return "[Tool: WebFetch] \(url)"

        case "WebSearch":
            let query = input["query"] as? String ?? ""
            return "[Tool: WebSearch] \"\(query)\""

        // Task management
        case "TodoWrite", "TaskCreate":
            let todos = input["todos"] as? [[String: Any]]
            if let first = todos?.first, let content = first["content"] as? String {
                return "[Tool: \(name)] \(String(content.prefix(60)))"
            }
            if let subject = input["subject"] as? String {
                return "[Tool: \(name)] \(subject)"
            }

        // Agent
        case "Agent":
            let desc = input["description"] as? String ?? ""
            let agentType = input["subagent_type"] as? String
            if let t = agentType {
                return "[Tool: Agent] \(t) — \(desc)"
            }
            return "[Tool: Agent] \(desc)"

        // Skill
        case "Skill":
            let skill = input["skill"] as? String ?? input["name"] as? String ?? ""
            return "[Tool: Skill] /\(skill)"

        // MCP tools
        default:
            if name.hasPrefix("mcp__") {
                let parts = name.components(separatedBy: "__")
                if parts.count >= 3 {
                    let server = parts[1]
                    let tool = parts[2]
                    return "[MCP: \(server)] \(tool)"
                }
            }
        }

        return "[Tool: \(name)]"
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

        var messages: [Message] = []
        messages.reserveCapacity(session.messageCount) // Pre-allocate based on known count

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        content.enumerateSubstrings(in: content.startIndex..., options: [.byLines]) { substring, _, _, _ in
            guard let line = substring, !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let msgType = json["type"] as? String,
                  msgType == "user" || msgType == "assistant" else {
                return
            }

            let timestamp: Date?
            if let ts = json["timestamp"] as? String {
                timestamp = isoFormatter.date(from: ts)
            } else {
                timestamp = nil
            }

            guard let messageObj = json["message"] as? [String: Any] else { return }

            var msgContent = ""
            var isToolUse = false

            if let textContent = messageObj["content"] as? String {
                msgContent = textContent
            } else if let contentArray = messageObj["content"] as? [[String: Any]] {
                for item in contentArray {
                    if let type = item["type"] as? String {
                        if type == "text", let text = item["text"] as? String {
                            msgContent += text
                        } else if type == "tool_use" {
                            isToolUse = true
                            if let toolName = item["name"] as? String {
                                let detail = Self.extractToolDetail(name: toolName, input: item["input"] as? [String: Any])
                                msgContent += detail
                            }
                        }
                    }
                }
            }

            guard !msgContent.isEmpty else { return }

            let modelId = messageObj["model"] as? String
            let agentId = json["agentId"] as? String

            messages.append(Message(
                role: msgType == "user" ? .user : .assistant,
                content: msgContent,
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

        var toolCalls: [ToolCall] = []
        var hookEvents: [HookEvent] = []
        var totalTokenUsage = TokenUsage.zero
        var modelUsageDict: [String: (count: Int, tokens: TokenUsage)] = [:]
        var totalDurationMs = 0
        var fileChanges: [FileChange] = []
        var errorMessages: [String: (count: Int, timestamp: Date?, toolName: String?)] = [:]
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        content.enumerateSubstrings(in: content.startIndex..., options: [.byLines]) { substring, _, _, _ in
            guard let line = substring, !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let msgType = json["type"] as? String else {
                return
            }

            let timestamp: Date?
            if let ts = json["timestamp"] as? String {
                timestamp = isoFormatter.date(from: ts)
            } else {
                timestamp = nil
            }

            switch msgType {
            case "assistant":
                guard let messageObj = json["message"] as? [String: Any] else { return }
                
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
                            
                            if let input = item["input"] as? [String: Any] {
                                if toolName.lowercased() == "write" || toolName.lowercased() == "edit" {
                                    if let filePath = input["filePath"] as? String ?? input["file_path"] as? String {
                                        let changeType: FileChangeType = toolName.lowercased() == "write" ? .created : .modified
                                        fileChanges.append(FileChange(
                                            id: toolId,
                                            filePath: filePath,
                                            changeType: changeType,
                                            timestamp: timestamp,
                                            lineCount: nil
                                        ))
                                    }
                                } else if toolName.lowercased() == "read" {
                                    if let filePath = input["filePath"] as? String ?? input["file_path"] as? String {
                                        fileChanges.append(FileChange(
                                            id: toolId,
                                            filePath: filePath,
                                            changeType: .read,
                                            timestamp: timestamp,
                                            lineCount: nil
                                        ))
                                    }
                                }
                            }
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
                guard let subtype = json["subtype"] as? String else { return }
                
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
                
            case "user":
                if let messageObj = json["message"] as? [String: Any],
                   let contentArray = messageObj["content"] as? [[String: Any]] {
                    for item in contentArray {
                        if let type = item["type"] as? String, type == "tool_result",
                           let isError = item["is_error"] as? Bool, isError,
                           let content = item["content"] as? String {
                            let toolId = item["tool_use_id"] as? String
                            let existing = errorMessages[content] ?? (count: 0, timestamp: nil, toolName: nil)
                            errorMessages[content] = (
                                count: existing.count + 1,
                                timestamp: timestamp ?? existing.timestamp,
                                toolName: toolId ?? existing.toolName
                            )
                        }
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
        
        let errorEvents = errorMessages.map { msg, data in
            ErrorEvent(
                id: UUID().uuidString,
                message: msg,
                timestamp: data.timestamp,
                toolName: data.toolName,
                count: data.count
            )
        }.sorted { $0.count > $1.count }
        
        let uniqueFileChanges = Dictionary(grouping: fileChanges, by: { $0.filePath })
            .compactMap { _, changes -> FileChange? in
                let writes = changes.filter { $0.changeType == .created || $0.changeType == .modified }
                return writes.last ?? changes.last
            }
        
        return SessionInsights(
            sessionId: session.id,
            toolCalls: toolCalls,
            toolStatistics: toolStatistics,
            hookEvents: hookEvents,
            totalTokenUsage: totalTokenUsage,
            modelUsage: modelUsage,
            totalDurationMs: totalDurationMs,
            generatedAt: Date(),
            fileChanges: uniqueFileChanges,
            errorEvents: errorEvents
        )
    }
}
