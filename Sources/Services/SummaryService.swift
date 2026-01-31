import Foundation

// MARK: - Summary Result
struct SummaryResult {
    let title: String?
    let tags: [String]
    let summary: String
    let keyPoints: [String]
    let nextSteps: [String]
    let provider: AIProvider
}

// MARK: - Summary Service
enum SummaryService {
    
    struct Config {
        let provider: AIProvider
        let apiKey: String
        let model: String
        let maxTokens: Int
        let temperature: Double
        let contextMaxMessages: Int
        let contextMaxCharsPerMessage: Int
        let contextPrompt: String
    }
    
    static func configFrom(settings: AppSettings) -> Config? {
        let provider = settings.summaryProvider
        
        let apiKey: String
        let model: String
        switch provider {
        case .openai:
            apiKey = settings.openaiKey
            model = settings.effectiveOpenaiModel
        case .anthropic:
            apiKey = settings.anthropicKey
            model = settings.effectiveAnthropicModel
        case .gemini:
            apiKey = settings.geminiKey
            model = settings.effectiveGeminiModel
        case .grok:
            apiKey = settings.grokKey
            model = settings.effectiveGrokModel
        }
        
        guard !apiKey.isEmpty else { return nil }
        
        return Config(
            provider: provider,
            apiKey: apiKey,
            model: model,
            maxTokens: settings.aiMaxTokens,
            temperature: settings.aiTemperature,
            contextMaxMessages: settings.contextMaxMessages,
            contextMaxCharsPerMessage: settings.contextMaxCharsPerMessage,
            contextPrompt: settings.contextPrompt
        )
    }
    
    // MARK: - Main Entry Point
    
    static func generateSummary(
        config: Config,
        session: Session,
        messages: [Message]
    ) async throws -> SummaryResult {
        guard !messages.isEmpty else {
            throw SummaryError.noMessages
        }
        
        let conversationText = messages.suffix(config.contextMaxMessages).map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            return "\(role): \(msg.content.prefix(config.contextMaxCharsPerMessage))"
        }.joined(separator: "\n\n")
        
        let prompt = """
        \(config.contextPrompt)

        ## 프로젝트 정보
        - 프로젝트: \(session.projectName)
        - 메시지 수: \(session.messageCount)개
        - 분석 범위: 최근 \(min(messages.count, config.contextMaxMessages))개 메시지 (각 \(config.contextMaxCharsPerMessage)자 제한)

        ## 대화 내용
        \(conversationText)
        """
        
