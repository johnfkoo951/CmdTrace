# Independent Multiplatform CmdTrace - 1:1 Clone

## Context

### Original Request
사용자가 CmdTrace의 Swift 앱, Webapp, Tauri 앱 3개 버전을 **모두 독립적으로** 동작하도록 구성 요청. Webapp이 Swift 앱의 LocalServer에 의존하는 현재 구조는 폐기. Webapp과 Tauri 모두 Swift 앱의 **1:1 기능 클론**으로 구현.

### Interview Summary
**Key Discussions**:
- Webapp 백엔드: **Bun + Hono** (경량 로컬 서버로 JSONL 파일 직접 읽기)
- 코드 구조: **Monorepo** (packages/shared-ui에 공통 React 컴포넌트, 각 앱은 데이터 레이어만 다름)
- 네이티브 기능: **가능한 것만 구현** (터미널 resume 등 OS 전용은 "앱에서만 가능" 표시)
- Swift 성능: **별도 계획으로 분리** (이 계획에 포함 안 함)

**Research Findings**:
- Swift 앱: v2.4.1, ~40개 소스 파일, 완전한 기능셋
- Webapp (cmdtrace-web): 1,332 LOC, React 19 + Vite + Tailwind + Zustand + Recharts
- Tauri (cmdtrace-tauri): 793 LOC, Rust backend + React frontend
- 실제 Claude 세션 경로: `~/.claude/projects/{slug}/*.jsonl` (**NO `/sessions/` subdirectory!**)
- 실제 OpenCode 세션 경로: `~/.local/share/opencode/storage/message/` + `storage/part/`
- `agent-*.jsonl` 파일은 `{session-uuid}/subagents/` 하위에 있음 (프로젝트 루트에 없음)

### Metis Review
**Identified Gaps** (addressed):
- Glob 패턴 불일치: CLAUDE.md에 `*/sessions/*.jsonl`이라 적혀있으나 **실제로는 `*/*.jsonl`** → 검증 완료, 계획에 반영
- OpenCode 경로 오류: Tauri에 `~/.opencode/sessions/`로 구현됨 → 실제 `~/.local/share/opencode/storage/message/` → 수정 포함
- 메타데이터 동시 쓰기 문제: 3개 앱이 같은 metadata 파일에 쓰면 데이터 손상 위험 → 각 앱별 별도 저장 경로 사용, 향후 sync 고려
- 1:1 클론 범위가 매우 큼 → Phase로 나눠서 진행하되 ONE PLAN으로 관리

---

## Work Objectives

### Core Objective
CmdTrace의 Swift 앱과 동일한 기능을 가진 **독립적인** Webapp(Bun+Hono)과 Tauri 앱을 Monorepo 구조로 구현한다.

### Concrete Deliverables
- Monorepo: `/Users/yohankoo/DEV/cmdtrace-multiplatform/`
  - `packages/shared-ui/` — 공통 React 컴포넌트 + 타입 + 유틸
  - `packages/shared-parser/` — JSONL/JSON 파서 (TypeScript, 웹+Tauri 공용)
  - `apps/web/` — Bun + Hono 백엔드 + React 프론트엔드
  - `apps/tauri/` — Tauri v2 Rust 백엔드 + React 프론트엔드
- Swift 앱의 기존 LocalServer/APIRouter는 유지 (삭제하지 않음)

### Definition of Done
- [ ] `apps/web/`: `bun run dev` 실행 → 브라우저에서 전체 기능 동작 (Swift 앱 없이)
- [ ] `apps/tauri/`: `pnpm tauri dev` 실행 → 네이티브 앱에서 전체 기능 동작
- [ ] 두 앱 모두 `~/.claude/projects/` 세션을 올바르게 로드
- [ ] 검색 연산자 (title:, content:, tag:, project:, date:, regex:, messages:) 모두 동작
- [ ] 태그 시스템 (생성, 수정, 삭제, 중첩, 색상) 동작
- [ ] 세션 관리 (즐겨찾기, 고정, 아카이브, 벌크 작업) 동작

### Must Have
- 독립 실행 (Swift 앱 의존성 없음)
- Swift 앱과 동일한 JSONL 파싱 결과
- 동일한 검색 연산자 지원
- 동일한 UI/UX (가능한 범위 내)

### Must NOT Have (Guardrails)
- Swift 앱 코드 수정 (이 계획에서 제외)
- 기존 cmdtrace-web, cmdtrace-tauri 프로젝트 수정 (새 monorepo로 마이그레이션)
- 새로운 기능 추가 (Swift에 없는 기능)
- iCloud 동기화 구현 (별도 계획)
- 과도한 추상화나 불필요한 유틸리티 생성

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: NO (신규 monorepo)
- **User wants tests**: Manual verification 위주
- **Framework**: 없음 (추후 추가 가능)

### Manual QA Approach
각 TODO는 playwright 브라우저 또는 터미널 검증 포함:
- Webapp: `http://localhost:3000` 에서 기능 확인
- Tauri: `pnpm tauri dev`로 네이티브 앱 확인
- 세션 데이터 정합성: Swift 앱과 동일한 세션 목록/내용 표시 확인

---

## Task Flow

```
Phase 1: Monorepo Foundation
  TODO 1 (monorepo setup) → TODO 2 (shared types) → TODO 3 (shared parser)

Phase 2: Data Layer
  TODO 4 (Bun+Hono backend) ─┐
  TODO 5 (Tauri Rust parser) ─┤→ TODO 6 (verify both parsers)
                               
Phase 3: Shared UI Components
  TODO 7 (design system) → TODO 8 (layout) → TODO 9 (session list) → TODO 10 (message view)

Phase 4: Core Features - Sessions
  TODO 11 (sidebar + search) → TODO 12 (session detail) → TODO 13 (search operators)

Phase 5: Core Features - Management
  TODO 14 (metadata persistence) → TODO 15 (tag system) → TODO 16 (session management)

Phase 6: Dashboard & Analytics  
  TODO 17 (dashboard) → TODO 18 (usage monitoring) → TODO 19 (native monitor)

Phase 7: Advanced Features
  TODO 20 (export) → TODO 21 (session diff) → TODO 22 (session insights)
  TODO 23 (projects view) → TODO 24 (config browser)

Phase 8: AI & Integration
  TODO 25 (AI summaries) → TODO 26 (settings) → TODO 27 (keyboard shortcuts + deep links)

Phase 9: Polish & Wiring
  TODO 28 (Tauri integration) → TODO 29 (Web integration) → TODO 30 (final QA)
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 4, 5 | Backend implementations are independent |
| B | 20, 21, 22, 23, 24 | Advanced features are independent |
| C | 28, 29 | Platform integrations are independent |

| Task | Depends On | Reason |
|------|------------|--------|
| 2 | 1 | Types need monorepo structure |
| 3 | 2 | Parser uses shared types |
| 4, 5 | 3 | Backends use shared parser |
| 7-10 | 1 | UI components need monorepo |
| 11-13 | 9, 10 | Features need base UI |
| 14-16 | 2 | Management needs types |
| 17-19 | 7, 14 | Dashboard needs design system + data |
| 25 | 12, 14 | AI needs session detail + metadata |
| 28, 29 | All prior | Integration wires everything |
| 30 | 28, 29 | Final QA after integration |

---

## TODOs

### Phase 1: Monorepo Foundation

- [x] 1. Monorepo 프로젝트 구조 생성

  **What to do**:
  - `/Users/yohankoo/DEV/cmdtrace-multiplatform/` 생성
  - pnpm workspace 설정 (`pnpm-workspace.yaml`)
  - Root `package.json` with workspace config
  - `packages/shared-ui/` - React 컴포넌트 패키지 (Vite library mode)
  - `packages/shared-parser/` - TypeScript JSONL 파서 패키지
  - `apps/web/` - Bun + Hono + Vite + React
  - `apps/tauri/` - Tauri v2 + Vite + React
  - Root `tsconfig.json` with project references
  - `.gitignore` 설정
  - 기존 `cmdtrace-web/` (1,332 LOC)과 `cmdtrace-tauri/` (793 LOC) 코드를 참고하되 새로 구성

  **Must NOT do**:
  - 기존 cmdtrace-web, cmdtrace-tauri 디렉토리 수정/삭제
  - 불필요한 config 파일 추가

  **Parallelizable**: NO (첫 번째 작업)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/cmdtrace-web/package.json` - 기존 웹앱 의존성 참고
  - `/Users/yohankoo/DEV/cmdtrace-tauri/package.json` - 기존 Tauri 의존성 참고
  - `/Users/yohankoo/DEV/cmdtrace-tauri/src-tauri/Cargo.toml` - Rust 의존성 참고

  **Acceptance Criteria**:
  - [ ] `pnpm install` 성공 (monorepo root에서)
  - [ ] `packages/shared-ui/` TypeScript 컴파일 성공
  - [ ] `packages/shared-parser/` TypeScript 컴파일 성공
  - [ ] `apps/web/` dev server 시작 성공
  - [ ] `apps/tauri/` frontend dev server 시작 성공

  **Commit**: YES
  - Message: `feat: initialize cmdtrace-multiplatform monorepo structure`
  - Files: 전체 monorepo

