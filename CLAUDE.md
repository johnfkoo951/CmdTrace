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
│   ├── CmdTraceApp.swift        # App entry point, window/menu config
│   ├── AppState.swift           # Global state (@Observable), debounced search/save
│   ├── PersistenceManager.swift # Background I/O with atomic writes
│   ├── ProjectManager.swift     # Project metadata management
│   ├── SessionFilter.swift      # Search operators and filtering logic
│   └── TagManager.swift         # Tag CRUD and bulk operations
├── Models/
│   ├── Session.swift            # Session data model
│   ├── Message.swift            # Message/conversation models
│   ├── UsageData.swift          # Usage data models (UsageData, UsageViewMode)
│   ├── ClaudeConfig.swift       # Claude configuration parsing
│   ├── ProjectMetadata.swift    # Project metadata model
│   └── SessionInsights.swift    # Token/tool/model usage analysis models
├── Services/
│   ├── SessionService.swift     # JSONL file parsing with memory-efficient streaming
│   ├── SummaryService.swift     # AI-powered session summarization
│   ├── ClaudeConfigService.swift # Claude config file reading
│   ├── CloudSyncService.swift   # iCloud sync (UI ready, backend pending)
│   ├── LocalServer.swift        # Embedded HTTP server for webapp dashboard
│   ├── APIRouter.swift          # Multi-provider API routing
│   └── TerminalService.swift    # Shell command execution
└── Views/  (23 files)
    ├── ContentView.swift        # Main layout (NavigationSplitView)
    ├── SidebarView.swift        # 4-tab sidebar (Files/Search/Favorites/Vaults)
    ├── DetailView.swift         # Session detail routing (~140 lines)
    ├── SessionHeaderView.swift  # Session header with metadata
    ├── SessionListViews.swift   # Session list, filters, bulk actions, stats bar
    ├── InspectorPanelView.swift # Right inspector (TOC/Properties/Actions)
    ├── MessageBubbleView.swift  # Chat bubble rendering
    ├── HelperViews.swift        # Shared UI helpers
    ├── DashboardView.swift      # Dashboard tab
    ├── UsageViews.swift         # ccusage data display (~710 lines)
    ├── NativeMonitorView.swift  # Real-time monitor with backpressure (~780 lines)
    ├── InteractionView.swift    # AI interaction tab
    ├── MarkdownTextView.swift   # Markdown rendering with block caching (~280 lines)
    ├── SessionInsightsView.swift # Token/tool/model usage views
    ├── InsightsViews.swift      # Additional insight components
    ├── StatisticsView.swift     # Statistics sheet
    ├── ConfigurationView.swift  # CLI settings and API config (~980 lines)
    ├── ProjectsView.swift       # Projects dashboard (~780 lines)
    ├── SettingsView.swift       # App settings (~910 lines)
    ├── TagBrowserView.swift     # Tag browsing and management (~600 lines)
    ├── SessionDiffView.swift    # Session comparison (side-by-side)
    ├── ExportView.swift         # Session export (MD/JSON/TXT/HTML)
    └── Components/              # Reusable UI components
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
- `~/Library/Application Support/CmdTrace/project-metadata.json`

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
All user data (settings, tags, favorites) persisted as JSON via `PersistenceManager`:
- **Background I/O**: File writes run on `DispatchQueue.global(qos: .utility)` with `.atomic` option
- **Debounced Save**: 500ms debounce to batch rapid changes; `saveUserDataNow()` for critical saves (app quit)
- Session metadata is stored separately from the session files themselves (which are read-only)

### Debouncing
- **Search**: 300ms debounce on `searchText` changes to avoid filtering on every keystroke
- **Save**: 500ms debounce on `saveUserData()` to batch I/O; immediate flush on app deactivate via `scenePhase`

### JSONL Parsing
- Uses `enumerateSubstrings(in:options:.byLines)` for memory-efficient line iteration (not `components(separatedBy:)`)
- `reserveCapacity` on message arrays based on known `messageCount`

