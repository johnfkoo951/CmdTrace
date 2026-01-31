import Foundation
import AppKit

/// Execute resume session in terminal (unified global function for all CLI types)
/// - Parameters:
///   - session: The session to resume
///   - terminal: Terminal type (Terminal.app, iTerm2, Warp)
///   - bypass: Whether to bypass permission checks (Claude Code only)
///   - cliType: The CLI tool type (Claude Code, OpenCode, Antigravity)
func executeResumeSession(_ session: Session, terminal: TerminalType, bypass: Bool, cliType: CLITool) {
    let projectPath = session.project
    
    let resumeCommand: String
    switch cliType {
    case .claude:
        resumeCommand = bypass
            ? "claude -r \(session.resumeId) --dangerously-skip-permissions"
            : "claude -r \(session.resumeId)"
    case .opencode:
        resumeCommand = "opencode --resume \(session.resumeId)"
    case .antigravity:
        resumeCommand = "antigravity --resume \(session.resumeId)"
    }

    DispatchQueue.global(qos: .userInitiated).async {
        switch terminal {
        case .terminal:
            let script = """
            tell application "Terminal"
                activate
                do script "cd '\(projectPath)' && \(resumeCommand)"
            end tell
            """
            runOsascriptGlobal(script)

        case .iterm:
            let script = """
            tell application "iTerm2"
                activate
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text "cd '\(projectPath)' && \(resumeCommand)"
                end tell
            end tell
            """
            runOsascriptGlobal(script)

        case .warp:
            // Warp: 명령어만 복사 (cd 없이! Warp가 해당 디렉토리에서 열림)
            DispatchQueue.main.async {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(resumeCommand, forType: .string)
            }

            let openProcess = Process()
            openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            openProcess.arguments = ["-a", "Warp", projectPath]
            try? openProcess.run()
            openProcess.waitUntilExit()

            Thread.sleep(forTimeInterval: 0.5)

            let pasteScript = """
            tell application "System Events"
                tell process "Warp"
                    set frontmost to true
                    delay 1.0
                    keystroke "v" using command down
                    delay 0.2
                    key code 36
                end tell
            end tell
            """
            runOsascriptGlobal(pasteScript)
        }
    }
}

/// Global osascript runner (for use outside of view context)
func runOsascriptGlobal(_ script: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]

    let pipe = Pipe()
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let errorOutput = String(data: data, encoding: .utf8) {
                print("osascript error (Inspector): \(errorOutput)")
            }
        }
    } catch {
        print("Failed to run osascript: \(error)")
    }
}
