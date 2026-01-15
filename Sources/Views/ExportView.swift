import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let session: Session
    let messages: [Message]
    
    @State private var exportFormat: ExportFormat = .markdown
    @State private var includeMetadata = true
    @State private var includeToolCalls = true
    @State private var includeTimestamps = true
    @State private var isExporting = false
    @State private var exportSuccess = false
    
    enum ExportFormat: String, CaseIterable {
        case markdown = "Markdown"
        case json = "JSON"
        case plainText = "Plain Text"
        case html = "HTML"
        
        var fileExtension: String {
            switch self {
            case .markdown: return "md"
            case .json: return "json"
            case .plainText: return "txt"
            case .html: return "html"
            }
        }
        
        var contentType: UTType {
            switch self {
            case .markdown, .plainText: return .plainText
            case .json: return .json
            case .html: return .html
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Export Session")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()
            
            Divider()
            
            Form {
                Section("Format") {
                    Picker("Export Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Options") {
                    Toggle("Include Metadata", isOn: $includeMetadata)
                    Toggle("Include Tool Calls", isOn: $includeToolCalls)
                    Toggle("Include Timestamps", isOn: $includeTimestamps)
                }
                
                Section("Preview") {
                    ScrollView {
                        Text(generatePreview())
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Section {
                    HStack {
                        Button {
                            copyToClipboard()
                        } label: {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        }
                        
                        Spacer()
                        
                        Button {
                            saveToFile()
                        } label: {
                            Label("Save to File", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 550)
        .overlay {
            if exportSuccess {
                exportSuccessOverlay
            }
        }
    }
    
    private var exportSuccessOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Exported Successfully")
                .font(.headline)
        }
        .padding(40)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.scale.combined(with: .opacity))
    }
    
    private func generatePreview() -> String {
        let content = generateExport()
        let lines = content.components(separatedBy: "\n")
        if lines.count > 30 {
            return lines.prefix(30).joined(separator: "\n") + "\n\n... (\(lines.count - 30) more lines)"
        }
        return content
    }
    
    private func generateExport() -> String {
        switch exportFormat {
        case .markdown:
            return generateMarkdown()
        case .json:
            return generateJSON()
        case .plainText:
            return generatePlainText()
        case .html:
            return generateHTML()
        }
    }
    
    private func generateMarkdown() -> String {
        var md = ""
        
        if includeMetadata {
            md += """
            ---
            title: "\(appState.getDisplayName(for: session))"
            session_id: \(session.id)
            project: \(session.projectName)
            messages: \(messages.count)
            exported: \(ISO8601DateFormatter().string(from: Date()))
            ---
            
            # \(appState.getDisplayName(for: session))
            
            **Project:** \(session.projectName)
            **Messages:** \(messages.count)
            **Duration:** \(session.duration ?? "N/A")
            
            ---
            
            """
        }
        
        let filteredMessages = includeToolCalls ? messages : messages.filter { !$0.isToolUse }
        
        for msg in filteredMessages {
            let role = msg.role == .user ? "👤 User" : "🤖 Assistant"
            
            if includeTimestamps, let timestamp = msg.timestamp {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                md += "### \(role) (\(formatter.string(from: timestamp)))\n\n"
            } else {
                md += "### \(role)\n\n"
            }
            
            md += msg.content + "\n\n"
        }
        
        return md
    }
    
    private func generateJSON() -> String {
        struct ExportData: Codable {
            let metadata: SessionMetadataExport?
            let messages: [MessageExport]
        }
        
        struct SessionMetadataExport: Codable {
            let sessionId: String
            let title: String
            let project: String
            let messageCount: Int
            let exportedAt: String
        }
        
        struct MessageExport: Codable {
            let role: String
            let content: String
            let timestamp: String?
            let isToolCall: Bool?
            let toolNames: [String]?
        }
        
        let metadata = includeMetadata ? SessionMetadataExport(
            sessionId: session.id,
            title: appState.getDisplayName(for: session),
            project: session.projectName,
            messageCount: messages.count,
            exportedAt: ISO8601DateFormatter().string(from: Date())
        ) : nil
        
        let filteredMessages = includeToolCalls ? messages : messages.filter { !$0.isToolUse }
        
        let messageExports = filteredMessages.map { msg in
            MessageExport(
                role: msg.role.rawValue,
                content: msg.content,
                timestamp: includeTimestamps ? msg.timestamp.map { ISO8601DateFormatter().string(from: $0) } : nil,
                isToolCall: includeToolCalls ? msg.isToolUse : nil,
                toolNames: includeToolCalls ? msg.toolUses?.map { $0.name } : nil
            )
        }
        
        let exportData = ExportData(metadata: metadata, messages: messageExports)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let data = try? encoder.encode(exportData),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        
        return "{}"
    }
    
    private func generatePlainText() -> String {
        var text = ""
        
        if includeMetadata {
            text += """
            Session: \(appState.getDisplayName(for: session))
            Project: \(session.projectName)
            Messages: \(messages.count)
            
            ========================================
            
            """
        }
        
        let filteredMessages = includeToolCalls ? messages : messages.filter { !$0.isToolUse }
        
        for msg in filteredMessages {
            let role = msg.role == .user ? "USER" : "ASSISTANT"
            
            if includeTimestamps, let timestamp = msg.timestamp {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                text += "[\(formatter.string(from: timestamp))] \(role):\n"
            } else {
                text += "\(role):\n"
            }
            
            text += msg.content + "\n\n"
            text += "----------------------------------------\n\n"
        }
        
        return text
    }
    
    private func generateHTML() -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>\(appState.getDisplayName(for: session))</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
                .metadata { background: #f5f5f5; padding: 15px; border-radius: 8px; margin-bottom: 20px; }
                .message { margin-bottom: 16px; padding: 12px; border-radius: 8px; }
                .user { background: #e3f2fd; }
                .assistant { background: #f3e5f5; }
                .role { font-weight: bold; margin-bottom: 8px; }
                .timestamp { font-size: 12px; color: #666; }
                .content { white-space: pre-wrap; }
                pre { background: #263238; color: #aed581; padding: 12px; border-radius: 4px; overflow-x: auto; }
            </style>
        </head>
        <body>
        """
        
        if includeMetadata {
            html += """
            <div class="metadata">
                <h1>\(appState.getDisplayName(for: session))</h1>
                <p><strong>Project:</strong> \(session.projectName)</p>
                <p><strong>Messages:</strong> \(messages.count)</p>
            </div>
            """
        }
        
        let filteredMessages = includeToolCalls ? messages : messages.filter { !$0.isToolUse }
        
        for msg in filteredMessages {
            let roleClass = msg.role == .user ? "user" : "assistant"
            let roleLabel = msg.role == .user ? "👤 User" : "🤖 Assistant"
            
            html += "<div class=\"message \(roleClass)\">"
            html += "<div class=\"role\">\(roleLabel)"
            
            if includeTimestamps, let timestamp = msg.timestamp {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                html += " <span class=\"timestamp\">(\(formatter.string(from: timestamp)))</span>"
            }
            
            html += "</div>"
            
            let escapedContent = msg.content
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            
            html += "<div class=\"content\">\(escapedContent)</div>"
            html += "</div>"
        }
        
        html += "</body></html>"
        return html
    }
    
    private func copyToClipboard() {
        let content = generateExport()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        
        withAnimation {
            exportSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                exportSuccess = false
            }
        }
    }
    
    private func saveToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [exportFormat.contentType]
        
        let displayName = appState.getDisplayName(for: session)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        
        panel.nameFieldStringValue = "\(displayName).\(exportFormat.fileExtension)"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let content = generateExport()
                try? content.write(to: url, atomically: true, encoding: .utf8)
                
                withAnimation {
                    exportSuccess = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        exportSuccess = false
                        dismiss()
                    }
                }
            }
        }
    }
}
