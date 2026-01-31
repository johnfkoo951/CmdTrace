import Foundation

// MARK: - Filename Generator
enum FilenameGenerator {
    
    /// Generate filename with prefix, suffix and variable substitution
    static func generateFilename(
        displayName: String,
        prefix: String,
        suffix: String,
        projectName: String,
        cliName: String,
        resumeId: String,
        messageCount: Int
    ) -> String {
        // Process variables in prefix and suffix
        let processedPrefix = processVariables(prefix, projectName: projectName, cliName: cliName, resumeId: resumeId, messageCount: messageCount)
        let processedSuffix = processVariables(suffix, projectName: projectName, cliName: cliName, resumeId: resumeId, messageCount: messageCount)

        // Sanitize display name for filename
        let safeName = displayName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "\"", with: "")

        return "\(processedPrefix)\(safeName)\(processedSuffix).md"
    }

    /// Process template variables in filename parts
    static func processVariables(
        _ text: String,
        projectName: String,
        cliName: String,
        resumeId: String,
        messageCount: Int
    ) -> String {
        var result = text

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: Date())

        result = result.replacingOccurrences(of: "{{date}}", with: dateStr)
        result = result.replacingOccurrences(of: "{{time}}", with: timeStr)
        result = result.replacingOccurrences(of: "{{project}}", with: projectName)
        result = result.replacingOccurrences(of: "{{cli}}", with: cliName)
        result = result.replacingOccurrences(of: "{{session}}", with: resumeId)
        result = result.replacingOccurrences(of: "{{messages}}", with: String(messageCount))

        return result
    }
}