---

- [x] 2. Shared TypeScript 타입 정의

  **What to do**:
  - `packages/shared-parser/src/types.ts` — 모든 데이터 모델 타입
  - Session, Message, ToolUse, SessionMetadata, TagInfo, UsageData, SessionInsights, ProjectMetadata, ClaudeConfiguration 등 Swift 모델과 1:1 매칭
  - CLITool, AppTab, SidebarViewMode, AppTheme, AIProvider, TagSortMode, UsageViewMode 등 enum 타입
  - AppSettings 타입 (모든 설정 필드)

  **Must NOT do**:
  - Swift에 없는 타입 추가
  - 과도한 generic/utility 타입

  **Parallelizable**: NO (depends on 1)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Models/Session.swift` - Session 모델 (computed properties 포함)
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Models/Message.swift` - Message, ToolUse 모델
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Models/UsageData.swift` - UsageData 모델
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Models/SessionInsights.swift` - SessionInsights 모델
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Models/ProjectMetadata.swift` - ProjectMetadata 모델
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Models/ClaudeConfig.swift` - ClaudeConfiguration 모델
  - `/Users/yohankoo/DEV/CmdTrace/Sources/App/AppState.swift` - AppSettings, SessionMetadata, TagInfo

  **Acceptance Criteria**:
  - [ ] `tsc --noEmit` 성공 (packages/shared-parser/)
  - [ ] Swift의 Session, Message, ToolUse, SessionMetadata, TagInfo 타입이 모두 TypeScript로 변환됨
  - [ ] 모든 enum이 TypeScript union type 또는 const enum으로 정의됨
  - [ ] computed properties (displayTitle, projectName, relativeTime, duration 등)가 utility 함수로 구현됨

  **Commit**: YES
  - Message: `feat: add shared TypeScript type definitions matching Swift models`
  - Files: `packages/shared-parser/src/types.ts`

---

