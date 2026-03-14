# CmdTrace Project Status

> Last Updated: 2026-03-14 | Current Version: v2.4.2 (Build 38)

## Overview

| 항목 | 내용 |
|------|------|
| 프로젝트 | CmdTrace - macOS AI CLI 세션 뷰어 |
| 개발 기간 | 2026-01-13 ~ 현재 (약 2개월) |
| Tech Stack | Swift 5.9+ / SwiftUI / macOS 14+ |
| 총 커밋 | 49 |
| 소스 파일 | 44개 (.swift) |
| 총 코드 | ~14,600 lines |

---

## Architecture

```
Sources/
├── App/          6 files   - AppState, Persistence, SessionFilter, TagManager
├── Models/       6 files   - Session, Message, UsageData, ProjectMetadata
├── Services/     7 files   - SessionService, SummaryService, CloudSync, LocalServer
└── Views/       23 files   - 전체 UI 컴포넌트
```

### 주요 파일 (500+ lines)

| 파일 | Lines | 역할 |
|------|-------|------|
| ConfigurationView.swift | 978 | CLI 설정, API 키, 환경 구성 |
| SettingsView.swift | 909 | 앱 설정 UI |
| AppState.swift | 835 | 글로벌 상태 관리 (@Observable) |
| NativeMonitorView.swift | 783 | 실시간 사용량 모니터링 |
| ProjectsView.swift | 778 | 프로젝트 관리 뷰 |
| UsageViews.swift | 712 | ccusage 데이터 표시 |
| SessionListViews.swift | 687 | 세션 목록, 필터, 벌크 작업 |
| InspectorPanelView.swift | 654 | 우측 인스펙터 패널 |
| TagBrowserView.swift | 601 | 태그 탐색/관리 |

---

## Version History

### v2.4.2 (2026-03-14) - Performance Optimization

검색, 저장, 파싱, UI 렌더링 전반의 성능 최적화.

| 개선 항목 | 변경 내용 | 효과 |
|-----------|-----------|------|
| Search Debounce | 300ms 딜레이로 타이핑 중 불필요한 필터링 제거 | CPU 부하 감소 |
| Save Debounce | 500ms 딜레이 + 앱 비활성화 시 즉시 저장 | I/O 횟수 감소 |
| Background I/O | PersistenceManager를 백그라운드 큐 + atomic write로 전환 | UI 블로킹 제거 |
| JSONL Parsing | `components(separatedBy:)` → `enumerateSubstrings` | 메모리 효율 향상 |
| Bulk Operations | 개별 save → 일괄 save (bulkAddTag, bulkRemoveTag, bulkToggleFavorite) | I/O 90%+ 감소 |
| Markdown Caching | MarkdownText 파싱 결과 캐싱, content 변경 시만 재파싱 | 렌더링 최적화 |
| StatsBar Caching | 메시지 수 합계를 onChange로 갱신 | 매 프레임 reduce 제거 |
| Monitor Backpressure | 데이터 로드 중복 실행 방지 guard 추가 | 리소스 낭비 방지 |

### v2.4.1 (2026-02-01) - Architecture Refactor

- 내장 HTTP 서버로 webapp 대시보드 지원 (Phase A)
- 태그 검색 바 개선
- 태그 이름 변경 + 벌크 업데이트

### v2.4.0 (2026-01-21) - Bulk Operations & Archive

- DetailView.swift 모듈 분리 (3700줄 → 10+ 파일)
- 세션 아카이브/복원
- 멀티 셀렉트 벌크 작업 (태그, 아카이브, 즐겨찾기)
- AttributedString 기반 검색 하이라이팅
- Cloud Sync UI (백엔드 미구현)
- CLI 셀렉터/태그 팝오버 UI 개선

### v2.3.0 (2026-01-16) - Search & Export

- 검색 연산자 (`date:`, `regex:`, `messages:`)
- 세션 내보내기 (Markdown, JSON, Plain Text, HTML)
- 세션 비교 (Side-by-side diff)
- 통계 대시보드 (30일 활동, 프로젝트/태그 분포)
- Inspector 패널 재구성

