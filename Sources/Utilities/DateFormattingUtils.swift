import Foundation

// MARK: - Date Formatting Utilities
/// Shared date formatting for usage views (Daily, Monthly, Block rows).
enum DateFormattingUtils {

    /// Format date string: "2025-12-13" → "12/13"
    static func formatDate(_ dateString: String) -> String {
        let components = dateString.split(separator: "-")
        if components.count >= 3 {
            return "\(components[1])/\(components[2])"
        }
        return dateString
    }

    /// Format month string: "2025-12" → "25/12"
    static func formatMonth(_ monthString: String) -> String {
        let components = monthString.split(separator: "-")
        if components.count >= 2 {
            let year = String(components[0].suffix(2))
            return "\(year)/\(components[1])"
        }
        return monthString
    }

    /// Format ISO time string: "2025-12-13T10:00:00" → "12/13 10:00"
    static func formatTime(_ timeString: String) -> String {
        let parts = timeString.split(separator: "T")
        if parts.count == 2 {
            let dateParts = parts[0].split(separator: "-")
            let timeParts = parts[1].split(separator: ":")
            if dateParts.count >= 3 && timeParts.count >= 2 {
                return "\(dateParts[1])/\(dateParts[2]) \(timeParts[0]):\(timeParts[1])"
            }
        }
        return timeString
    }
}