- [x] 3. Shared JSONL/JSON Parser

  **What to do**:
  - `packages/shared-parser/src/claude-parser.ts` — Claude Code JSONL 파서
    - `discoverClaudeSessions(basePath)`: `~/.claude/projects/*/` 탐색
    - `parseClaudeSessionHeader(filePath)`: JSONL 첫 패스 (메타데이터만)
    - `parseClaudeMessages(filePath)`: JSONL 전체 파싱 (메시지)
    - `agent-*.jsonl` 파일 필터링
    - 프로젝트 이름 추출 (slug → human readable)
    - summary type 라인에서 세션 제목 추출
    - timestamp 파싱 (ISO 8601)
  - `packages/shared-parser/src/opencode-parser.ts` — OpenCode JSON 파서
    - `discoverOpenCodeSessions(basePath)`: `~/.local/share/opencode/storage/message/` 탐색
    - `parseOpenCodeSession(sessionDir)`: session.json + messages 파싱
  - `packages/shared-parser/src/index.ts` — 통합 export

  **Must NOT do**:
  - 파일시스템 직접 접근 (fs import). 대신 인터페이스로 추상화하여 Node.js fs와 Tauri fs API 모두 대응
  - 스트리밍이 아닌 전체 파일 로드 (큰 세션 파일 처리용 스트리밍은 추후)

  **Parallelizable**: NO (depends on 2)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Services/SessionService.swift` - **핵심 참조**: Swift 파서의 정확한 로직을 TS로 포팅
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Services/SessionService.swift:30-67` - `loadClaudeSessions()`: glob 패턴, agent-* 필터링, messageCount > 0 필터
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Services/SessionService.swift:71-150` - `parseClaudeSession()`: JSONL 라인별 파싱, type별 처리
  - `/Users/yohankoo/DEV/cmdtrace-tauri/src-tauri/src/services/jsonl_parser.rs` - 기존 Rust 파서 (버그 있음, 참고만)

  **실제 데이터 참조**:
  - Claude 세션 경로: `~/.claude/projects/{slug}/*.jsonl` (NO `/sessions/` subdirectory!)
  - 프로젝트 slug 예: `-Users-yohankoo-DEV-CmdTrace`, `-Users-yohankoo-Local-Obsidian-MBP-CMDSPACE-Local-MBP`
  - Subagent 파일 위치: `~/.claude/projects/{slug}/{uuid}/subagents/agent-*.jsonl`
  - OpenCode 경로: `~/.local/share/opencode/storage/message/`, `~/.local/share/opencode/storage/part/`

  **JSONL 라인 타입들**:
  ```json
  {"type":"summary","summary":"세션 제목","leafUuid":"..."}
  {"type":"user","message":{"role":"user","content":"..."},"uuid":"...","timestamp":"2026-01-13T09:28:09.835Z"}
  {"type":"assistant","message":{"model":"claude-opus-4-5-20251101","role":"assistant","content":[...]},"timestamp":"..."}
  {"type":"system","subtype":"stop_hook_summary",...}
  {"type":"file-history-snapshot",...}
  ```

  **Acceptance Criteria**:
  - [ ] `tsc --noEmit` 성공
  - [ ] `discoverClaudeSessions()` 호출 시 실제 세션 파일 목록 반환 (Swift 앱과 동일 수)
  - [ ] `parseClaudeSessionHeader()` 결과: sessionId, title, preview, messageCount, lastActivity, firstTimestamp, project 모두 올바름
  - [ ] `agent-*.jsonl` 파일이 결과에 포함되지 않음
  - [ ] 프로젝트명 추출: `-Users-yohankoo-DEV-CmdTrace` → `CmdTrace` (Swift와 동일)

  **Commit**: YES
  - Message: `feat: implement shared JSONL/JSON parsers for Claude Code and OpenCode`
  - Files: `packages/shared-parser/src/`

---

### Phase 2: Data Layer (Backends)

- [x] 4. Webapp Backend (Bun + Hono)

  **What to do**:
  - `apps/web/server/` — Bun + Hono HTTP 서버
  - `server/index.ts` — 서버 엔트리 (포트 3001)
  - `server/routes/sessions.ts` — GET /api/sessions, GET /api/sessions/:id, GET /api/sessions/:id/messages
  - `server/routes/search.ts` — GET /api/search?q=...
  - `server/routes/tags.ts` — GET/POST/PUT/DELETE /api/tags
  - `server/routes/metadata.ts` — GET/PUT /api/sessions/:id/metadata (favorites, pins, names)
  - `server/routes/usage.ts` — GET /api/usage/daily, GET /api/usage/monthly, GET /api/usage/blocks
  - `server/routes/stats.ts` — GET /api/stats (대시보드 통계)
  - `server/routes/config.ts` — GET /api/config (Claude configuration)
  - `server/routes/health.ts` — GET /api/health
  - shared-parser 사용하여 JSONL 파싱
  - 메타데이터 저장: `~/Library/Application Support/CmdTrace-Web/` (Swift와 별도 경로)
  - ccusage CLI 실행: `child_process.exec('ccusage blocks --active --json --breakdown')`

  **Must NOT do**:
  - Swift 앱의 LocalServer와 동일 포트 사용 (19840)
  - 세션 파일 수정 (read-only)
  - 인증 추가 (localhost 전용)

  **Parallelizable**: YES (with 5)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Services/APIRouter.swift` - Swift API 라우팅 패턴 참고 (동일한 엔드포인트 구조)
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Services/LocalServer.swift` - HTTP 서버 구조 참고
  - `/Users/yohankoo/DEV/cmdtrace-web/src/store/index.ts` - 기존 웹앱 API 호출 패턴

  **Data References**:
  - 메타데이터 파일: `~/Library/Application Support/CmdTrace/session-metadata.json` (Swift 형식 참고, 별도 경로에 저장)
  - 태그 DB: `~/Library/Application Support/CmdTrace/tag-database.json` (Swift 형식 참고)
  - 서머리: `~/Library/Application Support/CmdTrace/summaries.json` (Swift 형식 참고)

  **Acceptance Criteria**:
  - [ ] `bun run server/index.ts` 실행 → 포트 3001 리슨
  - [ ] `curl http://localhost:3001/api/health` → `{"status":"ok","sessions":N}` (N > 0)
  - [ ] `curl http://localhost:3001/api/sessions` → JSON 배열, Swift 앱과 동일한 세션 수
  - [ ] `curl http://localhost:3001/api/sessions/{id}/messages` → 메시지 배열
  - [ ] `curl http://localhost:3001/api/search?q=content:authentication` → 필터링된 결과

  **Commit**: YES
  - Message: `feat: implement Bun+Hono backend with REST API for webapp`
  - Files: `apps/web/server/`

---

- [ ] 5. Tauri Rust Backend 수정

  **What to do**:
  - `apps/tauri/src-tauri/src/services/jsonl_parser.rs` — 완전 재작성
    - glob 패턴 수정: `~/.claude/projects/*/*.jsonl` (sessions/ 제거)
    - `agent-*.jsonl` 필터링 추가
    - 프로젝트명 추출 로직 수정 (Swift SessionService.swift 참고)
    - 메시지 파싱: type별 처리 (summary, user, assistant, system)
    - timestamp 파싱 수정
    - OpenCode 경로 수정: `~/.local/share/opencode/storage/message/`
  - `apps/tauri/src-tauri/src/commands/sessions.rs` — IPC 커맨드 수정
    - get_sessions: 올바른 세션 목록 반환
    - get_messages: 올바른 메시지 목록 반환
    - search_sessions: 검색 연산자 지원
  - `apps/tauri/src-tauri/src/commands/metadata.rs` — 새 파일
    - 메타데이터 CRUD (favorites, pins, custom names, tags)
    - 저장 경로: `~/Library/Application Support/CmdTrace-Tauri/`

  **Must NOT do**:
  - shared-parser TypeScript 코드를 Rust에서 직접 사용 (Tauri는 Rust 자체 파서 유지)
  - Swift 앱의 메타데이터 파일 직접 수정

  **Parallelizable**: YES (with 4)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Services/SessionService.swift:30-67` - **핵심**: Swift의 loadClaudeSessions() 로직을 Rust로 정확히 포팅
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Services/SessionService.swift:71-150` - parseClaudeSession() 라인별 파싱 로직
  - `/Users/yohankoo/DEV/cmdtrace-tauri/src-tauri/src/services/jsonl_parser.rs` - 기존 Rust 파서 (버그 참고)
  - `/Users/yohankoo/DEV/cmdtrace-tauri/src-tauri/src/commands/sessions.rs` - 기존 IPC 커맨드

  **Acceptance Criteria**:
  - [ ] `cargo build` 성공 (경고 최소화)
  - [ ] `pnpm tauri dev` → 앱 시작, 콘솔에 "Loaded N sessions" (N > 300, Swift와 유사)
  - [ ] 세션 목록에서 제목이 UUID가 아닌 실제 내용/summary로 표시
  - [ ] 메시지 수가 0이 아닌 실제 값 표시
  - [ ] 프로젝트명이 "MBP"가 아닌 실제 프로젝트명 표시

  **Commit**: YES
  - Message: `fix: rewrite Tauri JSONL parser to match Swift SessionService logic`
  - Files: `apps/tauri/src-tauri/src/`

---

- [ ] 6. 양쪽 파서 정합성 검증

  **What to do**:
  - Swift 앱에서 보이는 세션 목록과 webapp/tauri 세션 목록 비교
  - 세션 수, 프로젝트 수, 메시지 수 일치 확인
  - 특정 세션의 메시지 내용 비교 (3개 이상)
  - 엣지 케이스 확인: 빈 세션, 매우 큰 세션, 특수문자 포함 세션

  **Must NOT do**:
  - 자동화된 테스트 작성 (수동 비교)

  **Parallelizable**: NO (depends on 4, 5)

  **References**:
  - Swift 앱 실행하여 세션 목록 확인
  - `curl http://localhost:3001/api/sessions | jq length`
  - Tauri 앱 dev 모드에서 확인

  **Acceptance Criteria**:
  - [ ] Swift 앱 세션 수 ≈ Webapp 세션 수 ≈ Tauri 세션 수 (±5 이내)
  - [ ] 동일 세션의 messageCount가 3개 앱 모두 동일
  - [ ] 동일 세션의 프로젝트명이 3개 앱 모두 동일
  - [ ] 세션 타임스탬프 정렬 순서 동일

  **Commit**: NO

---

### Phase 3: Shared UI Components

