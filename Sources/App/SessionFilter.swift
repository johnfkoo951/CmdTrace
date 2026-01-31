import Foundation

struct SessionFilter {
    struct Result {
        let sessions: [Session]
        let searchTerm: String?
    }

    static func filter(
        sessions: [Session],
        searchText: String,
        selectedTag: String?,
        showArchivedSessions: Bool,
        showFavoritesOnly: Bool,
        sessionMetadata: [String: SessionMetadata]
    ) -> Result {
        var result = sessions
        var searchTerm: String? = nil

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
                let term = String(query.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                result = result.filter { session in
                    matchesDateFilter(session: session, dateFilter: term)
                }
            } else if query.hasPrefix("regex:") {
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
                let term = String(query.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                result = result.filter { session in
                    matchesMessageCountFilter(session: session, filter: term)
                }
            } else {
                let term = query.lowercased()
                searchTerm = term
                result = result.filter { session in
                    session.title.lowercased().contains(term) ||
                    session.project.lowercased().contains(term) ||
                    session.preview.lowercased().contains(term) ||
                    (sessionMetadata[session.id]?.customName?.lowercased().contains(term) == true) ||
                    (sessionMetadata[session.id]?.tags.contains { $0.lowercased().contains(term) } == true)
                }
            }
        }

        result.sort { first, second in
            let firstPinned = sessionMetadata[first.id]?.isPinned == true
            let secondPinned = sessionMetadata[second.id]?.isPinned == true
            if firstPinned != secondPinned {
                return firstPinned
            }
            return first.lastActivity > second.lastActivity
        }

        return Result(sessions: result, searchTerm: searchTerm)
    }

    // MARK: - Date Filter
    private static func matchesDateFilter(session: Session, dateFilter: String) -> Bool {
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
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let specificDate = formatter.date(from: dateFilter) {
                return calendar.isDate(sessionDate, inSameDayAs: specificDate)
            }
            return false
        }
    }

    // MARK: - Message Count Filter
    private static func matchesMessageCountFilter(session: Session, filter: String) -> Bool {
        let count = session.messageCount

        if filter.contains("..") {
            let parts = filter.split(separator: ".").map(String.init).filter { !$0.isEmpty }
            if parts.count == 2, let min = Int(parts[0]), let max = Int(parts[1]) {
                return count >= min && count <= max
            }
        }

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
            return count == value
        }

        return false
    }
}
