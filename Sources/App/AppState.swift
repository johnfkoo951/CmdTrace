import SwiftUI
import Observation

// MARK: - Enums
enum AppTab: String, CaseIterable {
    case sessions = "Sessions"
    case dashboard = "Dashboard"
    case configuration = "Configuration"
    case interaction = "Interaction"
    
    var icon: String {
        switch self {
        case .sessions: return "bubble.left.and.bubble.right"
        case .dashboard: return "chart.bar"
        case .configuration: return "gearshape.2"
        case .interaction: return "sparkles"
        }
    }
}

enum CLITool: String, CaseIterable, Codable, Equatable {
    case claude = "Claude Code"
    case opencode = "OpenCode"
    case antigravity = "Antigravity"
    
    var defaultIcon: String {
        switch self {
        case .claude: return "c.circle.fill"
        case .opencode: return "o.circle.fill"
        case .antigravity: return "a.circle.fill"
        }
    }
}

enum SidebarViewMode: String, CaseIterable {
    case list = "List"
    case tags = "Tags"
}

enum AppTheme: String, CaseIterable, Codable, Equatable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

enum AIProvider: String, CaseIterable, Codable, Equatable {
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case gemini = "Gemini"
    case grok = "Grok"
}

enum TerminalType {
    case terminal, iterm, warp
}

enum TagSortMode: String, CaseIterable, Codable, Equatable {
    case important = "Important First"
    case alphabetical = "Alphabetical"
    case countDesc = "Most Used"
    case countAsc = "Least Used"
}

// MARK: - Tag Data Model
struct TagInfo: Codable, Identifiable, Equatable, Hashable {
    var id: String { name }
    var name: String
    var color: String // hex color
    var isImportant: Bool
    var parentTag: String? // for nested tags
    
    init(name: String, color: String = "#3B82F6", isImportant: Bool = false, parentTag: String? = nil) {
        self.name = name
        self.color = color
        self.isImportant = isImportant
        self.parentTag = parentTag
    }
    