- [ ] 7. Design System 기초

  **What to do**:
  - `packages/shared-ui/src/styles/` — Tailwind v4 기반 디자인 토큰
  - 색상 팔레트 (Swift 앱 색상과 매칭)
  - 타이포그래피 (SF Pro 또는 Inter)
  - 간격/radius/shadow 토큰
  - 다크모드 지원 (CSS variables)
  - `packages/shared-ui/src/components/` — 기본 UI 컴포넌트
    - Button, Badge, Input, Select, Toggle, Card, Modal, Sheet
    - StatCard (대시보드용)
    - ProgressBar (사용량 바)
    - ColorPicker
    - TagChip (색상 칩)

  **Must NOT do**:
  - 자체 디자인 시스템 라이브러리 빌드 (Tailwind 유틸리티 직접 사용)
  - shadcn/ui 등 외부 컴포넌트 라이브러리 (직접 구현)

  **Parallelizable**: NO (depends on 1, but parallel with 4/5)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/HelperViews.swift` - Swift 재사용 컴포넌트 참고
  - `/Users/yohankoo/DEV/cmdtrace-web/src/index.css` - 기존 웹앱 Tailwind 설정
  - `/Users/yohankoo/DEV/cmdtrace-web/src/pages/DashboardPage.tsx` - StatCard 패턴

  **Acceptance Criteria**:
  - [ ] 모든 기본 컴포넌트 Storybook 없이 직접 렌더링 확인
  - [ ] 다크모드 토글 시 모든 컴포넌트 정상 표시
  - [ ] `packages/shared-ui` 빌드 성공

  **Commit**: YES
  - Message: `feat: implement shared design system and base UI components`
  - Files: `packages/shared-ui/`

---

- [ ] 8. Layout 컴포넌트

  **What to do**:
  - `packages/shared-ui/src/components/Layout/` — 앱 레이아웃
    - AppShell: 사이드바 + 메인 + 인스펙터 3분할 레이아웃
    - Sidebar: 왼쪽 네비게이션 (Sessions, Projects, Dashboard, Config, AI 탭)
    - InspectorPanel: 오른쪽 정보 패널 (토글 가능)
    - Toolbar: 상단 툴바 (검색, 새로고침, CLI 선택)
    - CLIToolPicker: Claude Code / OpenCode / Antigravity 전환
    - TabBar: Sessions/Projects/Dashboard/Config/AI 탭 버튼

  **Must NOT do**:
  - NavigationSplitView의 모든 macOS 네이티브 동작 복제 (resize handle 등은 단순화)

  **Parallelizable**: NO (depends on 7)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/ContentView.swift` - Swift 레이아웃 구조 (NavigationSplitView)
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/SidebarView.swift` - 사이드바 탭 구조
  - `/Users/yohankoo/DEV/cmdtrace-web/src/components/Layout.tsx` - 기존 웹앱 레이아웃

  **Acceptance Criteria**:
  - [ ] 3분할 레이아웃 렌더링 (사이드바 너비 조절 가능)
  - [ ] 인스펙터 패널 토글 동작
  - [ ] CLI 선택기 동작 (3개 CLI 전환)
  - [ ] 탭 전환 동작

  **Commit**: YES
  - Message: `feat: implement app layout with sidebar, inspector, and navigation`
  - Files: `packages/shared-ui/src/components/Layout/`

---

- [ ] 9. Session List 컴포넌트

  **What to do**:
  - `packages/shared-ui/src/components/SessionList/`
    - SessionListView: 날짜 그룹별 세션 목록 (Today, Yesterday, Jan 12...)
    - SessionRow: 세션 행 (제목, 프리뷰, 메시지 수, 프로젝트, 시간, 즐겨찾기/고정 아이콘)
    - SessionContextMenu: 우클릭 메뉴 (이름변경, 태그, 즐겨찾기, 고정, 아카이브, 내보내기 등)
    - BulkActionBar: 멀티셀렉트 액션 바
    - DateGroupHeader: 날짜 그룹 헤더

  **Must NOT do**:
  - 가상 스크롤링 (첫 버전은 단순 목록, 성능 이슈 시 추후)

  **Parallelizable**: NO (depends on 8)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/SessionListViews.swift` - SessionRow 구조, 날짜 그룹핑
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/SidebarView.swift` - 세션 목록 컨테이너, 벌크 액션
  - `/Users/yohankoo/DEV/cmdtrace-web/src/pages/SessionsPage.tsx` - 기존 웹앱 세션 목록

  **Acceptance Criteria**:
  - [ ] 세션 목록 날짜 그룹별 렌더링
  - [ ] 즐겨찾기/고정 아이콘 표시
  - [ ] 우클릭 컨텍스트 메뉴 표시
  - [ ] 멀티셀렉트 모드 동작

  **Commit**: YES
  - Message: `feat: implement session list with grouping, context menu, and bulk actions`
  - Files: `packages/shared-ui/src/components/SessionList/`

---

- [ ] 10. Message View 컴포넌트

  **What to do**:
  - `packages/shared-ui/src/components/MessageView/`
    - ConversationView: 메시지 목록 스크롤 뷰
    - MessageBubble: 메시지 버블 (역할, 모델, 에이전트, 타임스탬프)
    - MarkdownRenderer: 마크다운 렌더링 (react-markdown + rehype-highlight)
      - 코드 블록 (구문 강조, 복사 버튼)
      - 테이블 (자동 너비)
      - 콜아웃 블록 (Obsidian 스타일)
      - 리스트, 인용, 링크
    - ToolUseDisplay: 툴 사용 표시 (접이식)
    - SessionHeader: 세션 헤더 (제목, 프로젝트, 메시지 수, 기간)

  **Must NOT do**:
  - 자체 마크다운 파서 구현 (react-markdown 사용)
  - 이미지 렌더링 (텍스트 전용)

  **Parallelizable**: YES (with 9, after 7)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/MessageBubbleView.swift` - 메시지 버블 구조
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/MarkdownTextView.swift` - 마크다운 렌더링 로직
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/SessionHeaderView.swift` - 세션 헤더
  - `/Users/yohankoo/DEV/cmdtrace-web/src/pages/SessionDetailPage.tsx` - 기존 메시지 뷰

  **Acceptance Criteria**:
  - [ ] User/Assistant 메시지 구분 렌더링
  - [ ] 코드 블록 구문 강조 동작
  - [ ] 툴 사용 접이식 표시
  - [ ] 모델명 (Opus/Sonnet/Haiku) 뱃지 표시

  **Commit**: YES
  - Message: `feat: implement message view with markdown rendering and tool display`
  - Files: `packages/shared-ui/src/components/MessageView/`

---

### Phase 4: Core Features - Sessions

