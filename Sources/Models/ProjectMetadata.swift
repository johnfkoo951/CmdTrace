import Foundation
import SwiftUI

struct ProjectMetadata: Codable, Identifiable, Equatable {
    var id: String { path }
    let path: String
    var customName: String?
    var description: String?
    var languages: [String]
    var frameworks: [String]
    var tags: [String]
    var color: String
    var isFavorite: Bool
    var isPinned: Bool
    var notes: String?
    var lastOpened: Date?
    var createdAt: Date
    
    init(
        path: String,
        customName: String? = nil,
        description: String? = nil,
        languages: [String] = [],
        frameworks: [String] = [],
        tags: [String] = [],
        color: String = "#3B82F6",
        isFavorite: Bool = false,
        isPinned: Bool = false,
        notes: String? = nil,
        lastOpened: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.path = path
        self.customName = customName
        self.description = description
        self.languages = languages
        self.frameworks = frameworks
        self.tags = tags
        self.color = color
        self.isFavorite = isFavorite
        self.isPinned = isPinned
        self.notes = notes
        self.lastOpened = lastOpened
        self.createdAt = createdAt
    }
    
    var displayName: String {
        customName ?? projectName
    }
    
    var projectName: String {
        path.components(separatedBy: "/").last ?? path
    }
    
    var swiftUIColor: Color {
        Color(hex: color) ?? .blue
    }
    
    var fullPath: String {
        if path.hasPrefix("~") {
            return path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
        }
        return path
    }
}

struct ProjectStats: Equatable {
    let totalSessions: Int
    let totalMessages: Int
    let firstSession: Date?
    let lastSession: Date?
    let averageMessagesPerSession: Double
    let activeDays: Int
    
    var duration: String? {
        guard let first = firstSession, let last = lastSession else { return nil }
        let interval = last.timeIntervalSince(first)
        if interval < 86400 {
            return "< 1 day"
        } else {
            let days = Int(interval / 86400)
            return "\(days) days"
        }
    }
}

struct LanguageInfo: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let color: Color
    let icon: String
    
    static let knownLanguages: [String: LanguageInfo] = [
        "swift": LanguageInfo(name: "Swift", color: .orange, icon: "swift"),
        "python": LanguageInfo(name: "Python", color: .blue, icon: "chevron.left.forwardslash.chevron.right"),
        "typescript": LanguageInfo(name: "TypeScript", color: .blue, icon: "t.square"),
        "javascript": LanguageInfo(name: "JavaScript", color: .yellow, icon: "j.square"),
        "rust": LanguageInfo(name: "Rust", color: .orange, icon: "r.square"),
        "go": LanguageInfo(name: "Go", color: .cyan, icon: "g.square"),
        "java": LanguageInfo(name: "Java", color: .red, icon: "j.square"),
        "kotlin": LanguageInfo(name: "Kotlin", color: .purple, icon: "k.square"),
        "c": LanguageInfo(name: "C", color: .gray, icon: "c.square"),
        "cpp": LanguageInfo(name: "C++", color: .blue, icon: "plus.square"),
        "csharp": LanguageInfo(name: "C#", color: .purple, icon: "number.square"),
        "ruby": LanguageInfo(name: "Ruby", color: .red, icon: "r.square"),
        "php": LanguageInfo(name: "PHP", color: .indigo, icon: "p.square"),
        "html": LanguageInfo(name: "HTML", color: .orange, icon: "chevron.left.forwardslash.chevron.right"),
        "css": LanguageInfo(name: "CSS", color: .blue, icon: "paintbrush"),
        "sql": LanguageInfo(name: "SQL", color: .cyan, icon: "cylinder"),
        "shell": LanguageInfo(name: "Shell", color: .green, icon: "terminal"),
        "markdown": LanguageInfo(name: "Markdown", color: .gray, icon: "doc.text"),
    ]
    
    static func info(for language: String) -> LanguageInfo {
        knownLanguages[language.lowercased()] ?? LanguageInfo(name: language, color: .gray, icon: "doc")
    }
}

struct FrameworkInfo: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let color: Color
    
    static let knownFrameworks: [String: FrameworkInfo] = [
        "swiftui": FrameworkInfo(name: "SwiftUI", color: .blue),
        "uikit": FrameworkInfo(name: "UIKit", color: .blue),
        "react": FrameworkInfo(name: "React", color: .cyan),
        "nextjs": FrameworkInfo(name: "Next.js", color: .primary),
        "vue": FrameworkInfo(name: "Vue", color: .green),
        "angular": FrameworkInfo(name: "Angular", color: .red),
        "django": FrameworkInfo(name: "Django", color: .green),
        "flask": FrameworkInfo(name: "Flask", color: .gray),
        "fastapi": FrameworkInfo(name: "FastAPI", color: .teal),
        "express": FrameworkInfo(name: "Express", color: .gray),
        "nestjs": FrameworkInfo(name: "NestJS", color: .red),
        "rails": FrameworkInfo(name: "Rails", color: .red),
        "spring": FrameworkInfo(name: "Spring", color: .green),
        "dotnet": FrameworkInfo(name: ".NET", color: .purple),
        "flutter": FrameworkInfo(name: "Flutter", color: .blue),
        "electron": FrameworkInfo(name: "Electron", color: .cyan),
        "tauri": FrameworkInfo(name: "Tauri", color: .orange),
    ]
    
    static func info(for framework: String) -> FrameworkInfo {
        knownFrameworks[framework.lowercased()] ?? FrameworkInfo(name: framework, color: .gray)
    }
}
