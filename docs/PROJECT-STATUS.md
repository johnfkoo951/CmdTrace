# CmdTrace 기술 현황 보고서

| 항목 | 내용 |
|------|------|
| 문서 유형 | 기술 현황 보고서 (Technical Status Report) |
| 작성일 | 2026-03-15 |
| 버전 | v2.4.2 (Build 40) |
| 작성자 | CmdTrace 개발팀 |

---

## 1. 프로젝트 개요

**CmdTrace**는 CLI 기반 AI 코딩 어시스턴트(Claude Code, OpenCode, Antigravity)의 대화 기록을 조회·관리하는 macOS 네이티브 애플리케이션이다. JSONL 형식의 세션 로그를 파싱하여, 세션 탐색·태그 관리·사용량 모니터링·AI 요약 등의 기능을 제공한다.

| 항목 | 내용 |
|------|------|
| 플랫폼 | macOS 14.0+ (Sonoma) |
| 언어 | Swift 5.9+ |
| UI 프레임워크 | SwiftUI |
| 차트 | Swift Charts |
| 상태 관리 | Swift Observation (`@Observable`) |
| 패키지 관리 | Swift Package Manager |
| 데이터 저장소 | JSON 파일 (`~/Library/Application Support/CmdTrace/`) |
| 개발 기간 | 2026-01-13 ~ 현재 (약 2개월) |
| 총 커밋 수 | 51 |
| 소스 파일 | 44개 (.swift) |
| 총 코드 라인 | ~14,800 lines |

---

## 2. 시스템 아키텍처

### 2.1 디렉토리 구조

| 레이어 | 파일 수 | 주요 컴포넌트 |
|--------|---------|---------------|
| App | 6 | AppState, PersistenceManager, SessionFilter, TagManager, ProjectManager |
| Models | 6 | Session, Message, UsageData, ClaudeConfig, ProjectMetadata, SessionInsights |
| Services | 7 | SessionService, SummaryService, CloudSyncService, LocalServer, APIRouter, ClaudeConfigService, TerminalService |
| Views | 23 | ContentView, SidebarView, DetailView 등 전체 UI 컴포넌트 |

### 2.2 주요 파일 규모 (500+ lines)

| 파일 | Lines | 담당 영역 |
|------|------:|-----------|
| ConfigurationView.swift | 978 | CLI 설정, API 키, 환경 구성 |
| SettingsView.swift | 909 | 앱 설정 전체 UI |
| AppState.swift | 880 | 글로벌 상태, 디바운싱, 배치 처리 |
| NativeMonitorView.swift | 783 | 실시간 사용량 모니터링 + 차트 |
| ProjectsView.swift | 778 | 프로젝트 대시보드 |
| UsageViews.swift | 712 | ccusage 데이터 시각화 |
| SessionListViews.swift | 730 | 세션 목록, 컨텍스트 메뉴, 벌크 작업 |
| InspectorPanelView.swift | 654 | 세션 인스펙터 패널 |
| TagBrowserView.swift | 601 | 태그 탐색 및 관리 |

### 2.3 데이터 흐름

| 경로 | 설명 |
|------|------|
| `~/.claude/projects/*/sessions/*.jsonl` | Claude Code 세션 로그 (읽기 전용) |
| `~/.opencode/sessions/*.jsonl` | OpenCode 세션 로그 (읽기 전용) |
| `~/Library/Application Support/CmdTrace/settings.json` | 앱 설정 |
| `~/Library/Application Support/CmdTrace/session-metadata.json` | 즐겨찾기, 핀, 태그 등 사용자 메타데이터 |
| `~/Library/Application Support/CmdTrace/tag-database.json` | 태그 정의 (색상, 중요도, 계층) |
| `~/Library/Application Support/CmdTrace/summaries.json` | AI 생성 요약 |
| `~/Library/Application Support/CmdTrace/project-metadata.json` | 프로젝트 메타데이터 |

---

## 3. 릴리즈 히스토리

### 3.1 v2.4.2 (2026-03-15) — Performance Optimization