- [ ] 11. Sidebar + Search 통합

  **What to do**:
  - `packages/shared-ui/src/components/Sidebar/`
    - SearchField: 검색 입력 + 실시간 필터링
    - TagBrowser: 태그 트리 뷰 (중첩 태그)
    - SidebarViewToggle: List / Tags 뷰 토글
    - FilterBar: 즐겨찾기 필터, 아카이브 토글
    - StatsBar: 세션 수, 총 메시지 수
  - `packages/shared-parser/src/search.ts` — 검색 엔진
    - 기본 전문 검색
    - 연산자 파싱: title:, content:, tag:, project:, date:, regex:, messages:
    - 날짜 필터: today, yesterday, week, month, 특정일, 범위
    - 메시지 수 필터: >N, <N, =N, N..M

  **Must NOT do**:
  - SQLite FTS (첫 버전은 인메모리 검색)
  - Fuzzy search

  **Parallelizable**: NO (depends on 9)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/App/SessionFilter.swift` - **핵심**: 검색 연산자 파싱 로직
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/SidebarView.swift` - 사이드바 구조
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/TagBrowserView.swift` - 태그 브라우저

  **Acceptance Criteria**:
  - [ ] `content:authentication` 검색 → 메시지 내용에 "authentication" 포함된 세션만 표시
  - [ ] `tag:backend project:api` 복합 검색 동작
  - [ ] `date:today` 필터 동작
  - [ ] `messages:>10` 필터 동작
  - [ ] 태그 클릭 → 해당 태그 세션만 필터링

  **Commit**: YES
  - Message: `feat: implement search with operators and tag browser`
  - Files: `packages/shared-parser/src/search.ts`, `packages/shared-ui/src/components/Sidebar/`

---

- [ ] 12. Session Detail View

  **What to do**:
  - `packages/shared-ui/src/components/SessionDetail/`
    - SessionDetailView: 세션 헤더 + 대화 목록 통합
    - InspectorContent: 우측 인스펙터 내용
      - SessionInfo: 세션 ID, 프로젝트, 메시지 수, 타임스탬프, 기간
      - SummarySection: AI 요약 표시 (생성은 TODO 25)
      - TagsSection: 태그 칩 + 추가/제거
      - ActionsSection: 내보내기, 세션 비교, 요약 생성 등
    - ToolCallFilter: 툴 콜 표시/숨김 토글

  **Must NOT do**:
  - Resume in Terminal (웹앱에서 불가 → "앱에서만 가능" 표시)

  **Parallelizable**: NO (depends on 10, 11)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/DetailView.swift` - 세션 상세 뷰 전체 구조
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/InspectorPanelView.swift` - 인스펙터 패널 구조

  **Acceptance Criteria**:
  - [ ] 세션 선택 → 헤더 + 메시지 목록 표시
  - [ ] 인스펙터에 세션 정보 표시
  - [ ] 태그 추가/제거 동작
  - [ ] 툴 콜 필터 토글 동작

  **Commit**: YES
  - Message: `feat: implement session detail view with inspector panel`
  - Files: `packages/shared-ui/src/components/SessionDetail/`

---

- [ ] 13. 검색 연산자 전체 구현 및 검증

  **What to do**:
  - `packages/shared-parser/src/search.ts` 보완
    - `regex:` 연산자: 정규식 검색
    - `date:YYYY-MM-DD..YYYY-MM-DD` 범위 검색
    - `messages:N..M` 범위 필터
    - 따옴표 정확구문 검색: `"error handling"`
    - 대소문자 무시 기본 동작
  - 검색 결과 하이라이팅 (AttributedString 대응 → HTML mark 태그)

  **Must NOT do**:
  - 검색 인덱스 빌드 (인메모리)

  **Parallelizable**: NO (depends on 11)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/App/SessionFilter.swift` - Swift 검색 연산자 전체 구현

  **Acceptance Criteria**:
  - [ ] `regex:\.swift$` 검색 동작
  - [ ] `date:2026-01-01..2026-01-31` 범위 검색 동작
  - [ ] `"error handling"` 정확구문 검색 동작
  - [ ] 검색 결과 내 하이라이팅 표시

  **Commit**: YES
  - Message: `feat: complete search operators with regex, date ranges, and highlighting`
  - Files: `packages/shared-parser/src/search.ts`

---

### Phase 5: Core Features - Management

- [ ] 14. Metadata Persistence Layer

  **What to do**:
  - `packages/shared-parser/src/persistence.ts` — 메타데이터 영속 계층 (인터페이스)
    - SessionMetadataStore: CRUD for favorites, pins, custom names, archived
    - TagDatabaseStore: CRUD for tag definitions (name, color, importance, parent)
    - SummaryStore: CRUD for AI summaries
    - SettingsStore: 앱 설정 읽기/쓰기
  - `apps/web/server/persistence.ts` — Bun fs 기반 구현
    - 저장 경로: `~/Library/Application Support/CmdTrace-Web/`
    - JSON 파일 기반 (Swift와 동일 포맷)
  - `apps/tauri/src-tauri/src/services/persistence.rs` — Rust 기반 구현
    - 저장 경로: `~/Library/Application Support/CmdTrace-Tauri/`

  **Must NOT do**:
  - Swift 앱의 `~/Library/Application Support/CmdTrace/` 직접 읽기/쓰기 (별도 경로 사용)
  - SQLite (JSON 파일 유지)

  **Parallelizable**: NO (depends on 2)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/App/PersistenceManager.swift` - Swift 영속 계층 참고
  - `/Users/yohankoo/DEV/CmdTrace/Sources/App/AppState.swift` - 설정 구조

  **Data Format References**:
  - `~/Library/Application Support/CmdTrace/session-metadata.json` - 세션 메타데이터 JSON 포맷
  - `~/Library/Application Support/CmdTrace/tag-database.json` - 태그 DB JSON 포맷
  - `~/Library/Application Support/CmdTrace/settings.json` - 설정 JSON 포맷

  **Acceptance Criteria**:
  - [ ] 세션에 즐겨찾기 설정 → 앱 재시작 후에도 유지
  - [ ] 태그 생성/삭제 → JSON 파일에 반영
  - [ ] 설정 변경 → 저장 및 복원

  **Commit**: YES
  - Message: `feat: implement metadata persistence for web and Tauri backends`
  - Files: `packages/shared-parser/src/persistence.ts`, `apps/web/server/persistence.ts`, `apps/tauri/src-tauri/src/services/persistence.rs`

---

- [ ] 15. Tag System

  **What to do**:
  - `packages/shared-ui/src/components/Tags/`
    - TagChip: 색상 태그 칩 (삭제 버튼)
    - TagBrowser: 중첩 태그 트리 뷰
    - TagEditor: 태그 추가 팝업 (이름, 색상, 중요도)
    - TagManager: 태그 일괄 관리 (이름 변경, 삭제, 정렬)
  - `packages/shared-parser/src/tags.ts` — 태그 로직
    - 태그 정렬: Important First, Alphabetical, Most Used, Least Used
    - 중첩 태그 파싱 (parent/child)
    - 태그 이름 변경 시 모든 세션 업데이트
    - 태그 삭제 시 모든 세션에서 제거

  **Must NOT do**:
  - 태그 자동 추천 (AI 기능은 TODO 25)

  **Parallelizable**: NO (depends on 14)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/App/TagManager.swift` - 태그 관리 로직
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/TagBrowserView.swift` - 태그 브라우저 UI
  - `/Users/yohankoo/DEV/CmdTrace/Sources/App/AppState.swift` - 태그 정렬 모드

  **Acceptance Criteria**:
  - [ ] 태그 생성 (이름 + 색상) → 태그 DB에 저장
  - [ ] 세션에 태그 추가/제거 → 즉시 반영
  - [ ] 태그 이름 변경 → 모든 세션에서 업데이트됨
  - [ ] 중첩 태그 트리 렌더링 (parent → children)
  - [ ] 4가지 정렬 모드 동작

  **Commit**: YES
  - Message: `feat: implement complete tag system with nesting, colors, and sorting`
  - Files: `packages/shared-ui/src/components/Tags/`, `packages/shared-parser/src/tags.ts`

---

- [ ] 16. Session Management (즐겨찾기, 고정, 아카이브, 벌크)

  **What to do**:
  - 세션 이름 변경 (커스텀 네임)
  - 즐겨찾기 토글 (별 아이콘)
  - 고정 토글 (핀 아이콘, 목록 상단 정렬)
  - 아카이브 토글 (숨기기, 토글로 표시)
  - 벌크 작업:
    - 멀티셀렉트 모드 (체크박스)
    - 전체 선택
    - 벌크 아카이브/언아카이브
    - 벌크 즐겨찾기
    - 벌크 태그 추가/제거
  - Zustand store 통합 (상태 관리)

  **Must NOT do**:
  - 세션 삭제 (JSONL 파일은 read-only, 메타데이터만 관리)

  **Parallelizable**: NO (depends on 14, 15)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/SidebarView.swift` - 벌크 액션 UI
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/SessionListViews.swift` - 세션 행 액션

  **Acceptance Criteria**:
  - [ ] 즐겨찾기 토글 → 별 아이콘 표시, 즐겨찾기 필터 동작
  - [ ] 고정 → 목록 상단 고정
  - [ ] 아카이브 → 목록에서 숨김, 토글로 다시 표시
  - [ ] 멀티셀렉트 → 체크박스, 벌크 태그 추가 동작

  **Commit**: YES
  - Message: `feat: implement session management with favorites, pins, archive, bulk ops`
  - Files: `packages/shared-ui/src/`, `packages/shared-parser/src/`

---

### Phase 6: Dashboard & Analytics

- [ ] 17. Dashboard View

  **What to do**:
  - `packages/shared-ui/src/components/Dashboard/`
    - DashboardView: 메인 대시보드
    - StatCards: 4개 통계 카드 (세션 수, 총 메시지, 고유 프로젝트, 오늘 세션)
    - ActivityChart: 14일 활동 바 차트 (Recharts)
    - TopProjects: 상위 8개 프로젝트 목록

  **Must NOT do**:
  - Swift Charts의 모든 인터랙션 복제 (hover tooltip 정도만)

  **Parallelizable**: NO (depends on 7, 14)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/DashboardView.swift` - 대시보드 구조
  - `/Users/yohankoo/DEV/cmdtrace-web/src/pages/DashboardPage.tsx` - 기존 웹앱 대시보드

  **Acceptance Criteria**:
  - [ ] 4개 통계 카드에 실제 데이터 표시
  - [ ] 14일 활동 차트 렌더링
  - [ ] 상위 프로젝트 목록 표시

  **Commit**: YES
  - Message: `feat: implement dashboard with stat cards, activity chart, and top projects`
  - Files: `packages/shared-ui/src/components/Dashboard/`

