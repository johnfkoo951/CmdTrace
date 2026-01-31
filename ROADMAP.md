# CmdTrace Development Roadmap

## Current Version: v2.4.1

---

## Version History

### v2.4.1 (2026-02-01)
- **Architecture Refactor**: DetailView.swift (3700+ lines) → 모듈별 파일로 분리
  - `SessionHeaderView`, `InspectorPanelView`, `MessageBubbleView`, `HelperViews`, `SessionListViews`, `TagBrowserView`
- **AppState Refactor**: AppState.swift → 매니저 클래스로 분리
  - `PersistenceManager`, `ProjectManager`, `SessionFilter`, `TagManager`
- **Service Layer**: 서비스 로직 분리
  - `SummaryService`, `TerminalService`, `Utilities/`
- **Tag System Enhancement**:
  - 태그 이름 변경 + 모든 세션에 일괄 업데이트
  - 태그 시트에서 실시간 필터링
  - Tags 뷰 전용 검색바
- **UI Polish**:
  - CLI 셀렉터 Segmented 버튼 UI 개선
  - 태그 팝오버 외부 클릭 시 닫기
  - CLI 토글 순서 고정
- **Website Overhaul**: 랜딩 페이지 전면 리디자인

### v2.4.0 (2026-01-21)
- **Session Archive**: Archive/unarchive sessions, bulk archive, auto-archive old sessions
- **Bulk Operations**: Multi-select, bulk tag/archive/favorite, select all
- **Search Highlighting**: AttributedString-based highlighting in conversation
- **Cloud Sync UI**: Settings UI for iCloud sync (backend pending)
- **Projects Tab**: Project metadata management with full-width dashboard layout
- **Configuration Enhancement**: Copy, export, auto-refresh 기능 추가

### v2.3.0 (2026-01-18)
- **Search Enhancement**: `date:`, `regex:`, `messages:` operators
- **Export Sessions**: Markdown, JSON, Plain Text, HTML
- **Session Diff**: Side-by-side comparison
- **Statistics Dashboard**: 30-day activity, project/tag distribution
- **Keyboard Navigation**: ↑↓ in session list
- **Markdown Tables**: Improved rendering with auto-width
- **Inspector Reorganization**: Session Info → Summary → Actions → Details

### v2.2.0 (2026-01-16)
- **Configuration Tab**: Commands, Skills, Hooks, Agents, Plugins 뷰어
- **Session Insights**: 토큰 사용량, 예상 비용, 도구 통계
- **Used in Session**: 세션별 Commands/Skills/Hooks 사용 내역
- Global/Project 스코프 필터
- 카테고리별 도구 그룹핑 및 프로그레스 바

### v2.1.0 (2026-01-15)
- AI Summary 다중 환경 호환성 개선
- Resume 함수 통합 리팩토링
- 모든 AI Provider (Anthropic, OpenAI, Gemini, Grok) API 호환성 수정
- JSON 파싱 안정화
- 2026 추천 모델 목록 업데이트
- Tag/QuickActions/Obsidian Export 기능 개선
- 웹사이트 Gatekeeper/권한 안내 추가

### v2.0.0 (2026-01-XX)
- Native Monitoring View (ccusage 연동)
- Burn Rate Chart (Swift Charts)
- Color Customization
- DMG 빌드 스크립트
- 종합 README 및 스크린샷

