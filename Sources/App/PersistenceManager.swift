import Foundation

struct PersistenceManager {
    let dataURL: URL

    func loadSettings() -> AppSettings {
        let url = dataURL.appendingPathComponent("settings.json")
        guard let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return loaded
    }

    func loadSessionMetadata() -> [String: SessionMetadata] {
        let url = dataURL.appendingPathComponent("session-metadata.json")
        guard let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([String: SessionMetadata].self, from: data) else {
            return [:]
        }
        return loaded
    }

    func loadTagDatabase() -> [String: TagInfo] {
        let url = dataURL.appendingPathComponent("tag-database.json")
        guard let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([String: TagInfo].self, from: data) else {
            return [:]
        }
        return loaded
    }

    func loadSummaries() -> [String: SessionSummary] {
        let url = dataURL.appendingPathComponent("summaries.json")
        guard let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([String: SessionSummary].self, from: data) else {
            return [:]
        }
        return loaded
    }

    func loadProjectMetadata() -> [String: ProjectMetadata] {
        let url = dataURL.appendingPathComponent("project-metadata.json")
        guard let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([String: ProjectMetadata].self, from: data) else {
            return [:]
        }
        return loaded
    }

    func save(
        settings: AppSettings,
        sessionMetadata: [String: SessionMetadata],
        tagDatabase: [String: TagInfo],
        summaries: [String: SessionSummary],
        projectMetadata: [String: ProjectMetadata]
    ) {
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: dataURL.appendingPathComponent("settings.json"))
        }
        if let data = try? JSONEncoder().encode(sessionMetadata) {
            try? data.write(to: dataURL.appendingPathComponent("session-metadata.json"))
        }
        if let data = try? JSONEncoder().encode(tagDatabase) {
            try? data.write(to: dataURL.appendingPathComponent("tag-database.json"))
        }
        if let data = try? JSONEncoder().encode(summaries) {
            try? data.write(to: dataURL.appendingPathComponent("summaries.json"))
        }
        if let data = try? JSONEncoder().encode(projectMetadata) {
            try? data.write(to: dataURL.appendingPathComponent("project-metadata.json"))
        }
    }

    func migrateOldData(sessionMetadata: inout [String: SessionMetadata], tagDatabase: inout [String: TagInfo]) {
        let oldNamesURL = dataURL.appendingPathComponent("session-names.json")
        let oldTagsURL = dataURL.appendingPathComponent("session-tags.json")

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
}