---

- [ ] 18. Usage Monitoring (ccusage 통합)

  **What to do**:
  - `packages/shared-ui/src/components/Usage/`
    - UsageSection: 사용량 메인 컨테이너
    - UsageTabView: Daily / Monthly / Blocks 탭
    - DailyUsageRow: 일일 사용량 행 (모델 브레이크다운)
    - MonthlyUsageRow: 월간 사용량 행
    - BlockUsageRow: 5시간 블록 행
    - UsageSummaryCards: 총 비용, 총 토큰, 캐시 히트
  - Backend에서 ccusage CLI 실행:
    - `ccusage daily --json --since YYYYMMDD`
    - `ccusage monthly --json`
    - `ccusage blocks --active --json --breakdown`

  **Must NOT do**:
  - claude-monitor TUI 통합 (터미널 전용)

  **Parallelizable**: NO (depends on 17)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/UsageViews.swift` - 사용량 뷰 전체
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Models/UsageData.swift` - 사용량 데이터 모델

  **Acceptance Criteria**:
  - [ ] Daily 탭: 일일 사용량 + 모델 브레이크다운 표시
  - [ ] Monthly 탭: 월간 사용량 표시
  - [ ] Blocks 탭: 현재 활성 블록 표시
  - [ ] 총 비용/토큰 요약 카드 표시

  **Commit**: YES
  - Message: `feat: implement usage monitoring with ccusage integration`
  - Files: `packages/shared-ui/src/components/Usage/`

---

- [ ] 19. Native Monitor View

  **What to do**:
  - `packages/shared-ui/src/components/Monitor/`
    - NativeMonitorView: 실시간 모니터링 시트
    - MonitorBar: 사용량 프로그레스 바 (Cost, Tokens, Messages)
    - BurnRateChart: 번 레이트 예측 차트 (Recharts)
      - Token/Cost 모드 토글
      - 프로젝션 라인
      - 한계선 표시
    - ModelDistribution: 모델별 사용량 비율
    - RefreshIntervalPicker: 5s/10s/30s/60s
    - ColorCustomization: 바 색상 커스터마이징

  **Must NOT do**:
  - 웹소켓 실시간 (polling 방식)

  **Parallelizable**: NO (depends on 18)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/NativeMonitorView.swift` - 전체 모니터 뷰
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/NativeMonitorView.swift` - BurnRateChartView, MonitorBarView

  **Acceptance Criteria**:
  - [ ] 프로그레스 바 3개 (Cost, Tokens, Messages) 표시
  - [ ] 번 레이트 차트 렌더링 (프로젝션 라인 포함)
  - [ ] 자동 새로고침 동작 (선택한 간격)
  - [ ] 색상 커스터마이징 동작

  **Commit**: YES
  - Message: `feat: implement native monitor view with burn rate chart`
  - Files: `packages/shared-ui/src/components/Monitor/`

---

### Phase 7: Advanced Features

- [ ] 20. Export 기능

  **What to do**:
  - `packages/shared-parser/src/export.ts` — 내보내기 로직
    - exportMarkdown(session, messages, options)
    - exportJSON(session, messages, options)
    - exportPlainText(session, messages, options)
    - exportHTML(session, messages, options)
    - 옵션: includeMetadata, includeToolCalls, includeTimestamps
  - `packages/shared-ui/src/components/Export/`
    - ExportDialog: 포맷 선택, 옵션, 프리뷰, 복사/저장

  **Must NOT do**:
  - 파일 저장 다이얼로그 (웹앱은 다운로드 링크, Tauri는 save_dialog)

  **Parallelizable**: YES (with 21, 22, 23, 24)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/ExportView.swift` - 내보내기 뷰 전체

  **Acceptance Criteria**:
  - [ ] 4가지 포맷 내보내기 동작
  - [ ] 프리뷰 표시 (첫 30줄)
  - [ ] 클립보드 복사 동작

  **Commit**: YES
  - Message: `feat: implement session export in Markdown, JSON, Text, HTML formats`
  - Files: `packages/shared-parser/src/export.ts`, `packages/shared-ui/src/components/Export/`

---

- [ ] 21. Session Diff

  **What to do**:
  - `packages/shared-ui/src/components/Diff/`
    - SessionDiffView: 세션 비교 뷰
    - SessionPicker: 비교할 세션 선택 드롭다운
    - SideBySideView: 나란히 비교
    - StatsComparison: 메시지 수, 기간, 타임스탬프 비교

  **Must NOT do**:
  - Unified diff 뷰 (Side-by-side만)
  - 메시지 레벨 diff

  **Parallelizable**: YES (with 20, 22, 23, 24)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/SessionDiffView.swift` - 세션 비교 뷰

  **Acceptance Criteria**:
  - [ ] 두 세션 선택 → 나란히 표시
  - [ ] 통계 비교 (메시지 수, 기간) 표시

  **Commit**: YES
  - Message: `feat: implement session diff with side-by-side comparison`
  - Files: `packages/shared-ui/src/components/Diff/`

---