### v1.0.0 (Initial Release)
- 세션 뷰어 (Claude Code, OpenCode, Antigravity)
- 검색 (content:, title:, tag:, project:, date:)
- 태그, 즐겨찾기, 핀
- Resume 기능 (Terminal, iTerm2, Warp)
- AI 요약 생성 (Anthropic, OpenAI, Gemini, Grok)
- Obsidian 내보내기
- Deep Links (cmdtrace://session/{id})

---

## Implemented Features

### Core Features
| Feature | Status | Version |
|---------|--------|---------|
| Session Viewer | ✅ Done | v1.0.0 |
| Multi-CLI Support (Claude, OpenCode, Antigravity) | ✅ Done | v1.0.0 |
| Search with Operators | ✅ Done | v1.0.0 |
| Tags & Organization | ✅ Done | v1.0.0 |
| Favorites & Pins | ✅ Done | v1.0.0 |
| Resume Session | ✅ Done | v1.0.0 |
| Deep Links | ✅ Done | v1.0.0 |
| Tag Rename with Bulk Update | ✅ Done | v2.4.1 |
| Tag Real-time Filtering | ✅ Done | v2.4.1 |

### AI Features
| Feature | Status | Version |
|---------|--------|---------|
| AI Summary Generation | ✅ Done | v1.0.0 |
| Auto Title Generation | ✅ Done | v1.0.0 |
| Multi-Provider Support | ✅ Done | v1.0.0 |
| Tag Suggestions | ✅ Done | v1.0.0 |

### Monitoring
| Feature | Status | Version |
|---------|--------|---------|
| ccusage Integration | ✅ Done | v2.0.0 |
| Native Monitoring View | ✅ Done | v2.0.0 |
| Burn Rate Chart | ✅ Done | v2.0.0 |
| Plan Limits (Pro, Max5, Max20) | ✅ Done | v2.0.0 |

### Session Analysis
| Feature | Status | Version |
|---------|--------|---------|
| Configuration Tab | ✅ Done | v2.2.0 |
| Session Insights (Token/Cost) | ✅ Done | v2.2.0 |
| Tool Usage Statistics | ✅ Done | v2.2.0 |
| Search Enhancement (date/regex/messages) | ✅ Done | v2.3.0 |
| Export (Markdown/JSON/Text/HTML) | ✅ Done | v2.3.0 |
| Session Diff | ✅ Done | v2.3.0 |
| Statistics Dashboard | ✅ Done | v2.3.0 |

### Organization
| Feature | Status | Version |
|---------|--------|---------|
| Session Archive & Bulk Ops | ✅ Done | v2.4.0 |
| Search Highlighting | ✅ Done | v2.4.0 |
| Projects Tab | ✅ Done | v2.4.0 |
| Cloud Sync UI | ⚠️ UI Only | v2.4.0 |

### Architecture
| Feature | Status | Version |
|---------|--------|---------|
| DetailView Modular Split | ✅ Done | v2.4.1 |
| AppState Manager Extraction | ✅ Done | v2.4.1 |
| Service Layer Separation | ✅ Done | v2.4.1 |

### Export
| Feature | Status | Version |
|---------|--------|---------|
| Obsidian Export | ✅ Done | v1.0.0 |
| Hookmark Integration | ✅ Done | v1.0.0 |
| Summary Download | ✅ Done | v1.0.0 |

---

## Development Roadmap

### Phase 1: Foundation (v1.0.0 ~ v2.1.0) ✅ Completed

세션 뷰어 기본 기능, AI 요약, 모니터링, 멀티 CLI 지원.

| Milestone | Description | Status |
|-----------|-------------|--------|
| v1.0.0 | Session viewer, search, tags, resume, AI summary, deep links | ✅ |
| v2.0.0 | Native monitoring, burn rate chart, ccusage integration | ✅ |
| v2.1.0 | API 호환성 수정, AI provider 안정화, resume 리팩토링 | ✅ |

### Phase 2: Session Insights (v2.2.0 ~ v2.3.0) ✅ Completed

세션 분석, 설정 뷰어, 검색 고도화, 내보내기.

| Milestone | Description | Status |
|-----------|-------------|--------|
| v2.2.0 | Configuration tab, session insights (token/cost/tools) | ✅ |
| v2.3.0 | Advanced search, export, session diff, statistics dashboard | ✅ |

### Phase 3: Organization & Architecture (v2.4.0 ~ v2.4.1) ✅ Completed

세션 정리 기능 강화, 코드 아키텍처 개선.

| Milestone | Description | Status |
|-----------|-------------|--------|
| v2.4.0 | Archive, bulk ops, search highlighting, projects tab | ✅ |
| v2.4.1 | Codebase modular refactor, tag system enhancement, website overhaul | ✅ |

### Phase 4: Cloud Sync & Automation (v2.5.0) 🔄 Next Up

| Feature | Description | Priority |
|---------|-------------|----------|
| Cloud Sync Backend | CloudKit container setup, metadata sync | High |
| Auto-Tagging | AI-based automatic tag suggestions | Medium |
| Auto-Summary on Close | Generate summary when session ends | Medium |
| Smart Search Suggestions | Search autocomplete | Low |

### Phase 5: Ecosystem Integration (v2.6.0+)

| Feature | Description | Priority |
|---------|-------------|----------|
| Menu Bar App | Quick access widget in menu bar | High |
| Global Hotkey | System-wide shortcut to open CmdTrace | High |
| Spotlight Search | System search integration | Medium |
| Raycast Extension | Quick session search/launch | Medium |
| Shortcuts App | Siri Shortcuts support | Low |

### Phase 6: Collaboration (v3.0.0)

| Feature | Description | Priority |
|---------|-------------|----------|
| Session Sharing | Generate read-only share links | Medium |
| Team Workspaces | Shared tag/classification system | Low |
| Knowledge Base | Team session archive | Low |

### Phase 7: Advanced Analytics (v3.1.0)

| Feature | Description | Priority |
|---------|-------------|----------|
| Weekly/Monthly Reports | Period-based usage reports | Medium |
| Git Integration | Link sessions to commits | Medium |
| Code Impact Analysis | Track AI-written code | Low |
| Timeline View | Chronological tool usage visualization | Low |

---

## Backlog

| Feature | Description | Priority |
|---------|-------------|----------|
| Session Merge | Combine multiple sessions | Medium |
| Full-text Index | SQLite FTS for faster content search | Medium |
| macOS Widgets | Recent sessions widget | Low |
| VS Code Extension | Sidebar session browsing | Low |
| Notion Export | Export to Notion database | Low |
| E2E Encryption | Optional encryption for sync | Low |

---

## Known Issues

| Issue | Description | Workaround |
|-------|-------------|------------|
| Cloud Sync | CloudKit container not configured | UI ready, backend v2.5.0 |
| Large Sessions | Slow loading for 1000+ message sessions | Pagination planned |

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| ✅ Done | Implemented and released |
| 🔄 In Progress | Currently being developed |
| ⏳ Planned | Scheduled for development |
| ⚠️ Partial | Partially implemented |
| 💡 Idea | Under consideration |
| ❌ Cancelled | Not pursuing |

---

## Contributing

Feature requests and feedback welcome via [GitHub Issues](https://github.com/johnfkoo951/CmdTrace/issues).