검색, 저장, 파싱, UI 렌더링 전반에 걸친 성능 최적화 및 배치 AI Summary 기능 추가.

| 개선 항목 | 변경 내용 | 기대 효과 |
|-----------|-----------|-----------|
| Search Debounce | 300ms 딜레이로 타이핑 중 불필요한 필터링 제거 | CPU 부하 감소 |
| Save Debounce | 500ms 딜레이 + 앱 비활성화 시 즉시 저장 (scenePhase) | I/O 횟수 감소 |
| Background I/O | PersistenceManager를 `DispatchQueue.global(qos: .utility)` + `.atomic` write로 전환 | UI 블로킹 제거 |
| JSONL Parsing | `components(separatedBy:)` → `enumerateSubstrings(.byLines)` | 메모리 효율 향상 |
| Bulk Operations | 개별 save → 일괄 save (bulkAddTag, bulkRemoveTag, bulkToggleFavorite) | I/O 90%+ 감소 |
| Markdown Caching | MarkdownText 파싱 결과를 `@State`로 캐싱, `.task(id:)`로 갱신 | 렌더링 최적화 |
| StatsBar Caching | 총 메시지 수를 `onChange`로 갱신 | 매 프레임 reduce 제거 |
| Monitor Backpressure | `isLoadingData` guard로 데이터 로드 중복 실행 방지 | 리소스 낭비 방지 |
| AI Summary 컨텍스트 메뉴 | 세션 우클릭 → 개별 AI Summary 실행 | 단건 요약 편의성 |
| Batch AI Summary | 멀티 셀렉트 후 순차 처리 + 프로그레스바 | 대량 요약 지원 |
| Bulk Pin | BulkActionBar에 핀 토글 버튼 추가 | 일괄 핀 관리 |

### 3.2 v2.4.1 (2026-02-01) — Architecture Refactor

| 항목 | 설명 |
|------|------|
| 내장 HTTP 서버 | LocalServer.swift 기반 webapp 대시보드 (Phase A) |
| 태그 이름 변경 | 전 세션 일괄 업데이트 |
| 태그 검색 바 | Tags 뷰 전용 검색 UI |
| CLI 셀렉터 | 안정적 토글 순서 유지 |

### 3.3 v2.4.0 (2026-01-21) — Bulk Operations & Archive

| 항목 | 설명 |
|------|------|
| DetailView 리팩토링 | 3,700줄 → 10+ 모듈 파일로 분리 |
| 세션 아카이브 | 아카이브/복원, 자동 아카이브 |
| 벌크 작업 | 멀티 셀렉트, 일괄 태그/아카이브/즐겨찾기 |
| 검색 하이라이팅 | AttributedString 기반 |
| Cloud Sync UI | iCloud 동기화 설정 화면 (백엔드 미구현) |

### 3.4 이전 릴리즈 요약

| 버전 | 날짜 | 주요 내용 |
|------|------|-----------|
| v2.3.0 | 2026-01-16 | 검색 연산자, 세션 내보내기, Diff, 통계 대시보드 |
| v2.2.0 | 2026-01-16 | Configuration 탭, Session Insights |
| v2.1.0 | 2026-01-14 | 멀티 API 호환, 첫 공개 릴리즈 |
| v2.0.0-alpha | 2026-01-13 | 초기 빌드, JSONL 파싱, Claude Code/OpenCode 지원 |

---

## 4. 기능 현황

### 4.1 Core 기능

| 기능 | 상태 | 도입 버전 |
|------|:----:|:---------:|
| JSONL 세션 파싱 (Claude Code, OpenCode, Antigravity) | 완료 | v2.0 |
| 세션 목록·검색·필터 | 완료 | v2.0 |
| Markdown 렌더링 (코드블록, 테이블, 콜아웃) | 완료 | v2.0 |
| 검색 연산자 (title, tag, project, content, date, regex) | 완료 | v2.3 |
| 세션 내보내기 (Markdown, JSON, Plain Text, HTML) | 완료 | v2.3 |
| 세션 비교 (Side-by-side Diff) | 완료 | v2.3 |
| Deep Links (`cmdtrace://session/{id}`) | 완료 | v2.1 |