- [ ] 22. Session Insights

  **What to do**:
  - `packages/shared-parser/src/insights.ts` — 세션 분석 로직
    - 툴 사용 통계 (빈도, 카테고리별)
    - 토큰 사용량 (input/output/cache)
    - 모델 사용량 (메시지 수, 토큰)
    - 파일 변경 추적
    - 에러 이벤트
    - 타임라인 이벤트
    - 예상 비용 계산
  - `packages/shared-ui/src/components/Insights/`
    - ToolUsageView: 툴 사용 차트
    - TokenUsageView: 토큰 차트
    - ModelUsageView: 모델별 파이 차트
    - TimelineView: 타임라인

  **Must NOT do**:
  - 실시간 업데이트 (세션 열 때 1회 계산)

  **Parallelizable**: YES (with 20, 21, 23, 24)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/SessionInsightsView.swift` - 인사이트 뷰
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Models/SessionInsights.swift` - 인사이트 모델

  **Acceptance Criteria**:
  - [ ] 툴 사용 통계 차트 표시
  - [ ] 토큰 사용량 차트 표시
  - [ ] 모델 사용량 차트 표시
  - [ ] 타임라인 이벤트 표시

  **Commit**: YES
  - Message: `feat: implement session insights with tool, token, model usage analytics`
  - Files: `packages/shared-parser/src/insights.ts`, `packages/shared-ui/src/components/Insights/`

---

- [ ] 23. Projects View

  **What to do**:
  - `packages/shared-ui/src/components/Projects/`
    - ProjectsGrid: 프로젝트 카드 그리드
    - ProjectCard: 프로젝트 카드 (이름, 세션 수, 메시지 수, 언어, 프레임워크)
    - ProjectDetail: 프로젝트 상세 (메타데이터, 세션 목록, 통계)
    - ProjectSearch: 프로젝트 검색

  **Must NOT do**:
  - 프로젝트 메타데이터 자동 감지 (수동 입력)

  **Parallelizable**: YES (with 20, 21, 22, 24)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/ProjectsView.swift` - 프로젝트 뷰
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Models/ProjectMetadata.swift` - 프로젝트 모델

  **Acceptance Criteria**:
  - [ ] 프로젝트 카드 그리드 렌더링
  - [ ] 프로젝트별 세션 수, 메시지 수 표시
  - [ ] 프로젝트 상세 뷰 동작

  **Commit**: YES
  - Message: `feat: implement projects view with cards grid and detail page`
  - Files: `packages/shared-ui/src/components/Projects/`

---

- [ ] 24. Configuration Browser

  **What to do**:
  - `packages/shared-parser/src/config-parser.ts` — Claude 설정 파싱
    - `~/.claude/` 디렉토리에서 commands, skills, hooks, agents, plugins 읽기
    - Global vs Project 스코프 구분
  - `packages/shared-ui/src/components/Config/`
    - ConfigBrowser: 설정 브라우저 메인
    - ConfigSection: 섹션별 리스트 (Commands, Skills, Hooks, Agents, Plugins)
    - ConfigItem: 개별 항목 (이름, 설명, 스코프 뱃지, 내용)
    - ConfigSearch: 설정 검색
    - ScopeFilter: Global/Project 필터

  **Must NOT do**:
  - 설정 편집 (read-only)

  **Parallelizable**: YES (with 20, 21, 22, 23)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Services/ClaudeConfigService.swift` - 설정 파싱 로직
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/ConfigurationView.swift` - 설정 브라우저 UI
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Models/ClaudeConfig.swift` - 설정 모델

  **Acceptance Criteria**:
  - [ ] Commands, Skills, Hooks, Agents, Plugins 섹션 표시
  - [ ] Global/Project 스코프 뱃지 표시
  - [ ] 검색 동작
  - [ ] 설정 내용 표시 (마크다운 렌더링)

  **Commit**: YES
  - Message: `feat: implement Claude configuration browser`
  - Files: `packages/shared-parser/src/config-parser.ts`, `packages/shared-ui/src/components/Config/`

---

### Phase 8: AI & Integration

- [ ] 25. AI Summary 생성

  **What to do**:
  - `packages/shared-parser/src/ai-summary.ts` — AI API 호출
    - OpenAI, Anthropic, Gemini, Grok API 지원
    - generateSummary(config, messages): summary, keyPoints, nextSteps, tags
    - configurable: maxMessages, maxCharsPerMessage, temperature, customPrompt
  - `packages/shared-ui/src/components/Summary/`
    - SummarySection: 요약 표시 (마크다운)
    - SummaryGenerator: 요약 생성 UI (프로바이더 선택, 생성 버튼, 진행 상태)
    - KeyPointsList: 핵심 포인트 리스트
    - SuggestedTags: 추천 태그

  **Must NOT do**:
  - 자동 요약 생성 (수동 트리거만)
  - API 키를 프론트엔드에 저장 (백엔드에서만 관리)

  **Parallelizable**: NO (depends on 12, 14)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Services/SummaryService.swift` - AI 요약 서비스 전체 로직

  **Acceptance Criteria**:
  - [ ] API 키 설정 → 프로바이더 선택 → 요약 생성 동작
  - [ ] 요약, 핵심 포인트, 추천 태그 표시
  - [ ] 생성된 요약 저장 및 재표시

  **Commit**: YES
  - Message: `feat: implement AI summary generation with multi-provider support`
  - Files: `packages/shared-parser/src/ai-summary.ts`, `packages/shared-ui/src/components/Summary/`

---

- [ ] 26. Settings View

  **What to do**:
  - `packages/shared-ui/src/components/Settings/`
    - SettingsView: 설정 메인 (탭 기반)
    - GeneralSettings: 테마, CLI 선택, 표시 옵션
    - APIKeysSettings: 4개 프로바이더 API 키 입력
    - AISettings: 모델 선택, 온도, 토큰 수, 컨텍스트 프롬프트
    - UsageSettings: 플랜 선택, 자동 새로고침, 색상
    - ConnectionStatus: 서버 연결 상태 (웹앱용)

  **Must NOT do**:
  - iCloud 동기화 설정 (별도 계획)
  - Obsidian 연동 설정 (데스크톱 전용 → "앱에서만 가능")
  - Terminal 설정 (데스크톱 전용)

  **Parallelizable**: NO (depends on 14)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/SettingsView.swift` - 설정 뷰 전체

  **Acceptance Criteria**:
  - [ ] 테마 변경 → 즉시 반영
  - [ ] API 키 입력 → 저장 → 재시작 후 유지
  - [ ] CLI 도구 선택 → 세션 목록 변경
  - [ ] 네이티브 전용 기능에 "앱에서만 가능" 라벨 표시

  **Commit**: YES
  - Message: `feat: implement settings view with all configuration options`
  - Files: `packages/shared-ui/src/components/Settings/`

---

- [ ] 27. Keyboard Shortcuts + Statistics

  **What to do**:
  - 키보드 단축키:
    - `Cmd+R` / `Ctrl+R`: 세션 새로고침
    - `Cmd+F` / `Ctrl+F`: 검색 포커스
    - `Cmd+1~3` / `Ctrl+1~3`: 탭 전환
    - `↑↓`: 세션 목록 네비게이션
  - `packages/shared-ui/src/components/Statistics/`
    - StatisticsSheet: 통계 시트 (30일 활동, 프로젝트/태그 분포)

  **Must NOT do**:
  - Deep link (웹앱은 URL 라우팅으로 대체, Tauri는 추후)

  **Parallelizable**: NO (depends on 8, 11)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/CmdTrace/Sources/App/CmdTraceApp.swift` - 키보드 단축키 정의
  - `/Users/yohankoo/DEV/CmdTrace/Sources/Views/StatisticsView.swift` - 통계 뷰

  **Acceptance Criteria**:
  - [ ] Cmd+R → 세션 새로고침 동작
  - [ ] Cmd+F → 검색 필드 포커스
  - [ ] ↑↓ → 세션 목록 네비게이션
  - [ ] 통계 시트 표시 (30일 차트, 프로젝트 분포)

  **Commit**: YES
  - Message: `feat: implement keyboard shortcuts and statistics view`
  - Files: `packages/shared-ui/src/`

