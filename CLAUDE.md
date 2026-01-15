# CmdTrace

macOS native SwiftUI app for viewing and managing AI CLI agent conversation histories.

## Project Overview

CmdTrace is a session viewer for CLI-based AI coding assistants (Claude Code, OpenCode, Antigravity). It reads JSONL conversation logs and provides a rich interface for browsing, organizing, and analyzing coding sessions.

## Tech Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (macOS 14+)
- **Charts**: Swift Charts (for burn rate visualization)
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
    ├── DetailView.swift     # Conversation view, dashboard, AI interaction, usage tools
    └── SettingsView.swift   # App settings UI
```

## Key Features

### Session Management
- **Multi-CLI Support**: Claude Code, OpenCode, Antigravity
- **3 Main Tabs**: Sessions, Dashboard, AI Interaction
- **Session Organization**: Favorites, pins, custom names, tags
- **Search**: Full-text + operators (`title:`, `tag:`, `project:`, `content:`)
- **Tag System**: Nested tags, colors, importance levels
- **Deep Links**: `cmdtrace://session/{id}`

### Usage Tools (Dashboard)
- **ccusage Integration**: Daily, Monthly, Blocks views with JSON parsing
- **claude-monitor Integration**: Execute with plan selection (Pro, Max5, Max20)
- **Native Monitoring View**: Built-in real-time monitoring without Terminal

### Native Monitoring View
Real-time usage monitoring inside the app:
- **Customizable Colors**: ColorPicker for bar colors (cost, token, message, warning)
- **Auto-refresh**: Configurable intervals (5s, 10s, 30s, 60s)
- **Usage Bars**: Progress bars with plan limits
- **Model Distribution**: Color-coded model breakdown
- **Burn Rate Chart**: Swift Charts-based prediction graph
  - Token/Cost mode toggle
  - Projection line based on current burn rate
  - Limit threshold indicator
  - Gradient area visualization
  - Warning for exceeding limits

### AI Integration
- OpenAI, Anthropic, Gemini, Grok API settings
- Obsidian vault export configuration

## Data Paths

Session logs are read from:
- **Claude Code**: `~/.claude/projects/*/sessions/*.jsonl`
- **OpenCode**: `~/.opencode/sessions/*.jsonl`

App data stored in:
- `~/Library/Application Support/CmdTrace/settings.json`
- `~/Library/Application Support/CmdTrace/session-metadata.json`
- `~/Library/Application Support/CmdTrace/tag-database.json`
- `~/Library/Application Support/CmdTrace/summaries.json`

## External CLI Tools

Optional tools for usage monitoring:
```bash
# ccusage (Node.js) - Required for native monitoring
npm install -g ccusage
# or use: npx ccusage@latest

# claude-monitor (Python) - Optional TUI monitoring
pip install claude-monitor
# or: uv tool install claude-monitor
```

### ccusage Commands Used
```bash
# Native monitoring data source (5-hour block)
ccusage blocks --active --json --breakdown

# Daily view
ccusage daily --json --since YYYYMMDD

# Monthly view
ccusage monthly --json
```

## Build & Run

