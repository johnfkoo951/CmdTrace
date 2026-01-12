# CmdTrace

<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="CmdTrace Icon">
</p>

<p align="center">
  <strong>macOS native session viewer for AI CLI coding assistants</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#keyboard-shortcuts">Shortcuts</a> •
  <a href="#license">License</a>
</p>

---

## Overview

CmdTrace is a macOS native SwiftUI application for viewing and managing AI CLI agent conversation histories. It reads JSONL conversation logs from Claude Code, OpenCode, and Antigravity, providing a rich interface for browsing, organizing, and analyzing coding sessions.

## Features

### Session Management
- **Multi-CLI Support**: Claude Code, OpenCode, Antigravity
- **Session Organization**: Favorites, pins, custom names, tags
- **Full-text Search**: With operators (`title:`, `tag:`, `project:`, `content:`)
- **Deep Links**: `cmdtrace://session/{id}` for quick access

### Dashboard
- **Session Statistics**: Total sessions, messages, tokens overview
- **Activity Calendar**: GitHub-style contribution heatmap
- **Model Distribution**: Visualize usage across AI models

### Usage Tools Integration

CmdTrace integrates with popular usage monitoring tools:

#### ccusage Support
- Daily, Monthly, Weekly reports
- 5-hour billing blocks view
- JSON output parsing
- Model breakdown analysis

#### Native Monitoring View (Built-in)
Real-time monitoring without leaving the app:
- **Customizable Colors**: Adjust bar colors to your preference
- **Auto-refresh**: 5s, 10s, 30s, 60s intervals
- **Usage Bars**: Cost, Token, Message usage with limits
- **Model Distribution**: Visual breakdown by model
- **Burn Rate Chart**: Interactive prediction graph
  - Token/Cost mode toggle
  - Projection to block end
  - Limit warning indicators
  - Gradient area visualization

#### claude-monitor Support
- Execute directly from CmdTrace
- Plan selection (Pro, Max5, Max20)
- View modes (Realtime, Daily, Monthly)

### AI Integration
- OpenAI, Anthropic, Gemini, Grok API settings
- Obsidian vault export configuration

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+

### Optional CLI Tools
For usage monitoring features:
```bash
# ccusage (Node.js)
npm install -g ccusage
# or use npx ccusage@latest

# claude-monitor (Python)
pip install claude-monitor
# or uv tool install claude-monitor
```

## Installation

### Build from Source

```bash
# Clone the repository
git clone https://github.com/cmdspace/CmdTrace.git
cd CmdTrace

# Build release app bundle
./build-app.sh

# Install to Applications
cp -r ./build/CmdTrace.app /Applications/
```

### Run in Development

```bash
swift build
swift run
```

## Usage

### Data Paths

Session logs are read from:
- **Claude Code**: `~/.claude/projects/*/sessions/*.jsonl`
- **OpenCode**: `~/.opencode/sessions/*.jsonl`

App data stored in:
- `~/Library/Application Support/CmdTrace/settings.json`
- `~/Library/Application Support/CmdTrace/session-metadata.json`
- `~/Library/Application Support/CmdTrace/tag-database.json`

### Using the Native Monitor

1. Go to Dashboard tab
2. Find "Usage Tools" section
3. Click menu button (•••)
4. Select "Native Monitoring" (내장 모니터링)

Features:
- Toggle between Token and Cost views in the chart
- Click the palette icon to customize colors
- Set auto-refresh interval
- View burn rate predictions

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+R` | Refresh sessions |
| `Cmd+F` | Focus search |
| `Cmd+1` | Sessions tab |
| `Cmd+2` | Dashboard tab |
| `Cmd+3` | AI Interaction tab |

## Project Structure

```
Sources/
├── App/
│   ├── CmdTraceApp.swift    # App entry point
│   └── AppState.swift       # Global state (@Observable)
├── Models/
│   ├── Session.swift        # Session data model
│   └── Message.swift        # Message models
├── Services/
│   └── SessionService.swift # JSONL parsing
└── Views/
    ├── ContentView.swift    # Main layout
    ├── SidebarView.swift    # Session list
    ├── DetailView.swift     # Conversation view, dashboard
    └── SettingsView.swift   # App settings
```

## Tech Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **State Management**: Swift Observation (`@Observable`)
- **Charts**: Swift Charts
- **Package Manager**: Swift Package Manager

## License

Copyright (c) 2025 CMDSPACE. All Rights Reserved.

This is proprietary software. See [LICENSE](LICENSE) for details.

## Contact

For licensing inquiries: johnfkoo951@gmail.com