---

### Phase 9: Platform Integration & Final QA

- [ ] 28. Tauri 앱 통합

  **What to do**:
  - `apps/tauri/src/` — React 프론트엔드
    - shared-ui 컴포넌트 import 및 통합
    - Tauri IPC (invoke) 기반 데이터 레이어
    - `useTauriApi.ts`: Tauri invoke 래퍼
    - Zustand store: Tauri IPC 연동
    - 모든 페이지 연결: Sessions, Dashboard, Projects, Config, Settings
  - `apps/tauri/src-tauri/` — Rust 백엔드 최종 연결
    - 모든 IPC 커맨드 연결 확인
    - 파일 감시자 (notify crate) 연결
    - 메뉴/단축키 네이티브 연결

  **Must NOT do**:
  - 추가 기능 (Swift에 없는 것)

  **Parallelizable**: YES (with 29)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/cmdtrace-tauri/src/hooks/useTauriApi.ts` - 기존 Tauri API 래퍼
  - `/Users/yohankoo/DEV/cmdtrace-tauri/src/store/index.ts` - 기존 Zustand store

  **Acceptance Criteria**:
  - [ ] `pnpm tauri dev` → 앱 시작
  - [ ] 세션 목록 로드 (Swift 앱과 동일한 수)
  - [ ] 세션 선택 → 메시지 표시
  - [ ] 검색 동작
  - [ ] 태그 추가/제거 동작
  - [ ] 대시보드 차트 표시
  - [ ] 설정 저장/복원 동작

  **Commit**: YES
  - Message: `feat: integrate shared UI components into Tauri app`
  - Files: `apps/tauri/`

---

- [ ] 29. Webapp 통합

  **What to do**:
  - `apps/web/src/` — React 프론트엔드
    - shared-ui 컴포넌트 import 및 통합
    - HTTP API (fetch) 기반 데이터 레이어
    - `useWebApi.ts`: Bun+Hono API 래퍼
    - Zustand store: HTTP API 연동
    - 모든 페이지 연결: Sessions, Dashboard, Projects, Config, Settings
    - React Router 라우팅 설정
  - `apps/web/` — Bun 서버 + Vite 프론트엔드 통합
    - Dev: Vite dev server (3000) + Bun API (3001), proxy 설정
    - Prod: Bun이 static + API 모두 서빙

  **Must NOT do**:
  - Swift 앱 LocalServer 의존

  **Parallelizable**: YES (with 28)

  **References**:

  **Pattern References**:
  - `/Users/yohankoo/DEV/cmdtrace-web/src/store/index.ts` - 기존 Zustand store
  - `/Users/yohankoo/DEV/cmdtrace-web/src/App.tsx` - 기존 라우팅

  **Acceptance Criteria**:
  - [ ] `bun run dev` → 브라우저에서 전체 기능 동작 (Swift 앱 없이!)
  - [ ] 세션 목록 로드 (Swift 앱과 동일한 수)
  - [ ] 세션 선택 → 메시지 표시
  - [ ] 검색 동작
  - [ ] 태그 추가/제거 동작
  - [ ] 대시보드 차트 표시
  - [ ] 설정 저장/복원 동작

  **Commit**: YES
  - Message: `feat: integrate shared UI components into webapp with independent backend`
  - Files: `apps/web/`

---

- [ ] 30. Final QA: 3개 앱 기능 대조 확인

  **What to do**:
  - Swift 앱 vs Webapp vs Tauri 기능 대조표 작성
  - 체크리스트:
    - [ ] 세션 목록 동일성 (수, 순서, 제목, 프로젝트)
    - [ ] 메시지 내용 동일성 (3개 세션 이상)
    - [ ] 검색 연산자 7종 동작 확인
    - [ ] 태그 CRUD 동작
    - [ ] 즐겨찾기/고정/아카이브 동작
    - [ ] 대시보드 통계 일치
    - [ ] 사용량 모니터링 동작
    - [ ] 내보내기 4종 동작
    - [ ] 세션 비교 동작
    - [ ] 인사이트 동작
    - [ ] 프로젝트 뷰 동작
    - [ ] 설정 저장/복원

  **Must NOT do**:
  - 자동화 테스트 (수동 체크)

  **Parallelizable**: NO (depends on 28, 29)

  **Acceptance Criteria**:
  - [ ] 기능 대조표 완성 → 모든 항목 PASS
  - [ ] 스크린샷 비교 (주요 3개 화면)

  **Commit**: YES
  - Message: `chore: final QA verification for multiplatform feature parity`

---

## Commit Strategy

| After Task | Message | Verification |
|------------|---------|--------------|
| 1 | `feat: initialize cmdtrace-multiplatform monorepo` | pnpm install |
| 2 | `feat: shared TypeScript types` | tsc --noEmit |
| 3 | `feat: shared JSONL/JSON parsers` | tsc --noEmit |
| 4 | `feat: Bun+Hono backend` | curl health check |
| 5 | `fix: Tauri JSONL parser` | cargo build |
| 6 | (no commit) | manual verification |
| 7-10 | `feat: shared UI components` | visual check |
| 11-13 | `feat: search + session features` | search test |
| 14-16 | `feat: persistence + management` | restart check |
| 17-19 | `feat: dashboard + monitoring` | chart render |
| 20-24 | `feat: advanced features` | feature check |
| 25-27 | `feat: AI + settings + shortcuts` | key test |
| 28 | `feat: Tauri integration` | pnpm tauri dev |
| 29 | `feat: webapp integration` | bun run dev |
| 30 | `chore: final QA` | all pass |

---

## Success Criteria

### Verification Commands
```bash
# Monorepo 빌드
cd /Users/yohankoo/DEV/cmdtrace-multiplatform && pnpm install && pnpm build
# Expected: all packages and apps build successfully

# Webapp 독립 실행
cd apps/web && bun run dev
# Expected: http://localhost:3000 에서 전체 기능 동작, Swift 앱 없이

# Tauri 독립 실행
cd apps/tauri && pnpm tauri dev
# Expected: 네이티브 앱 실행, 전체 기능 동작

# 세션 수 검증
curl http://localhost:3001/api/sessions | jq length
# Expected: Swift 앱과 동일한 세션 수 (±5)
```

### Final Checklist
- [ ] Webapp이 Swift 앱 없이 독립 실행됨
- [ ] Tauri가 독립 실행됨
- [ ] 세션 파싱 결과가 Swift 앱과 동일
- [ ] 검색 연산자 7종 모두 동작
- [ ] 태그 시스템 완전 동작
- [ ] 대시보드/사용량 모니터링 동작
- [ ] AI 요약 생성 동작
- [ ] 내보내기 4종 동작
- [ ] 기존 cmdtrace-web, cmdtrace-tauri 프로젝트 미수정