### v2.2.0 (2026-01-16) - Configuration & Insights

- Configuration 탭 추가
- Session Insights (토큰/도구/모델 사용량 분석)

### v2.1.0 (2026-01-14) - Public Release

- 멀티 API 호환 (OpenAI, Anthropic, Gemini, Grok)
- 안정화 및 첫 공개 릴리즈

### v2.0.0-alpha (2026-01-13) - Initial Build

- 기본 세션 뷰어, JSONL 파싱
- Claude Code / OpenCode 지원

---

## Feature Map

### Core

| Feature | Status | Version |
|---------|--------|---------|
| JSONL 세션 파싱 (Claude Code, OpenCode, Antigravity) | ✅ | v2.0 |
| 세션 목록/검색/필터 | ✅ | v2.0 |
| Markdown 렌더링 (코드블록, 테이블, 콜아웃) | ✅ | v2.0 |
| 검색 연산자 (title, tag, project, content, date, regex) | ✅ | v2.3 |
| 세션 내보내기 (MD, JSON, TXT, HTML) | ✅ | v2.3 |
| 세션 비교 (Diff) | ✅ | v2.3 |
| Deep Links (`cmdtrace://session/{id}`) | ✅ | v2.1 |

### Organization

| Feature | Status | Version |
|---------|--------|---------|
| 즐겨찾기, 핀, 커스텀 이름 | ✅ | v2.0 |
| 태그 시스템 (중첩, 색상, 중요도) | ✅ | v2.0 |
| 태그 이름 변경 + 벌크 업데이트 | ✅ | v2.4.1 |
| 세션 아카이브/복원 | ✅ | v2.4 |
| 벌크 작업 (멀티 셀렉트) | ✅ | v2.4 |
| 프로젝트 관리 | ✅ | v2.3 |

### Monitoring & Analytics

| Feature | Status | Version |
|---------|--------|---------|
| ccusage 연동 (Daily, Monthly, Blocks) | ✅ | v2.1 |
| Native Monitor (실시간 사용량) | ✅ | v2.1 |
| Burn Rate Chart (Swift Charts) | ✅ | v2.1 |
| Session Insights (토큰/도구/모델) | ✅ | v2.2 |
| 통계 대시보드 | ✅ | v2.3 |

### Integration

| Feature | Status | Version |
|---------|--------|---------|
| AI 요약 (OpenAI, Anthropic, Gemini, Grok) | ✅ | v2.1 |
| 내장 HTTP 서버 (webapp 대시보드) | ✅ | v2.4.1 |
| Cloud Sync | ⚠️ UI Only | v2.4 |

---

## Planned (v2.5.0+)

| Feature | Priority | 비고 |
|---------|----------|------|
| Cloud Sync Backend | High | CloudKit 컨테이너 설정, 실제 동기화 |
| Menu Bar App | High | 메뉴바 위젯으로 빠른 접근 |
| Global Hotkey | High | 시스템 전역 단축키 |
| Session Merge | Medium | 여러 세션 병합 |
| Full-text Index | Medium | SQLite FTS로 빠른 컨텐츠 검색 |
| Timeline View | Low | 세션 타임라인 시각화 |
| Widgets | Low | macOS 위젯 |
| Shortcuts Integration | Low | Siri Shortcuts 지원 |

---

## Known Issues

| Issue | 상태 | 대응 |
|-------|------|------|
| Cloud Sync 백엔드 미구현 | Open | UI 준비됨, v2.5.0 예정 |
| 1000+ 메시지 세션 로딩 느림 | Open | Pagination 계획 |

---

## Tech Debt

| 항목 | 심각도 | 비고 |
|------|--------|------|
| ConfigurationView.swift (978줄) | Medium | 분리 검토 필요 |
| SettingsView.swift (909줄) | Medium | 탭별 분리 가능 |
| Session loading 최적화 | Low | v2.4.2에서 파싱 개선 완료, 추가 최적화 여지 |