        let request = try buildAPIRequest(config: config, prompt: prompt)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            var errorMsg = "HTTP \(httpResponse.statusCode)"
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let error = errorJson["error"] as? [String: Any], let message = error["message"] as? String {
                    errorMsg = message
                } else if let message = errorJson["message"] as? String {
                    errorMsg = message
                }
            }
            throw SummaryError.apiError("\(config.provider.rawValue) API 오류: \(errorMsg)")
        }
        
        var responseText = try parseAPIResponse(provider: config.provider, data: data)
        responseText = extractJSONFromMarkdown(responseText)
        
        if let responseData = responseText.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
            return makeResult(from: parsed, provider: config.provider)
        }
        
        if let partial = parsePartialJSON(responseText) {
            return makeResult(from: partial, provider: config.provider)
        }
        
        let cleanedText = responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return SummaryResult(
            title: nil,
            tags: [],
            summary: cleanedText,
            keyPoints: [],
            nextSteps: [],
            provider: config.provider
        )
    }
    
    // MARK: - API Request Builder
    
    private static func buildAPIRequest(config: Config, prompt: String) throws -> URLRequest {
        let url: URL
        var request: URLRequest
        let jsonData: Data
        
        switch config.provider {
        case .anthropic:
            url = URL(string: "https://api.anthropic.com/v1/messages")!
            let body: [String: Any] = [
                "model": config.model,
                "max_tokens": config.maxTokens,
                "messages": [["role": "user", "content": prompt]]
            ]
            jsonData = try JSONSerialization.data(withJSONObject: body)
            request = URLRequest(url: url)
            request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            
        case .openai:
            url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var body: [String: Any] = [
                "model": config.model,
                "max_completion_tokens": config.maxTokens,
                "messages": [["role": "user", "content": prompt]]
            ]
            let modelName = config.model.lowercased()
            let supportsTemperature = !modelName.contains("o1") && !modelName.contains("o3") && !modelName.hasPrefix("gpt-5")
            if supportsTemperature {
                body["temperature"] = config.temperature
            }
            jsonData = try JSONSerialization.data(withJSONObject: body)
            request = URLRequest(url: url)
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
            
        case .gemini:
            let apiVersion = config.model.contains("preview") ? "v1beta" : "v1beta"
            url = URL(string: "https://generativelanguage.googleapis.com/\(apiVersion)/models/\(config.model):generateContent?key=\(config.apiKey)")!
            let body: [String: Any] = [
                "contents": [["parts": [["text": prompt]]]],
                "generationConfig": ["maxOutputTokens": config.maxTokens]
            ]
            jsonData = try JSONSerialization.data(withJSONObject: body)
            request = URLRequest(url: url)
            
        case .grok:
            url = URL(string: "https://api.x.ai/v1/chat/completions")!
            let body: [String: Any] = [
                "model": config.model,
                "max_tokens": config.maxTokens,
                "temperature": config.temperature,
                "messages": [["role": "user", "content": prompt]]
            ]
            jsonData = try JSONSerialization.data(withJSONObject: body)
            request = URLRequest(url: url)
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        return request
    }
    
    // MARK: - Response Parsing
    
    private static func parseAPIResponse(provider: AIProvider, data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SummaryError.parseFailed("JSON 파싱 실패")
        }
        
        if let error = json["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown error"
            throw SummaryError.apiError("API 오류: \(message)")
        }
        
        switch provider {
        case .anthropic:
            if let errorType = json["type"] as? String, errorType == "error" {
                let message = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                throw SummaryError.apiError("Anthropic 오류: \(message)")
            }
            if let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                return text
            }
        case .openai, .grok:
            if let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
        case .gemini:
            if let errorInfo = json["error"] as? [String: Any] {
                let message = errorInfo["message"] as? String ?? "Unknown error"
                let status = errorInfo["status"] as? String ?? "ERROR"
                throw SummaryError.apiError("Gemini 오류 (\(status)): \(message)")
            }
            if let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                return text
            }
            if let promptFeedback = json["promptFeedback"] as? [String: Any],
               let blockReason = promptFeedback["blockReason"] as? String {
                throw SummaryError.apiError("콘텐츠 차단됨: \(blockReason)")
            }
        }
        
        throw SummaryError.parseFailed("응답에서 텍스트를 찾을 수 없음")
    }
    
    // MARK: - JSON Extraction Helpers
    
    static func extractJSONFromMarkdown(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let jsonMatch = result.range(of: "```json\\s*\\n?", options: .regularExpression),
           let endMatch = result.range(of: "\\n?```", options: .regularExpression, range: jsonMatch.upperBound..<result.endIndex) {
            result = String(result[jsonMatch.upperBound..<endMatch.lowerBound])
        }
        else if let jsonMatch = result.range(of: "```json\\s*\\n?", options: .regularExpression) {
            result = String(result[jsonMatch.upperBound...])
        }
        else if result.hasPrefix("```") && result.hasSuffix("```") {
            result = String(result.dropFirst(3).dropLast(3))
            if let newlineIndex = result.firstIndex(of: "\n") {
                let firstLine = String(result[..<newlineIndex]).trimmingCharacters(in: .whitespaces)
                if firstLine.allSatisfy({ $0.isLetter }) {
                    result = String(result[result.index(after: newlineIndex)...])
                }
            }
        }
        else if result.hasPrefix("```") {
            result = String(result.dropFirst(3))
            if let newlineIndex = result.firstIndex(of: "\n") {
                result = String(result[result.index(after: newlineIndex)...])
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func parsePartialJSON(_ text: String) -> [String: Any]? {
        var result: [String: Any] = [:]
        
        if let titleMatch = text.range(of: "\"title\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            let match = String(text[titleMatch])
            if let valueStart = match.range(of: ":"),
               let firstQuote = match[valueStart.upperBound...].firstIndex(of: "\"") {
                let afterQuote = match.index(after: firstQuote)
                if let lastQuote = match[afterQuote...].firstIndex(of: "\"") {
                    result["title"] = String(match[afterQuote..<lastQuote])
                }
            }
        }
        
        if let tagsStart = text.range(of: "\"tags\"\\s*:\\s*\\[", options: .regularExpression) {
            let afterBracket = text[tagsStart.upperBound...]
            if let closeBracket = afterBracket.firstIndex(of: "]") {
                let tagsContent = String(afterBracket[..<closeBracket])
                let tagPattern = "\"([^\"]+)\""
                var tags: [String] = []
                var searchRange = tagsContent.startIndex..<tagsContent.endIndex
                while let match = tagsContent.range(of: tagPattern, options: .regularExpression, range: searchRange) {
                    let tagWithQuotes = String(tagsContent[match])
                    let tag = tagWithQuotes.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    tags.append(tag)
                    searchRange = match.upperBound..<tagsContent.endIndex
                }
                result["tags"] = tags
            }
        }
        
        if let summaryMatch = text.range(of: "\"summary\"\\s*:\\s*\"", options: .regularExpression) {
            let afterQuote = text[summaryMatch.upperBound...]
            var summaryText = ""
            var escaped = false
            for char in afterQuote {
                if escaped {
                    summaryText.append(char)
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    break
                } else {
                    summaryText.append(char)
                }
            }
            if !summaryText.isEmpty {
                result["summary"] = summaryText
            }
        }
        
        return result.isEmpty ? nil : result
    }
    
    // MARK: - Result Construction
    
    private static func makeResult(from response: [String: Any], provider: AIProvider) -> SummaryResult {
        SummaryResult(
            title: response["title"] as? String,
            tags: response["tags"] as? [String] ?? [],
            summary: response["summary"] as? String ?? "Summary generated",
            keyPoints: response["keyPoints"] as? [String] ?? [],
            nextSteps: response["nextSteps"] as? [String] ?? [],
            provider: provider
        )
    }
}

// MARK: - Errors
enum SummaryError: LocalizedError {
    case noAPIKey(String)
    case noMessages
    case apiError(String)
    case parseFailed(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider): return "\(provider) API 키가 설정되지 않았습니다"
        case .noMessages: return "분석할 메시지가 없습니다"
        case .apiError(let msg): return msg
        case .parseFailed(let msg): return msg
        case .networkError(let msg): return "네트워크 오류: \(msg)"
        }
    }
}

// MARK: - Convenience: Apply Result to AppState
extension SummaryResult {
    func apply(to appState: AppState, sessionId: String) {
        if let title = title {
            appState.setSessionName(title, for: sessionId)
        }
        
        for tag in tags {
            var cleanTag = tag.hasPrefix("#") ? String(tag.dropFirst()) : tag
            cleanTag = cleanTag.replacingOccurrences(of: " ", with: "")
            if !cleanTag.isEmpty {
                appState.addTag(cleanTag, to: sessionId)
            }
        }
        
        let sessionSummary = SessionSummary(
            sessionId: sessionId,
            summary: summary,
            keyPoints: keyPoints,
            suggestedNextSteps: nextSteps,
            tags: tags,
            generatedAt: Date(),
            provider: provider
        )
        appState.saveSummary(sessionSummary)
    }
}
