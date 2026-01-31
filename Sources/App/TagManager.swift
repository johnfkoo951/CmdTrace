import Foundation

struct TagManager {
    static func allTags(from tagDatabase: [String: TagInfo], sortMode: TagSortMode, sessionMetadata: [String: SessionMetadata]) -> [TagInfo] {
        let tags = Array(tagDatabase.values)
        switch sortMode {
        case .important:
            return tags.sorted { ($0.isImportant ? 0 : 1, $0.name) < ($1.isImportant ? 0 : 1, $1.name) }
        case .alphabetical:
            return tags.sorted { $0.name < $1.name }
        case .countDesc:
            return tags.sorted { countForTag($0.name, in: sessionMetadata) > countForTag($1.name, in: sessionMetadata) }
        case .countAsc:
            return tags.sorted { countForTag($0.name, in: sessionMetadata) < countForTag($1.name, in: sessionMetadata) }
        }
    }

    static func countForTag(_ tagName: String, in sessionMetadata: [String: SessionMetadata]) -> Int {
        sessionMetadata.values.filter { $0.tags.contains(tagName) }.count
    }

    static func visibleTags(from tagDatabase: [String: TagInfo], visibleTagNames: [String], sortMode: TagSortMode, sessionMetadata: [String: SessionMetadata]) -> [TagInfo] {
        if visibleTagNames.isEmpty {
            return allTags(from: tagDatabase, sortMode: sortMode, sessionMetadata: sessionMetadata)
                .filter { $0.isImportant }
                .prefix(5)
                .map { $0 }
        }
        return visibleTagNames.compactMap { tagDatabase[$0] }
    }

    static func rootTags(from tagDatabase: [String: TagInfo], sortMode: TagSortMode, sessionMetadata: [String: SessionMetadata]) -> [TagInfo] {
        allTags(from: tagDatabase, sortMode: sortMode, sessionMetadata: sessionMetadata).filter { $0.parentTag == nil }
    }

    static func childTags(of parentName: String, from tagDatabase: [String: TagInfo], sortMode: TagSortMode, sessionMetadata: [String: SessionMetadata]) -> [TagInfo] {
        allTags(from: tagDatabase, sortMode: sortMode, sessionMetadata: sessionMetadata).filter { $0.parentTag == parentName }
    }

    static func rename(
        from oldName: String,
        to newName: String,
        tagDatabase: inout [String: TagInfo],
        sessionMetadata: inout [String: SessionMetadata]
    ) {
        guard oldName != newName else { return }

        if let tagInfo = tagDatabase[oldName] {
            tagDatabase.removeValue(forKey: oldName)
            tagDatabase[newName] = TagInfo(name: newName, color: tagInfo.color, isImportant: tagInfo.isImportant, parentTag: tagInfo.parentTag)
        }

        for (sessionId, var meta) in sessionMetadata {
            if let index = meta.tags.firstIndex(of: oldName) {
                meta.tags[index] = newName
                sessionMetadata[sessionId] = meta
            }
        }

        for (name, var info) in tagDatabase {
            if info.parentTag == oldName {
                info = TagInfo(name: name, color: info.color, isImportant: info.isImportant, parentTag: newName)
                tagDatabase[name] = info
            }
        }
    }

    static func delete(
        _ tagName: String,
        tagDatabase: inout [String: TagInfo],
        sessionMetadata: inout [String: SessionMetadata]
    ) {
        tagDatabase.removeValue(forKey: tagName)

        for (sessionId, var meta) in sessionMetadata {
            meta.tags.removeAll { $0 == tagName }
            sessionMetadata[sessionId] = meta
        }
    }
}