### Embedded HTTP Server
`LocalServer.swift` provides a built-in HTTP server for webapp dashboard access (Phase A).

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

## Key View Components

### Native Monitor (NativeMonitorView.swift)
- `NativeMonitorView`: Main monitoring sheet with backpressure guard
- `MonitorData`: Data model for monitoring state
- `MonitorBarView`: Reusable progress bar component
- `BurnRateChartView`: Swift Charts-based prediction graph

### Inspector (InspectorPanelView.swift)
- Session info, summary, actions, detail sections
- Tag editing with real-time filtering

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

### Completed (v2.4.0)

| Feature | Description | Status |
|---------|-------------|--------|
| Session Archive | Archive/unarchive sessions, bulk archive, auto-archive old sessions | ✅ |
| Bulk Operations | Multi-select, bulk tag/archive/favorite, select all | ✅ |
| Search Highlighting | AttributedString-based highlighting in conversation | ✅ |
| Cloud Sync UI | Settings UI for iCloud sync (backend pending) | ⚠️ UI Only |
| DetailView Refactor | 3700+ lines → 10+ modular view files | ✅ |

### Completed (v2.4.1)

| Feature | Description | Status |
|---------|-------------|--------|
| Embedded HTTP Server | LocalServer for webapp dashboard (Phase A) | ✅ |
| Tag Rename | Bulk update across all sessions | ✅ |
| Tag Search Bar | Dedicated search in Tags view | ✅ |
| CLI Selector | Improved UI with stable toggle order | ✅ |

### Completed (v2.4.2)

| Feature | Description | Status |
|---------|-------------|--------|
| Search Debounce | 300ms delay to reduce filtering during typing | ✅ |
| Save Debounce | 500ms delay + immediate flush on app deactivate | ✅ |
| Background I/O | PersistenceManager on utility queue with atomic writes | ✅ |
| JSONL Parsing | enumerateSubstrings for memory-efficient line iteration | ✅ |
| Bulk Op Optimization | Single save per batch instead of per-item | ✅ |
| Markdown Caching | Block parse results cached, re-parsed only on content change | ✅ |
| StatsBar Caching | Message count computed on change, not every frame | ✅ |
| Monitor Backpressure | Prevent overlapping data loads | ✅ |

### Completed (v2.5.0)

| Feature | Description | Status |
|---------|-------------|--------|
| Claude Code Features Dashboard | Agent, Hooks, Teams, Skills, Commands, Plugins, MCP visualization | ✅ |
| cmux-style Sidebar | Vertical icon strip activity bar, notification badges | ✅ |
| Modern Hook Parsing | settings.json hook rules (25+ event types, 4 hook types) | ✅ |
| Agent Teams | Team grouping and teammate visualization | ✅ |
| MCP Server Dashboard | Transport types, connection status, config display | ✅ |
| Plugin Component Tracking | Skill/Agent/Hook counts per plugin | ✅ |
| Features Tab (Cmd+4) | Dedicated tab for Claude Code configuration browser | ✅ |
| Dashboard Quick Cards | Feature overview cards with navigation to Features tab | ✅ |

### Planned (v2.6.0+)

| Feature | Description | Priority |
|---------|-------------|----------|
| Cloud Sync Backend | CloudKit container setup, actual sync | High |
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
| Cloud Sync | CloudKit container not configured | UI ready, backend v2.5.0 |
| Large Sessions | Slow loading for 1000+ message sessions | Pagination planned |

### Development Notes

**Current Focus**: v2.5.0에서 Cloud Sync 백엔드 구현 및 Menu Bar App 개발

**Tech Debt**:
- ConfigurationView.swift (~980 lines), SettingsView.swift (~910 lines) 분리 검토
- ~~DetailView.swift 분리~~ → v2.4.0에서 완료
- ~~Session loading 최적화~~ → v2.4.2에서 JSONL 파싱 개선 완료


Current: v2.5.1

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