    var swiftUIColor: Color {
        Color(hex: color) ?? .blue
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

// MARK: - Session Metadata
struct SessionMetadata: Codable, Equatable {
    var isFavorite: Bool = false
    var isPinned: Bool = false
    var isArchived: Bool = false
    var archivedAt: Date?
    var customName: String?
    var tags: [String] = []
}

// MARK: - Settings
struct AppSettings: Codable, Equatable {
    var selectedCLI: CLITool = .claude
    var theme: AppTheme = .system
    var enabledCLIs: [CLITool] = [.claude, .opencode]
    
    // CLI Custom Icons
    var cliIcons: [String: String] = [:] // CLI rawValue -> SF Symbol name
    
    // API Keys
    var openaiKey: String = ""
    var anthropicKey: String = ""
    var geminiKey: String = ""
    var grokKey: String = ""
    
    // AI Tasks
    var summaryProvider: AIProvider = .anthropic
    var suggestionProvider: AIProvider = .openai
    var reminderHours: Int = 24
    var enableReminders: Bool = true
    var enableSuggestions: Bool = true

    // AI Model Settings (Updated for 2026)
    var openaiModel: String = "gpt-5.2"
    var anthropicModel: String = "claude-sonnet-4-5-20250929"
    var geminiModel: String = "gemini-3-flash-preview"
    var grokModel: String = "grok-4-1-fast-reasoning"
    var aiTemperature: Double = 0.7
    var aiMaxTokens: Int = 1024

    // Custom model names (for user-specified models)
    var useCustomOpenaiModel: Bool = false
    var useCustomAnthropicModel: Bool = false
    var useCustomGeminiModel: Bool = false
    var useCustomGrokModel: Bool = false
    var customOpenaiModel: String = ""
    var customAnthropicModel: String = ""
    var customGeminiModel: String = ""
    var customGrokModel: String = ""

    // Computed properties for actual model to use
    var effectiveOpenaiModel: String {
        useCustomOpenaiModel && !customOpenaiModel.isEmpty ? customOpenaiModel : openaiModel
    }
    var effectiveAnthropicModel: String {
        useCustomAnthropicModel && !customAnthropicModel.isEmpty ? customAnthropicModel : anthropicModel
    }
    var effectiveGeminiModel: String {
        useCustomGeminiModel && !customGeminiModel.isEmpty ? customGeminiModel : geminiModel
    }
    var effectiveGrokModel: String {
        useCustomGrokModel && !customGrokModel.isEmpty ? customGrokModel : grokModel
    }

    // Check if selected summary provider has API key
    var hasSummaryProviderKey: Bool {
        switch summaryProvider {
        case .openai: return !openaiKey.isEmpty
        case .anthropic: return !anthropicKey.isEmpty
        case .gemini: return !geminiKey.isEmpty
        case .grok: return !grokKey.isEmpty
        }
    }

    var summaryProviderKeyName: String {
        summaryProvider.rawValue
    }

    // Obsidian
    var obsidianVaultPath: String = ""
    var obsidianPrefix: String = ""
    var obsidianSuffix: String = ""
    
    // Display
    var showToolCalls: Bool = true
    var renderMarkdown: Bool = true
    
    // Tags
    var tagSortMode: TagSortMode = .important
    var visibleTagsInList: [String] = []
    
    // Cloud Sync
    var cloudSyncEnabled: Bool = false

    // Context Summary Settings
    var contextMaxMessages: Int = 50
    var contextMaxCharsPerMessage: Int = 500
    var contextPrompt: String = AppSettings.defaultContextPrompt

    static let defaultContextPrompt = """
이 코딩 세션 대화를 분석하여 다음을 생성해주세요:

## 생성 항목

1. **타이틀** (title)
   - 핵심 작업/주제를 담은 간결한 제목
   - 한국어, 10-25자
   - 예: "SwiftUI 대시보드 차트 구현", "API 인증 버그 수정"

2. **태그** (tags)
   - 세션의 주요 키워드를 태그로 추출
   - 3-5개의 태그
   - 기술 스택, 작업 유형, 주요 기능 등 포함
   - 예: ["SwiftUI", "Charts", "Dashboard", "버그수정"]

3. **컨텍스트 요약** (summary)
   - 다음에 이어서 작업할 때 참고할 핵심 맥락
   - 한국어, 3-5문장
   - 반드시 포함할 내용:
     * 무슨 작업을 했는지 (What)
     * 어디까지 진행됐는지 (Progress)
     * 주요 결정사항이나 변경점 (Key Changes)
     * 다음에 해야 할 작업 힌트 (Next)

4. **핵심 포인트** (keyPoints)
   - 주요 결정사항, 변경된 파일, 해결한 문제 등
   - 3-5개 항목

5. **다음 단계** (nextSteps)
   - 이 세션을 이어서 작업할 때 해야 할 것들
   - 2-3개 항목

## 응답 형식 (JSON만 출력, 다른 텍스트 없이)
{"title": "...", "tags": ["...", "..."], "summary": "...", "keyPoints": ["...", "..."], "nextSteps": ["...", "..."]}
"""

    func iconFor(_ cli: CLITool) -> String {
        cliIcons[cli.rawValue] ?? cli.defaultIcon
    }
}

// MARK: - Session Summary
struct SessionSummary: Codable, Identifiable, Equatable {
    var id: String { sessionId }
    let sessionId: String
    var summary: String
    var keyPoints: [String]
    var suggestedNextSteps: [String]
    var tags: [String]
    var generatedAt: Date
    var provider: AIProvider

    init(sessionId: String, summary: String, keyPoints: [String], suggestedNextSteps: [String], tags: [String] = [], generatedAt: Date, provider: AIProvider) {
        self.sessionId = sessionId
        self.summary = summary
        self.keyPoints = keyPoints
        self.suggestedNextSteps = suggestedNextSteps
        self.tags = tags
        self.generatedAt = generatedAt
        self.provider = provider
    }
}

// MARK: - AppState
@Observable
final class AppState {
    var sessions: [Session] = []
    var filteredSessions: [Session] = []
    var selectedSession: Session?
    var selectedTab: AppTab = .sessions
    
    var searchText: String = "" {
        didSet { filterSessions() }
    }
    var isSearchFocused: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    
    var selectedTag: String?
    var sidebarViewMode: SidebarViewMode = .list
    var showFavoritesOnly: Bool = false
    var showInspector: Bool = false
    
    // Archive
    var showArchivedSessions: Bool = false
    
    // Multi-select (Bulk Operations)
    var selectedSessionIds: Set<String> = []
    var isMultiSelectMode: Bool = false
    
    // Search highlighting
    var currentSearchTerm: String?
    
    // Settings
    var settings: AppSettings = AppSettings()
    
    // Tag Database
    var tagDatabase: [String: TagInfo] = [:]
    
    // Session Metadata
    var sessionMetadata: [String: SessionMetadata] = [:]
    
    // Summaries
    var sessionSummaries: [String: SessionSummary] = [:]
    
    private var cachedSessions: [AgentType: [Session]] = [:]
    private var cacheLoadingStatus: [AgentType: Bool] = [:]
    
    private let sessionService = SessionService()
    private let dataURL: URL
    
    var cloudSyncStatus: CloudSyncService.SyncStatus = .idle
    var lastCloudSyncDate: Date?
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("CmdTrace")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        dataURL = appDir
        
        loadUserData()
        // Load all CLI sessions in background for instant switching
        Task { await preloadAllSessions() }
    }
    
    var selectedCLI: CLITool {
        get { settings.selectedCLI }
        set {
            settings.selectedCLI = newValue
            selectedSession = nil
            selectedTag = nil
            // Instant switch from cache
            switchToCache(for: agentType)
            saveUserData()
        }
    }
    
    /// Switch to cached sessions instantly (called on CLI change)
    private func switchToCache(for agent: AgentType) {
        if let cached = cachedSessions[agent] {
            sessions = cached
            filterSessions()
        } else {
            // Cache miss - load in background
            Task { await loadSessions() }
        }
    }
    
    /// Preload sessions for all CLIs on app startup
    @MainActor
    func preloadAllSessions() async {
        // Load current CLI first (user sees this immediately)
        await loadSessions()
        
        // Then load other CLIs in background
        for agent in AgentType.allCases where agent != agentType {
            if cacheLoadingStatus[agent] != true && cachedSessions[agent] == nil {
                cacheLoadingStatus[agent] = true
                do {
                    let sessions = try await sessionService.loadSessions(for: agent)
                    cachedSessions[agent] = sessions
                } catch {
                    // Silent fail for background preload
                }
                cacheLoadingStatus[agent] = false
            }
        }
    }
    
    var agentType: AgentType {
        switch settings.selectedCLI {
        case .claude: return .claude
        case .opencode, .antigravity: return .opencode
        }
    }
    
    // MARK: - All Tags (sorted)
    var allTags: [TagInfo] {
        let tags = Array(tagDatabase.values)
        switch settings.tagSortMode {
        case .important:
            return tags.sorted { ($0.isImportant ? 0 : 1, $0.name) < ($1.isImportant ? 0 : 1, $1.name) }
        case .alphabetical:
            return tags.sorted { $0.name < $1.name }
        case .countDesc:
            return tags.sorted { tagCount(for: $0.name) > tagCount(for: $1.name) }
        case .countAsc:
            return tags.sorted { tagCount(for: $0.name) < tagCount(for: $1.name) }
        }
    }
    
    var visibleTags: [TagInfo] {
        if settings.visibleTagsInList.isEmpty {
            return allTags.filter { $0.isImportant }.prefix(5).map { $0 }
        }
        return settings.visibleTagsInList.compactMap { tagDatabase[$0] }
    }
    
    func tagCount(for tagName: String) -> Int {
        sessionMetadata.values.filter { $0.tags.contains(tagName) }.count
    }
    
    // MARK: - Nested Tags
    var rootTags: [TagInfo] {
        allTags.filter { $0.parentTag == nil }
    }
    
    func childTags(of parentName: String) -> [TagInfo] {
        allTags.filter { $0.parentTag == parentName }
    }
    
    // MARK: - Sessions
    @MainActor
    func loadSessions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedSessions = try await sessionService.loadSessions(for: agentType)
            sessions = loadedSessions
            cachedSessions[agentType] = loadedSessions
            filterSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func filterSessions() {
        var result = sessions
        
        if !showArchivedSessions {
            result = result.filter { sessionMetadata[$0.id]?.isArchived != true }
        }
        
        if showFavoritesOnly {
            result = result.filter { sessionMetadata[$0.id]?.isFavorite == true }
        }
        
        if let tag = selectedTag {
            result = result.filter { sessionMetadata[$0.id]?.tags.contains(tag) == true }
        }
        
        if !searchText.isEmpty {
            let query = searchText.trimmingCharacters(in: .whitespaces)
            
            if query.hasPrefix("title:") {
                let term = String(query.dropFirst(6)).lowercased().trimmingCharacters(in: .whitespaces)
                result = result.filter { session in
                    session.title.lowercased().contains(term) ||
                    (sessionMetadata[session.id]?.customName?.lowercased().contains(term) == true)
                }
            } else if query.hasPrefix("tag:") {
                let term = String(query.dropFirst(4)).lowercased().trimmingCharacters(in: .whitespaces)
                result = result.filter { session in
                    sessionMetadata[session.id]?.tags.contains { $0.lowercased().contains(term) } == true
                }
            } else if query.hasPrefix("project:") {
                let term = String(query.dropFirst(8)).lowercased().trimmingCharacters(in: .whitespaces)
                result = result.filter { session in
                    session.project.lowercased().contains(term) ||
                    session.projectName.lowercased().contains(term)
                }
            } else if query.hasPrefix("content:") {
                let term = String(query.dropFirst(8)).lowercased().trimmingCharacters(in: .whitespaces)
                result = result.filter { session in
                    session.preview.lowercased().contains(term)
                }
            } else if query.hasPrefix("date:") {
                // Date filter: date:today, date:yesterday, date:week, date:month, date:2024-01-15, date:2024-01-01..2024-01-31
                let term = String(query.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                result = result.filter { session in
                    matchesDateFilter(session: session, dateFilter: term)
                }
            } else if query.hasPrefix("regex:") {
                // Regex search in title, project, and preview
                let pattern = String(query.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    result = result.filter { session in
                        let searchTargets = [
                            session.title,
                            session.project,
                            session.preview,
                            sessionMetadata[session.id]?.customName ?? ""
                        ]
                        return searchTargets.contains { target in
                            let range = NSRange(target.startIndex..., in: target)
                            return regex.firstMatch(in: target, options: [], range: range) != nil
                        }
                    }
                }
            } else if query.hasPrefix("messages:") {
                // Message count filter: messages:>10, messages:<5, messages:=20, messages:10..50
                let term = String(query.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                result = result.filter { session in
                    matchesMessageCountFilter(session: session, filter: term)
                }
            } else {
                let term = query.lowercased()
                currentSearchTerm = term
                result = result.filter { session in
                    session.title.lowercased().contains(term) ||
                    session.project.lowercased().contains(term) ||
                    session.preview.lowercased().contains(term) ||
                    (sessionMetadata[session.id]?.customName?.lowercased().contains(term) == true) ||
                    (sessionMetadata[session.id]?.tags.contains { $0.lowercased().contains(term) } == true)
                }
            }
        } else {
            currentSearchTerm = nil
        }
        
        // Sort: pinned first
        result.sort { first, second in
            let firstPinned = sessionMetadata[first.id]?.isPinned == true
            let secondPinned = sessionMetadata[second.id]?.isPinned == true
            if firstPinned != secondPinned {
                return firstPinned
            }
            return first.lastActivity > second.lastActivity
        }
        
        filteredSessions = result
    }
    
    // MARK: - Search Filter Helpers
    
    private func matchesDateFilter(session: Session, dateFilter: String) -> Bool {
        let calendar = Calendar.current
        let sessionDate = session.lastActivity
        let today = calendar.startOfDay(for: Date())
        
        switch dateFilter.lowercased() {
        case "today":
            return calendar.isDateInToday(sessionDate)
        case "yesterday":
            return calendar.isDateInYesterday(sessionDate)
        case "week":
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else { return false }
            return sessionDate >= weekAgo
        case "month":
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: today) else { return false }
            return sessionDate >= monthAgo
        default:
            // Check for date range: 2024-01-01..2024-01-31
            if dateFilter.contains("..") {
                let parts = dateFilter.split(separator: ".").map(String.init).filter { !$0.isEmpty }
                if parts.count == 2 {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let startDate = formatter.date(from: parts[0]),
                       let endDate = formatter.date(from: parts[1]) {
                        let startOfStart = calendar.startOfDay(for: startDate)
                        let endOfEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
                        return sessionDate >= startOfStart && sessionDate < endOfEnd
                    }
                }
            }
            // Check for specific date: 2024-01-15
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let specificDate = formatter.date(from: dateFilter) {
                return calendar.isDate(sessionDate, inSameDayAs: specificDate)
            }
            return false
        }
    }
    
    private func matchesMessageCountFilter(session: Session, filter: String) -> Bool {
        let count = session.messageCount
        
        // Range: 10..50
        if filter.contains("..") {
            let parts = filter.split(separator: ".").map(String.init).filter { !$0.isEmpty }
            if parts.count == 2, let min = Int(parts[0]), let max = Int(parts[1]) {
                return count >= min && count <= max
            }
        }
        
        // Comparison: >10, <5, >=20, <=30, =15
        if filter.hasPrefix(">="), let value = Int(filter.dropFirst(2)) {
            return count >= value
        } else if filter.hasPrefix("<="), let value = Int(filter.dropFirst(2)) {
            return count <= value
        } else if filter.hasPrefix(">"), let value = Int(filter.dropFirst(1)) {
            return count > value
        } else if filter.hasPrefix("<"), let value = Int(filter.dropFirst(1)) {
            return count < value
        } else if filter.hasPrefix("="), let value = Int(filter.dropFirst(1)) {
            return count == value
        } else if let value = Int(filter) {
            // Exact match if just a number
            return count == value
        }
        
        return false
    }
    
    // MARK: - Session Metadata Helpers
    func getDisplayName(for session: Session) -> String {
        sessionMetadata[session.id]?.customName ?? session.displayTitle
    }
    
    func setSessionName(_ name: String, for sessionId: String) {
        var meta = sessionMetadata[sessionId] ?? SessionMetadata()
        meta.customName = name.isEmpty ? nil : name
        sessionMetadata[sessionId] = meta
        saveUserData()
    }
    
    func getTags(for sessionId: String) -> [String] {
        sessionMetadata[sessionId]?.tags ?? []
    }
    
    func addTag(_ tagName: String, to sessionId: String) {
        var meta = sessionMetadata[sessionId] ?? SessionMetadata()
        if !meta.tags.contains(tagName) {
            meta.tags.append(tagName)
            sessionMetadata[sessionId] = meta
            
            // Add to tag database if new
            if tagDatabase[tagName] == nil {
                tagDatabase[tagName] = TagInfo(name: tagName)
            }
            
            saveUserData()
        }
    }
    
    func removeTag(_ tagName: String, from sessionId: String) {
        var meta = sessionMetadata[sessionId] ?? SessionMetadata()
        meta.tags.removeAll { $0 == tagName }
        sessionMetadata[sessionId] = meta
        saveUserData()
    }
    
    func toggleFavorite(for sessionId: String) {
        var meta = sessionMetadata[sessionId] ?? SessionMetadata()
        meta.isFavorite.toggle()
        sessionMetadata[sessionId] = meta
        filterSessions()
        saveUserData()
    }
    
    func togglePinned(for sessionId: String) {
        var meta = sessionMetadata[sessionId] ?? SessionMetadata()
        meta.isPinned.toggle()
        sessionMetadata[sessionId] = meta
        filterSessions()
        saveUserData()
    }
    
    func isFavorite(_ sessionId: String) -> Bool {
        sessionMetadata[sessionId]?.isFavorite == true
    }
    
    func isPinned(_ sessionId: String) -> Bool {
        sessionMetadata[sessionId]?.isPinned == true
    }
    
    func isArchived(_ sessionId: String) -> Bool {
        sessionMetadata[sessionId]?.isArchived == true
    }
    
    func toggleArchive(for sessionId: String) {
        var meta = sessionMetadata[sessionId] ?? SessionMetadata()
        meta.isArchived.toggle()
        meta.archivedAt = meta.isArchived ? Date() : nil
        sessionMetadata[sessionId] = meta
        filterSessions()
        saveUserData()
    }
    
    func archiveOldSessions(olderThan days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        for session in sessions {
            if session.lastActivity < cutoffDate {
                var meta = sessionMetadata[session.id] ?? SessionMetadata()
                if !meta.isArchived {
                    meta.isArchived = true
                    meta.archivedAt = Date()
                    sessionMetadata[session.id] = meta
                }
            }
        }
        filterSessions()
        saveUserData()
    }
    
    // MARK: - Bulk Operations
    func bulkAddTag(_ tagName: String) {
        for sessionId in selectedSessionIds {
            addTag(tagName, to: sessionId)
        }
    }
    
    func bulkRemoveTag(_ tagName: String) {
        for sessionId in selectedSessionIds {
            removeTag(tagName, from: sessionId)
        }
    }
    
    func bulkArchive() {
        for sessionId in selectedSessionIds {
            var meta = sessionMetadata[sessionId] ?? SessionMetadata()
            if !meta.isArchived {
                meta.isArchived = true
                meta.archivedAt = Date()
                sessionMetadata[sessionId] = meta
            }
        }
        selectedSessionIds.removeAll()
        isMultiSelectMode = false
        filterSessions()
        saveUserData()
    }
    
    func bulkUnarchive() {
        for sessionId in selectedSessionIds {
            var meta = sessionMetadata[sessionId] ?? SessionMetadata()
            meta.isArchived = false
            meta.archivedAt = nil
            sessionMetadata[sessionId] = meta
        }
        selectedSessionIds.removeAll()
        isMultiSelectMode = false
        filterSessions()
        saveUserData()
    }
    
    func bulkToggleFavorite() {
        for sessionId in selectedSessionIds {
            toggleFavorite(for: sessionId)
        }
        selectedSessionIds.removeAll()
        isMultiSelectMode = false
    }
    
    func clearSelection() {
        selectedSessionIds.removeAll()
        isMultiSelectMode = false
    }
    
    func toggleSessionSelection(_ sessionId: String) {
        if selectedSessionIds.contains(sessionId) {
            selectedSessionIds.remove(sessionId)
        } else {
            selectedSessionIds.insert(sessionId)
        }
        isMultiSelectMode = !selectedSessionIds.isEmpty
    }
    
    func selectAllFilteredSessions() {
        selectedSessionIds = Set(filteredSessions.map { $0.id })
        isMultiSelectMode = !selectedSessionIds.isEmpty
    }
    
    // MARK: - Tag Database Helpers
    func updateTagInfo(_ tagInfo: TagInfo) {
        tagDatabase[tagInfo.name] = tagInfo
        saveUserData()
    }
    
    func renameTag(from oldName: String, to newName: String) {
        guard oldName != newName else { return }
        
        // Update tag database
        if var tagInfo = tagDatabase[oldName] {
            tagDatabase.removeValue(forKey: oldName)
            tagInfo = TagInfo(name: newName, color: tagInfo.color, isImportant: tagInfo.isImportant, parentTag: tagInfo.parentTag)
            tagDatabase[newName] = tagInfo
        }
        
        // Update all sessions
        for (sessionId, var meta) in sessionMetadata {
            if let index = meta.tags.firstIndex(of: oldName) {
                meta.tags[index] = newName
                sessionMetadata[sessionId] = meta
            }
        }
        
        // Update parent references
        for (name, var info) in tagDatabase {
            if info.parentTag == oldName {
                info = TagInfo(name: name, color: info.color, isImportant: info.isImportant, parentTag: newName)
                tagDatabase[name] = info
            }
        }
        
        saveUserData()
    }
    
    func deleteTag(_ tagName: String) {
        tagDatabase.removeValue(forKey: tagName)
        
        for (sessionId, var meta) in sessionMetadata {
            meta.tags.removeAll { $0 == tagName }
            sessionMetadata[sessionId] = meta
        }
        
        saveUserData()
    }
    
    // MARK: - Summaries
    func getSummary(for sessionId: String) -> SessionSummary? {
        sessionSummaries[sessionId]
    }
    
    func saveSummary(_ summary: SessionSummary) {
        sessionSummaries[summary.sessionId] = summary
        saveUserData()
    }
    
    // MARK: - Persistence
    private func loadUserData() {
        let settingsURL = dataURL.appendingPathComponent("settings.json")
        let metadataURL = dataURL.appendingPathComponent("session-metadata.json")
        let tagsURL = dataURL.appendingPathComponent("tag-database.json")
        let summariesURL = dataURL.appendingPathComponent("summaries.json")
        
        if let data = try? Data(contentsOf: settingsURL),
           let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = loaded
        }
        
        if let data = try? Data(contentsOf: metadataURL),
           let loaded = try? JSONDecoder().decode([String: SessionMetadata].self, from: data) {
            sessionMetadata = loaded
        }
        
        if let data = try? Data(contentsOf: tagsURL),
           let loaded = try? JSONDecoder().decode([String: TagInfo].self, from: data) {
            tagDatabase = loaded
        }
        
        if let data = try? Data(contentsOf: summariesURL),
           let loaded = try? JSONDecoder().decode([String: SessionSummary].self, from: data) {
            sessionSummaries = loaded
        }
        
        // Migrate old data if exists
        migrateOldData()
    }
    
    private func migrateOldData() {
        let oldNamesURL = dataURL.appendingPathComponent("session-names.json")
        let oldTagsURL = dataURL.appendingPathComponent("session-tags.json")
        
        // Migrate session names
        if let data = try? Data(contentsOf: oldNamesURL),
           let names = try? JSONDecoder().decode([String: String].self, from: data) {
            for (sessionId, name) in names {
                var meta = sessionMetadata[sessionId] ?? SessionMetadata()
                if meta.customName == nil {
                    meta.customName = name
                    sessionMetadata[sessionId] = meta
                }
            }
            try? FileManager.default.removeItem(at: oldNamesURL)
        }
        
        // Migrate session tags
        if let data = try? Data(contentsOf: oldTagsURL),
           let tags = try? JSONDecoder().decode([String: [String]].self, from: data) {
            for (sessionId, tagList) in tags {
                var meta = sessionMetadata[sessionId] ?? SessionMetadata()
                for tag in tagList {
                    if !meta.tags.contains(tag) {
                        meta.tags.append(tag)
                    }
                    if tagDatabase[tag] == nil {
                        tagDatabase[tag] = TagInfo(name: tag)
                    }
                }
                sessionMetadata[sessionId] = meta
            }
            try? FileManager.default.removeItem(at: oldTagsURL)
        }
    }
    
    func saveUserData() {
        let settingsURL = dataURL.appendingPathComponent("settings.json")
        let metadataURL = dataURL.appendingPathComponent("session-metadata.json")
        let tagsURL = dataURL.appendingPathComponent("tag-database.json")
        let summariesURL = dataURL.appendingPathComponent("summaries.json")
        
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: settingsURL)
        }
        if let data = try? JSONEncoder().encode(sessionMetadata) {
            try? data.write(to: metadataURL)
        }
        if let data = try? JSONEncoder().encode(tagDatabase) {
            try? data.write(to: tagsURL)
        }
        if let data = try? JSONEncoder().encode(sessionSummaries) {
            try? data.write(to: summariesURL)
        }
    }
    
    @MainActor
    func checkCloudAccountStatus() async -> Bool {
        await CloudSyncService.shared.checkAccountStatus()
    }
    
    @MainActor
    func enableCloudSync() async throws {
        try await CloudSyncService.shared.enableSync()
        settings.cloudSyncEnabled = true
        saveUserData()
    }
    
    @MainActor
    func disableCloudSync() async {
        await CloudSyncService.shared.disableSync()
        settings.cloudSyncEnabled = false
        cloudSyncStatus = .idle
        saveUserData()
    }
    
    @MainActor
    func performCloudSync() async {
        guard settings.cloudSyncEnabled else { return }
        
        cloudSyncStatus = .syncing
        
        do {
            let (mergedMeta, mergedSummaries, mergedTags) = try await CloudSyncService.shared.performFullSync(
                metadata: sessionMetadata,
                summaries: sessionSummaries,
                tags: tagDatabase
            )
            
            sessionMetadata = mergedMeta
            sessionSummaries = mergedSummaries
            tagDatabase = mergedTags
            
            lastCloudSyncDate = Date()
            cloudSyncStatus = .success(lastCloudSyncDate!)
            saveUserData()
            filterSessions()
        } catch {
            cloudSyncStatus = .error(error.localizedDescription)
        }
    }
}

// MARK: - Agent Type (backward compatibility)
enum AgentType: String, CaseIterable {
    case claude = "Claude Code"
    case opencode = "OpenCode"
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String {
        guard let components = NSColor(self).cgColor.components else { return "#3B82F6" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Preset Colors
struct TagColors {
    static let presets: [(name: String, hex: String)] = [
        ("Blue", "#3B82F6"),
        ("Green", "#22C55E"),
        ("Red", "#EF4444"),
        ("Orange", "#F97316"),
        ("Purple", "#A855F7"),
        ("Pink", "#EC4899"),
        ("Yellow", "#EAB308"),
        ("Cyan", "#06B6D4"),
        ("Indigo", "#6366F1"),
        ("Gray", "#6B7280"),
    ]
}
