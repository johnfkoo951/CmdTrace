import SwiftUI

// MARK: - Markdown Text View
struct MarkdownText: View {
    let content: String

    init(_ content: String) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                        Text(attributed)
                            .font(.body)
                    } else {
                        Text(text)
                            .font(.body)
                    }
                case .code(let code, let language):
                    VStack(alignment: .leading, spacing: 4) {
                        if !language.isEmpty {
                            Text(language)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(code)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(10)
                        }
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                case .heading(let text, let level):
                    Text(text)
                        .font(level == 1 ? .title2.bold() : level == 2 ? .title3.bold() : .headline)
                        .padding(.top, level == 1 ? 8 : 4)
                case .listItem(let text, let indent):
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                            Text(attributed)
                                .font(.body)
                        } else {
                            Text(text)
                                .font(.body)
                        }
                    }
                    .padding(.leading, CGFloat(indent * 16))
                case .quote(let text):
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(.blue.opacity(0.5))
                            .frame(width: 3)
                        Text(text)
                            .font(.body)
                            .italic()
                            .foregroundStyle(.secondary)
                            .padding(.leading, 10)
                    }
                case .table(let rows, let headers):
                    ScrollView(.horizontal, showsIndicators: false) {
                        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                            if !headers.isEmpty {
                                GridRow {
                                    ForEach(Array(headers.enumerated()), id: \.offset) { colIndex, header in
                                        Text(header)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(nsColor: .windowBackgroundColor))
                                            .overlay(alignment: .trailing) {
                                                if colIndex < headers.count - 1 {
                                                    Rectangle()
                                                        .fill(Color(nsColor: .separatorColor).opacity(0.5))
                                                        .frame(width: 1)
                                                }
                                            }
                                    }
                                }
                                
                                GridRow {
                                    ForEach(0..<max(headers.count, 1), id: \.self) { _ in
                                        Rectangle()
                                            .fill(Color.accentColor.opacity(0.6))
                                            .frame(height: 2)
                                    }
                                }
                            }

                            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                                GridRow {
                                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                                        Text(cell)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.primary.opacity(0.9))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(rowIndex % 2 == 0 ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.4))
                                            .overlay(alignment: .trailing) {
                                                if colIndex < row.count - 1 {
                                                    Rectangle()
                                                        .fill(Color(nsColor: .separatorColor).opacity(0.3))
                                                        .frame(width: 1)
                                                }
                                            }
                                    }
                                }
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
            }
        }
    }

    private enum Block {
        case text(String)
        case code(String, String) // code, language
        case heading(String, Int) // text, level
        case listItem(String, Int) // text, indent level
        case quote(String)
        case table([[String]], [String]) // rows, headers
    }

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        let lines = content.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Code block
            if line.hasPrefix("```") {
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.code(codeLines.joined(separator: "\n"), language))
                i += 1
                continue
            }

            // Heading
            if line.hasPrefix("#") {
                let level = line.prefix(while: { $0 == "#" }).count
                let text = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                if level <= 6 && !text.isEmpty {
                    blocks.append(.heading(text, level))
                    i += 1
                    continue
                }
            }

            // List item
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") ||
               line.trimmingCharacters(in: .whitespaces).hasPrefix("* ") {
                let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count / 2
                let text = line.trimmingCharacters(in: .whitespaces).dropFirst(2).trimmingCharacters(in: .whitespaces)
                blocks.append(.listItem(String(text), indent))
                i += 1
                continue
            }

            // Quote
            if line.hasPrefix("> ") {
                let text = String(line.dropFirst(2))
                blocks.append(.quote(text))
                i += 1
                continue
            }

            // Table - lines starting with |
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                var tableLines: [String] = []
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    tableLines.append(lines[i])
                    i += 1
                }

                if tableLines.count >= 2 {
                    // Parse header row
                    let headers = parseTableRow(tableLines[0])

                    // Skip separator row (|---|---|)
                    var dataStartIndex = 1
                    if tableLines.count > 1 && tableLines[1].contains("---") {
                        dataStartIndex = 2
                    }

                    // Parse data rows
                    var rows: [[String]] = []
                    for j in dataStartIndex..<tableLines.count {
                        let cells = parseTableRow(tableLines[j])
                        if !cells.isEmpty {
                            rows.append(cells)
                        }
                    }

                    blocks.append(.table(rows, headers))
                }
                continue
            }

            // Regular text - accumulate consecutive non-special lines
            var textLines: [String] = []
            while i < lines.count {
                let currentLine = lines[i]
                if currentLine.hasPrefix("```") || currentLine.hasPrefix("#") ||
                   currentLine.trimmingCharacters(in: .whitespaces).hasPrefix("- ") ||
                   currentLine.trimmingCharacters(in: .whitespaces).hasPrefix("* ") ||
                   currentLine.hasPrefix("> ") ||
                   currentLine.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    break
                }
                textLines.append(currentLine)
                i += 1
            }

            let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.text(text))
            }
        }

        return blocks
    }

    private func parseTableRow(_ line: String) -> [String] {
        var cells: [String] = []
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Remove leading and trailing pipes
        var content = trimmed
        if content.hasPrefix("|") {
            content = String(content.dropFirst())
        }
        if content.hasSuffix("|") {
            content = String(content.dropLast())
        }

        // Split by | and trim each cell
        let parts = content.components(separatedBy: "|")
        for part in parts {
            cells.append(part.trimmingCharacters(in: .whitespaces))
        }

        return cells
    }
}