### 4.2 세션 관리

| 기능 | 상태 | 도입 버전 |
|------|:----:|:---------:|
| 즐겨찾기·핀·커스텀 이름 | 완료 | v2.0 |
| 태그 시스템 (중첩, 색상, 중요도) | 완료 | v2.0 |
| 태그 이름 변경 + 벌크 업데이트 | 완료 | v2.4.1 |
| 세션 아카이브·복원 | 완료 | v2.4 |
| 멀티 셀렉트 벌크 작업 | 완료 | v2.4 |
| 우클릭 컨텍스트 메뉴 (Favorite, Pin, AI Summary, Resume) | 완료 | v2.4.2 |
| 배치 AI Summary (순차 처리 + 진행률) | 완료 | v2.4.2 |
| 프로젝트 관리 | 완료 | v2.3 |

### 4.3 모니터링 및 분석

| 기능 | 상태 | 도입 버전 |
|------|:----:|:---------:|
| ccusage 연동 (Daily, Monthly, Blocks) | 완료 | v2.1 |
| Native Monitor (실시간 사용량) | 완료 | v2.1 |
| Burn Rate Chart (Swift Charts) | 완료 | v2.1 |
| Session Insights (토큰·도구·모델 분석) | 완료 | v2.2 |
| 통계 대시보드 (30일 활동, 분포) | 완료 | v2.3 |

### 4.4 외부 연동

| 기능 | 상태 | 도입 버전 |
|------|:----:|:---------:|
| AI 요약 (OpenAI, Anthropic, Gemini, Grok) | 완료 | v2.1 |
| 내장 HTTP 서버 (webapp 대시보드) | 완료 | v2.4.1 |
| Cloud Sync | UI만 구현 | v2.4 |

---

## 5. 향후 계획 (v2.5.0+)

| 기능 | 우선순위 | 설명 |
|------|:--------:|------|
| Cloud Sync Backend | High | CloudKit 컨테이너 구성, 실제 데이터 동기화 |
| Menu Bar App | High | 메뉴바 위젯을 통한 빠른 접근 |
| Global Hotkey | High | 시스템 전역 단축키로 앱 호출 |
| Session Merge | Medium | 관련 세션 병합 기능 |
| Full-text Index | Medium | SQLite FTS를 활용한 빠른 컨텐츠 검색 |
| Timeline View | Low | 시각적 세션 타임라인 |
| Widgets | Low | macOS 위젯 지원 |
| Shortcuts Integration | Low | Siri Shortcuts 연동 |

---

## 6. 알려진 이슈 및 기술 부채

### 6.1 알려진 이슈

| 이슈 | 상태 | 대응 방안 |
|------|:----:|-----------|
| Cloud Sync 백엔드 미구현 | Open | UI 준비 완료, v2.5.0에서 CloudKit 구현 예정 |
| 1000+ 메시지 세션 로딩 지연 | Open | Pagination 도입 계획 |

### 6.2 기술 부채

| 항목 | 심각도 | 현황 |
|------|:------:|------|
| ConfigurationView.swift (978줄) | Medium | 기능별 분리 검토 필요 |
| SettingsView.swift (909줄) | Medium | 탭별 하위 뷰 분리 가능 |
| ~~DetailView.swift (3,700줄)~~ | ~~High~~ | v2.4.0에서 10+ 파일로 분리 완료 |
| ~~Session loading 최적화~~ | ~~Medium~~ | v2.4.2에서 JSONL 스트리밍 파싱 도입 완료 |

---

## 7. 빌드 및 배포

| 명령 | 설명 |
|------|------|
| `swift build` | 디버그 빌드 |
| `./build-app.sh` | 릴리즈 앱 번들 생성 |
| `./build-dmg.sh` | DMG 인스톨러 생성 |
| `cp -r ./build/CmdTrace.app /Applications/` | 로컬 배포 |
| GitHub Release | `gh release create vX.X.X-buildN ./build/*.dmg` |

---

*문서 끝*
