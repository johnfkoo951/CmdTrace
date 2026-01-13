import SwiftUI
import Observation

// MARK: - Enums
enum AppTab: String, CaseIterable {
    case sessions = "Sessions"
    case dashboard = "Dashboard"
    case interaction = "Interaction"
    
    var icon: String {
        switch self {
        case .sessions: return "bubble.left.and.bubble.right"
        case .dashboard: return "chart.bar"
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
    var openaiModel: String = "gpt-5-mini-2025-08-07"
    var anthropicModel: String = "claude-sonnet-4-5-20250929"
    var geminiModel: String = "gemini-3-flash-preview"
    var grokModel: String = "grok-4-1-fast-non-reasoning"
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
    var visibleTagsInList: [String] = [] // which tags to show in list view

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
    
    // Settings
    var settings: AppSettings = AppSettings()
    
    // Tag Database
    var tagDatabase: [String: TagInfo] = [:]
    
    // Session Metadata
    var sessionMetadata: [String: SessionMetadata] = [:]
    
    // Summaries
    var sessionSummaries: [String: SessionSummary] = [:]
    
    // Pre-cached sessions for all CLIs (instant switching)
    private var cachedSessions: [AgentType: [Session]] = [:]
    private var cacheLoadingStatus: [AgentType: Bool] = [:]
    
    private let sessionService = SessionService()
    private let dataURL: URL
    
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
        
        // Filter by favorites
        if showFavoritesOnly {
            result = result.filter { sessionMetadata[$0.id]?.isFavorite == true }
        }
        
        // Filter by tag
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
            } else {
                let term = query.lowercased()
                result = result.filter { session in
                    session.title.lowercased().contains(term) ||
                    session.project.lowercased().contains(term) ||
                    session.preview.lowercased().contains(term) ||
                    (sessionMetadata[session.id]?.customName?.lowercased().contains(term) == true) ||
                    (sessionMetadata[session.id]?.tags.contains { $0.lowercased().contains(term) } == true)
                }
            }
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
