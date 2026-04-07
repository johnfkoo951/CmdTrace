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

/// Resolve the cmux CLI binary. A GUI app's inherited PATH does NOT include
/// `/Applications/cmux.app/Contents/Resources/bin`, so `/usr/bin/env cmux`
/// fails silently. We look in well-known locations first, then fall back to
/// a login shell lookup which loads the user's full PATH.
private func resolveCmuxBinary() -> String? {
    let candidates = [
        "/Applications/cmux.app/Contents/Resources/bin/cmux",
        "/usr/local/bin/cmux",
        "/opt/homebrew/bin/cmux",
        "\(NSHomeDirectory())/.local/bin/cmux",
    ]
    for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
        return path
    }

    // Fallback: ask a login shell where cmux is
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-l", "-c", "command -v cmux"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let path = path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
    } catch {
        // fall through
    }
    return nil
}

/// Run a cmux subcommand. Returns (exitCode, combinedOutput).
@discardableResult
private func runCmux(_ args: [String]) -> (Int32, String) {
    guard let cmuxPath = resolveCmuxBinary() else {
        return (-1, "cmux binary not found")
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: cmuxPath)
    process.arguments = args

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    } catch {
        return (-1, "\(error)")
    }
}

/// Check if cmux is running by pinging its Unix socket
private func isCmuxRunning() -> Bool {
    let (status, _) = runCmux(["ping"])
    return status == 0
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
            NSLog("cmux: socket did not become ready")
            return
        }
    }

    // Step 2: Create a new workspace with the resume command
    let (status, output) = runCmux(["new-workspace", "--cwd", cwd, "--command", command])
    if status != 0 {
        NSLog("cmux new-workspace failed (status=\(status)): \(output)")
        return
    }

    // Step 3: Bring cmux to the foreground without launching a new instance
    DispatchQueue.main.async {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "sh.cmux.cmux")
            + NSRunningApplication.runningApplications(withBundleIdentifier: "com.cmux.cmux")
        if let app = running.first {
            app.activate()
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
