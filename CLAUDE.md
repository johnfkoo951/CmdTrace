# CmdTrace

macOS native SwiftUI app for viewing and managing AI CLI agent conversation histories.

## Project Overview

CmdTrace is a session viewer for CLI-based AI coding assistants (Claude Code, OpenCode, Antigravity). It reads JSONL conversation logs and provides a rich interface for browsing, organizing, and analyzing coding sessions.

## Tech Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (macOS 14+)
- **State Management**: Swift Observation (`@Observable`)
- **Package Manager**: Swift Package Manager
- **Data Storage**: JSON files in `~/Library/Application Support/CmdTrace/`

## Project Structure

```
Sources/
├── App/
│   ├── CmdTraceApp.swift    # App entry point, window/menu config
│   └── AppState.swift       # Global state (@Observable), settings, persistence
├── Models/
│   ├── Session.swift        # Session data model
│   └── Message.swift        # Message/conversation models
├── Services/
│   └── SessionService.swift # JSONL file parsing, session loading
└── Views/
    ├── ContentView.swift    # Main layout (NavigationSplitView)
    ├── SidebarView.swift    # Session list, tags, search/filter
    ├── DetailView.swift     # Conversation view, dashboard, AI interaction
    └── SettingsView.swift   # App settings UI
```

## Key Features

- **Multi-CLI Support**: Claude Code, OpenCode, Antigravity
- **3 Main Tabs**: Sessions, Dashboard, AI Interaction
- **Session Organization**: Favorites, pins, custom names, tags
- **Search**: Full-text + operators (`title:`, `tag:`, `project:`, `content:`)
- **Tag System**: Nested tags, colors, importance levels
- **AI Integration**: OpenAI, Anthropic, Gemini, Grok API settings
- **Obsidian Export**: Vault path configuration
- **Deep Links**: `cmdtrace://session/{id}`

## Data Paths

Session logs are read from:
- **Claude Code**: `~/.claude/projects/*/sessions/*.jsonl`
- **OpenCode**: `~/.opencode/sessions/*.jsonl`

App data stored in:
- `~/Library/Application Support/CmdTrace/settings.json`
- `~/Library/Application Support/CmdTrace/session-metadata.json`
- `~/Library/Application Support/CmdTrace/tag-database.json`
- `~/Library/Application Support/CmdTrace/summaries.json`

## Build & Run

```bash
# Build
swift build

# Build release app bundle
./build-app.sh

# Run debug
swift run
```

## Architecture Notes

### AppState Pattern
Uses Swift's `@Observable` macro for reactive state. Single source of truth for:
- Session list and selection
- UI state (tabs, search, filters)
- User settings and metadata
- Tag database

### Session Caching
Pre-loads sessions for all CLI tools on startup for instant switching between Claude Code and OpenCode.

### Persistence
All user data (settings, tags, favorites) persisted as JSON. Session metadata is stored separately from the session files themselves (which are read-only).

## Code Conventions

- Use `@Environment(AppState.self)` for accessing global state in views
- Use `@Bindable var state = appState` for two-way bindings
- Prefer `Task { await ... }` for async operations in SwiftUI
- Use SF Symbols for all icons
- Follow Apple HIG for macOS app design

## Keyboard Shortcuts

- `Cmd+R`: Refresh sessions
- `Cmd+F`: Focus search
- `Cmd+1/2/3`: Switch tabs (Sessions/Dashboard/AI)
