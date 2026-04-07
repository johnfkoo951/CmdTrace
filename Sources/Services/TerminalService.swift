import Foundation
import AppKit

/// Execute resume session in terminal (unified global function for all CLI types)
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

    launchCommandInTerminal(terminal: terminal, command: resumeCommand, projectPath: projectPath)
}

/// Unified entry point used by both "Resume Session" and "Start New Session".
/// Handles terminal-specific launch logic in one place so bugs are fixed everywhere.
func launchCommandInTerminal(terminal: TerminalType, command: String, projectPath: String) {
    let fullCommand = "cd '\(projectPath)' && \(command)"

    DispatchQueue.global(qos: .userInitiated).async {
        switch terminal {
        case .terminal:
            let script = """
            tell application "Terminal"
                activate
                do script "\(fullCommand)"
            end tell
            """
            runOsascriptGlobal(script)

        case .iterm:
            let script = """
            tell application "iTerm2"
                activate
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text "\(fullCommand)"
                end tell
            end tell
            """
            runOsascriptGlobal(script)

        case .warp:
            // Warp honors `open -a Warp <path>` for the cwd, so only the
            // command itself needs to be pasted.
            openAppAndPasteCommand(appName: "Warp", command: command, projectPath: projectPath)

        case .ghostty:
            // Ghostty on macOS doesn't support CLI +new-tab or -e.
            // Use clipboard + AppleScript paste approach (same as Warp).
            openAppAndPasteCommand(appName: "Ghostty", command: fullCommand, projectPath: nil)

        case .cmux:
            // cmux has a proper socket-based CLI. Use it directly —
            // avoid AppleScript keystroke hacks that create duplicate
            // synced windows.
            launchCmuxWorkspace(cwd: projectPath, command: command)
        }
    }
}

// MARK: - cmux helpers

/// Check if cmux is running by pinging its Unix socket
private func isCmuxRunning() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["cmux", "ping"]
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}

/// Launch cmux (if needed) and create a new workspace with the given command
private func launchCmuxWorkspace(cwd: String, command: String) {
    // Step 1: Ensure cmux is running
    if !isCmuxRunning() {
        // Launch cmux.app without opening a Finder window
        let openProcess = Process()
        openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        openProcess.arguments = ["-na", "cmux"]
        try? openProcess.run()
        openProcess.waitUntilExit()

        // Wait up to ~5s for the socket to come up
        var ready = false
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.25)
            if isCmuxRunning() {
                ready = true
                break
            }
        }
        if !ready {
            print("cmux: socket did not become ready")
            return
        }
    }

    // Step 2: Create a new workspace with the resume command
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["cmux", "new-workspace", "--cwd", cwd, "--command", command]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let err = String(data: data, encoding: .utf8), !err.isEmpty {
                print("cmux new-workspace error: \(err)")
            }
        }
    } catch {
        print("cmux new-workspace failed: \(error)")
        return
    }

    // Step 3: Bring cmux to the foreground without launching a new instance
    DispatchQueue.main.async {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "sh.cmux.cmux")
            + NSRunningApplication.runningApplications(withBundleIdentifier: "com.cmux.cmux")
        if let app = running.first {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
}

// MARK: - Generic clipboard + paste helper (Warp, Ghostty)

/// Open an app (optionally at a project path), copy command to clipboard,
/// then paste + Enter via System Events.
private func openAppAndPasteCommand(appName: String, command: String, projectPath: String?) {
    // Put the command on the clipboard first so the paste step is reliable
    DispatchQueue.main.async {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }

    // Launch the app. If a project path is supplied, open it so the app
    // lands in the right cwd (Warp supports this; Ghostty ignores it).
    let openProcess = Process()
    openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    if let projectPath = projectPath {
        openProcess.arguments = ["-a", appName, projectPath]
    } else {
        openProcess.arguments = ["-na", appName]
    }
    try? openProcess.run()
    openProcess.waitUntilExit()

    // Wait for the window to be ready to accept input
    Thread.sleep(forTimeInterval: 0.8)

    let script = """
    tell application "System Events"
        tell process "\(appName)"
            set frontmost to true
            delay 0.4
            keystroke "v" using command down
            delay 0.2
            key code 36
        end tell
    end tell
    """
    runOsascriptGlobal(script)
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
                print("osascript error: \(errorOutput)")
            }
        }
    } catch {
        print("Failed to run osascript: \(error)")
    }
}
