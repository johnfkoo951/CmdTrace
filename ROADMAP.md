# CmdTrace Development Roadmap

## Current Version: v2.2.0

---

## Version History

### v2.2.0 (2026-01-16)
- **Configuration Tab**: Commands, Skills, Hooks, Agents, Plugins 뷰어
- **Session Insights**: 토큰 사용량, 예상 비용, 도구 통계
- **Used in Session**: 세션별 Commands/Skills/Hooks 사용 내역
- Global/Project 스코프 필터
- 카테고리별 도구 그룹핑 및 프로그레스 바

### v2.1.0 (2025-01-15)
- Resume 함수 통합 리팩토링
- async/await 경고 수정
- 웹사이트 Gatekeeper/권한 안내 추가

### v2.0.0 (2025-01-XX)
- Native Monitoring View (ccusage 연동)
- Burn Rate Chart (Swift Charts)
- Color Customization

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

### Export
| Feature | Status | Version |
|---------|--------|---------|
| Obsidian Export | ✅ Done | v1.0.0 |
| Hookmark Integration | ✅ Done | v1.0.0 |
| Summary Download | ✅ Done | v1.0.0 |

---

## Development Roadmap

### Phase 1: Session Insights (v2.2) - 🔄 In Progress

#### 1.1 Tool/Skill/Hook Tracking
| Feature | Status | Description |
|---------|--------|-------------|
| Tool Usage Parsing | ⏳ Planned | Parse tool calls from JSONL (Read, Write, Bash, etc.) |
| Skill Invocation Log | ⏳ Planned | Track which skills were invoked |
| Hook Trigger History | ⏳ Planned | Record hook trigger events |
| Usage Statistics | ⏳ Planned | Tool usage frequency, success/failure rate |
| Timeline View | ⏳ Planned | Chronological tool usage visualization |

#### 1.2 Session Analysis
| Feature | Status | Description |
|---------|--------|-------------|
| Token Usage per Session | ⏳ Planned | Calculate token consumption per session |
| Cost Estimation | ⏳ Planned | Display estimated cost |
| Code Change Summary | ⏳ Planned | List of files modified in session |
| Error Pattern Detection | ⏳ Planned | Detect recurring error patterns |

---

### Phase 2: Cloud Sync (v2.3)

#### 2.1 Authentication
| Feature | Status | Description |
|---------|--------|-------------|
| Google Sign-In | ⏳ Planned | OAuth 2.0 based login |
| Apple Sign-In | ⏳ Planned | Native macOS authentication |
| Account Management | ⏳ Planned | Settings, logout, deletion |

#### 2.2 Cross-Device Sync
| Feature | Status | Description |
|---------|--------|-------------|
| Metadata Sync | ⏳ Planned | Sync tags, favorites, custom names |
| Summary Sync | ⏳ Planned | Sync AI-generated summaries |
| Settings Sync | ⏳ Planned | Sync app settings |
| Conflict Resolution | ⏳ Planned | UI for resolving sync conflicts |

> ⚠️ **Privacy**: Session content stays local. Only metadata syncs.

#### 2.3 Backend Infrastructure
| Feature | Status | Description |
|---------|--------|-------------|
| Firebase/Supabase | ⏳ Planned | Realtime DB + Auth |
| CloudKit Option | ⏳ Planned | Apple ecosystem alternative |
| E2E Encryption | ⏳ Planned | Optional encryption |

---

### Phase 3: Automation & AI (v2.4)

#### 3.1 Smart Automation
| Feature | Status | Description |
|---------|--------|-------------|
| Auto-Tagging | ⏳ Planned | AI-based automatic tag suggestions |
| Auto-Summary on Close | ⏳ Planned | Generate summary when session ends |
| Smart Search Suggestions | ⏳ Planned | Search autocomplete |
| Related Sessions | ⏳ Planned | Recommend similar sessions |

#### 3.2 Workflow Automation
| Feature | Status | Description |
|---------|--------|-------------|
| Scheduled Backup | ⏳ Planned | Periodic backup (iCloud, external) |
| Export Automation | ⏳ Planned | Conditional auto-export to Obsidian |
| Cleanup Rules | ⏳ Planned | Auto-cleanup old sessions |

---

### Phase 4: Collaboration (v2.5)

#### 4.1 Session Sharing
| Feature | Status | Description |
|---------|--------|-------------|
| Share Link | ⏳ Planned | Generate read-only share links |
| Export Formats | ⏳ Planned | Markdown, HTML, PDF export |
| Snippet Sharing | ⏳ Planned | Share specific conversation parts |

#### 4.2 Team Features
| Feature | Status | Description |
|---------|--------|-------------|
| Team Workspaces | ⏳ Planned | Shared tag/classification system |
| Session Comments | ⏳ Planned | Add comments to sessions |
| Knowledge Base | ⏳ Planned | Team session archive |

---

### Phase 5: Ecosystem Integration (v3.0)

#### 5.1 IDE Integration
| Feature | Status | Description |
|---------|--------|-------------|
| VS Code Extension | ⏳ Planned | Sidebar session browsing |
| JetBrains Plugin | ⏳ Planned | IntelliJ/WebStorm support |
| Cursor Integration | ⏳ Planned | Cursor IDE integration |

#### 5.2 macOS Integration
| Feature | Status | Description |
|---------|--------|-------------|
| Spotlight Search | ⏳ Planned | System search integration |
| Quick Look | ⏳ Planned | Session file preview |
| Shortcuts App | ⏳ Planned | Automation actions |
| Menu Bar Widget | ⏳ Planned | Quick access widget |

#### 5.3 External Services
| Feature | Status | Description |
|---------|--------|-------------|
| Raycast Extension | ⏳ Planned | Quick session search/launch |
| Alfred Workflow | ⏳ Planned | Power user support |
| Notion Export | ⏳ Planned | Export to Notion database |
| Linear/Jira Link | ⏳ Planned | Issue tracker integration |

---

### Phase 6: Advanced Analytics (v3.1)

#### 6.1 Productivity Dashboard
| Feature | Status | Description |
|---------|--------|-------------|
| Weekly/Monthly Reports | ⏳ Planned | Period-based usage reports |
| Productivity Trends | ⏳ Planned | Trend graphs |
| Project Insights | ⏳ Planned | Per-project AI usage analysis |
| Learning Patterns | ⏳ Planned | FAQ pattern analysis |

#### 6.2 Code Insights
| Feature | Status | Description |
|---------|--------|-------------|
| Git Integration | ⏳ Planned | Link sessions to commits |
| Code Impact Analysis | ⏳ Planned | Track AI-written code |
| Refactoring History | ⏳ Planned | Refactoring history visualization |

---

## Priority Matrix

| Phase | Difficulty | Value | Est. Duration |
|-------|------------|-------|---------------|
| Phase 1 (Insights) | Medium | High | 2-3 weeks |
| Phase 2 (Cloud) | High | Very High | 4-6 weeks |
| Phase 3 (Automation) | Medium | High | 2-3 weeks |
| Phase 4 (Collaboration) | High | Medium | 4-5 weeks |
| Phase 5 (Integration) | Medium | Medium | 3-4 weeks |
| Phase 6 (Analytics) | High | Medium | 4-5 weeks |

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| ✅ Done | Implemented and released |
| 🔄 In Progress | Currently being developed |
| ⏳ Planned | Scheduled for development |
| 💡 Idea | Under consideration |
| ❌ Cancelled | Not pursuing |

---

## Contributing

Feature requests and feedback welcome via [GitHub Issues](https://github.com/johnfkoo951/CmdTrace/issues).