```bash
# Build
swift build

# Build release app bundle
./build-app.sh

# Run debug
swift run

# Deploy to Applications
cp -r ./build/CmdTrace.app /Applications/
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

### CLI Execution from GUI
When executing CLI tools (ccusage, claude-monitor) from the GUI:
- Use `/bin/zsh -l -c` to load shell environment
- Redirect stderr: `2>/dev/null` to avoid JSON parsing errors
- Use temp files for output to handle large responses
- Calculate dates in Swift instead of shell subcommands

## Code Conventions

- Use `@Environment(AppState.self)` for accessing global state in views
- Use `@Bindable var state = appState` for two-way bindings
- Prefer `Task { await ... }` for async operations in SwiftUI
- Use SF Symbols for all icons
- Follow Apple HIG for macOS app design
- Import `Charts` for data visualization

## Key View Components (DetailView.swift)

### Usage Section
- `UsageSection`: Main container for usage tools
- `UsageTabView`: Tab switcher for ccusage views
- `UsageOutputView`: Display ccusage results

### Native Monitor
- `NativeMonitorView`: Main monitoring sheet
- `MonitorData`: Data model for monitoring state
- `MonitorBarView`: Reusable progress bar component
- `BurnRateChartView`: Swift Charts-based prediction graph
- `ProjectionPoint`: Data point for chart projection
- `ColorCustomizationView`: Color picker popover

### Enums
- `ClaudePlan`: Pro, Max5, Max20 with limits
- `UsageTab`: daily, monthly, blocks
- `ChartMode`: tokens, cost

## Keyboard Shortcuts

- `Cmd+R`: Refresh sessions
- `Cmd+F`: Focus search
- `Cmd+1/2/3`: Switch tabs (Sessions/Dashboard/AI)

## Version
## Development Roadmap

### Completed (v2.3.0)

| Feature | Description | Status |
|---------|-------------|--------|
| Search Enhancement | `date:`, `regex:`, `messages:` operators | ✅ |
| Export Sessions | Markdown, JSON, Plain Text, HTML | ✅ |
| Session Diff | Side-by-side comparison | ✅ |
| Statistics Dashboard | 30-day activity, project/tag distribution | ✅ |
| Keyboard Navigation | ↑↓ in session list | ✅ |
| Markdown Tables | Improved rendering with auto-width | ✅ |
| Inspector Reorganization | Session Info → Summary → Actions → Details | ✅ |

### In Progress (v2.4.0-alpha)

| Feature | Description | Priority |
|---------|-------------|----------|
| Cloud Sync | iCloud sync for metadata, tags, summaries | High |
| Search Highlighting | Highlight matches in conversation view | Medium |
| Session Archive | Archive old sessions to reduce clutter | Medium |
| Bulk Operations | Multi-select for tags, export, delete | Medium |

### Planned (v2.5.0+)

| Feature | Description | Priority |
|---------|-------------|----------|
| Menu Bar App | Quick access widget in menu bar | High |
| Global Hotkey | System-wide shortcut to open CmdTrace | High |
| Session Merge | Combine multiple sessions | Medium |
| Full-text Index | SQLite FTS for faster content search | Medium |
| Timeline View | Visual timeline of all sessions | Low |
| Widgets | macOS widgets for recent sessions | Low |
| Shortcuts Integration | Siri Shortcuts support | Low |

### Known Issues

| Issue | Description | Workaround |
|-------|-------------|------------|
| Cloud Sync | CloudKit container not configured | Coming Soon |
| Large Sessions | Slow loading for 1000+ message sessions | Pagination planned |

### Development Notes

**Current Focus**: Cloud Sync 구현 완료 후 v2.4.0 릴리즈 예정

**Tech Debt**:
- DetailView.swift 크기 (3700+ lines) → 분리 필요
- Session loading 최적화 필요


Current: v2.4.0-alpha

### Version Management

버전 변경 시 아래 파일들을 **모두** 업데이트해야 함:

| 파일 | 위치 | 형식 |
|------|------|------|
| `build-app.sh` | `VERSION="..."` | `2.1.0` |
| `CLAUDE.md` | `Current: v...` | `v2.1.0` |
| `website/index.html` | `<span class="version">` | `v2.1.0` |

### Semantic Versioning (SemVer)

```
vMAJOR.MINOR.PATCH-prerelease
```

| 자리 | 올릴 때 |
|------|---------|
| **MAJOR** | 호환 안 되는 변경 (데이터 포맷, 설정 구조 변경) |
| **MINOR** | 새 기능 추가 (기존 기능 유지) |
| **PATCH** | 버그 수정, 사소한 개선 |

### Pre-release 태그

| 태그 | 의미 |
|------|------|
| `alpha` | 개발 중, 기능 불완전 |
| `beta` | 기능 완성, 테스트 중 |
| `rc` | Release Candidate, 릴리즈 직전 |
| (없음) | 정식 릴리즈 |

### Release 절차

```bash
# 1. 버전 파일들 업데이트 (위 테이블 참고)

# 2. 앱 빌드
./build-app.sh

# 3. DMG 생성
./build-dmg.sh

# 4. 커밋 & 푸시
git add -A && git commit -m "chore: bump version to vX.X.X"
git push origin main

# 5. 태그 생성 & 푸시
git tag vX.X.X-buildN
git push origin vX.X.X-buildN

# 6. GitHub 릴리즈 생성
gh release create vX.X.X-buildN ./build/*.dmg --title "CmdTrace vX.X.X" --prerelease
```
