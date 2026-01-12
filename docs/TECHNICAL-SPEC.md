# CmdTrace 기술 사양서 (Technical Specifications)

<p align="center">
  <img src="../Resources/AppIcon.png" width="96" height="96" alt="CmdTrace Icon">
</p>

---

## 1. 기술 스택 (Tech Stack)

### 1.1 핵심 기술

| 항목 | 기술 | 버전 |
|------|------|------|
| **언어** | Swift | 5.9+ |
| **UI 프레임워크** | SwiftUI | macOS 14+ |
| **상태 관리** | Swift Observation | `@Observable` |
| **패키지 관리** | Swift Package Manager | - |
| **차트** | Swift Charts | macOS 14+ |

### 1.2 플랫폼 요구사항

| 항목 | 요구사항 |
|------|----------|
| **Primary** | macOS 14.0+ (Sonoma) |
| **아키텍처** | Apple Silicon (arm64), Intel (x86_64) |
| **최소 메모리** | 4GB RAM |
| **저장 공간** | 100MB+ |

---

## 2. 프로젝트 구조 (Project Structure)

```
CmdTrace/
├── Package.swift              # SPM 패키지 정의
├── build-app.sh               # 앱 번들 빌드 스크립트
├── Resources/
│   ├── AppIcon.icns           # macOS 앱 아이콘
│   └── AppIcon.png            # README용 아이콘
├── Sources/
│   ├── App/
│   │   ├── CmdTraceApp.swift  # 앱 진입점, 윈도우/메뉴 설정
│   │   └── AppState.swift     # 전역 상태 (@Observable)
│   ├── Models/
│   │   ├── Session.swift      # 세션 데이터 모델
│   │   └── Message.swift      # 메시지/대화 모델
│   ├── Services/
│   │   └── SessionService.swift # JSONL 파싱, 세션 로딩
│   └── Views/
│       ├── ContentView.swift  # 메인 레이아웃 (NavigationSplitView)
│       ├── SidebarView.swift  # 세션 목록, 태그, 검색/필터
│       ├── DetailView.swift   # 대화 뷰, 대시보드, AI 상호작용
│       └── SettingsView.swift # 앱 설정 UI
└── docs/
    ├── INTRODUCTION.md        # 제품 소개
    ├── USER-GUIDE.md          # 사용 설명서
    └── TECHNICAL-SPEC.md      # 기술 사양서 (현재 문서)
```

---

## 3. 아키텍처 (Architecture)

### 3.1 계층 구조

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    SwiftUI Views                       │  │
│  │  ContentView │ SidebarView │ DetailView │ SettingsView │  │
│  └───────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                    Application Layer                         │
│  ┌───────────────────────────────────────────────────────┐  │
│  │               AppState (@Observable)                   │  │
│  │  - sessions, settings, metadata, tags, summaries       │  │
│  └───────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                    Domain Layer                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                     Models                             │  │
│  │  Session │ Message │ TagInfo │ SessionMetadata         │  │
│  └───────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                    Data Layer                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │   SessionService │ FileManager │ JSON Persistence      │  │
│  └───────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                    External Integrations                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Claude Code │ OpenCode │ ccusage │ Obsidian Vault     │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 상태 관리 패턴

Swift Observation 프레임워크의 `@Observable` 매크로를 사용한 반응형 상태 관리:

```swift
@Observable
final class AppState {
    var sessions: [Session] = []
    var filteredSessions: [Session] = []
    var selectedSession: Session?
    var selectedTab: AppTab = .sessions
    var settings: AppSettings = AppSettings()
    // ...
}
```

**뷰에서 사용:**
```swift
@Environment(AppState.self) private var appState
@Bindable var state = appState  // 양방향 바인딩용
```

---

## 4. 데이터 모델 (Data Models)

### 4.1 핵심 모델

#### Session
```swift
struct Session: Identifiable {
    let id: String
    let title: String
    let project: String
    let projectName: String
    let preview: String
    let lastActivity: Date
    let messages: [Message]
    // ...
}
```

#### Message
```swift
struct Message: Identifiable {
    let id: String
    let role: MessageRole  // user, assistant, system
    let content: String
    let timestamp: Date
    let toolCalls: [ToolCall]?
    // ...
}
```

#### TagInfo
```swift
struct TagInfo: Codable, Identifiable {
    var name: String
    var color: String      // hex color
    var isImportant: Bool
    var parentTag: String? // 계층 구조 지원
}
```

#### SessionMetadata
```swift
struct SessionMetadata: Codable {
    var isFavorite: Bool = false
    var isPinned: Bool = false
    var customName: String?
    var tags: [String] = []
}
```

### 4.2 설정 모델

```swift
struct AppSettings: Codable {
    var selectedCLI: CLITool = .claude
    var theme: AppTheme = .system
    var enabledCLIs: [CLITool] = [.claude, .opencode]

    // API Keys
    var openaiKey: String = ""
    var anthropicKey: String = ""
    var geminiKey: String = ""
    var grokKey: String = ""

    // Obsidian
    var obsidianVaultPath: String = ""

    // Display
    var showToolCalls: Bool = true
    var renderMarkdown: Bool = true
    // ...
}
```

---

## 5. 데이터 저장 (Data Storage)

### 5.1 파일 구조

| 파일 | 용도 | 형식 |
|------|------|------|
| `settings.json` | 앱 설정 | JSON |
| `session-metadata.json` | 세션 메타데이터 (즐겨찾기, 고정, 이름, 태그) | JSON |
| `tag-database.json` | 태그 정의 (색상, 중요도, 계층) | JSON |
| `summaries.json` | AI 생성 요약 | JSON |

### 5.2 저장 경로

```
~/Library/Application Support/CmdTrace/
├── settings.json
├── session-metadata.json
├── tag-database.json
└── summaries.json
```

### 5.3 세션 데이터 소스

| CLI | 경로 | 형식 |
|-----|------|------|
| **Claude Code** | `~/.claude/projects/*/sessions/*.jsonl` | JSONL |
| **OpenCode** | `~/.opencode/sessions/*.jsonl` | JSONL |
| **Antigravity** | `~/.opencode/sessions/*.jsonl` | JSONL |

---

## 6. 핵심 서비스 (Core Services)

### 6.1 SessionService

JSONL 파일 파싱 및 세션 로딩:

```swift
class SessionService {
    func loadSessions(for agent: AgentType) async throws -> [Session]
    func parseJSONL(_ url: URL) throws -> [Message]
}
```

### 6.2 세션 캐싱

앱 시작 시 모든 CLI의 세션을 백그라운드에서 프리로드:

```swift
@MainActor
func preloadAllSessions() async {
    // 현재 CLI 먼저 로드 (즉시 표시)
    await loadSessions()

    // 다른 CLI 백그라운드 로드
    for agent in AgentType.allCases where agent != agentType {
        // ...
    }
}
```

---

## 7. UI 컴포넌트 (UI Components)

### 7.1 메인 뷰 구조

```swift
NavigationSplitView {
    SidebarView()     // 세션 목록
} detail: {
    switch selectedTab {
    case .sessions:
        SessionDetailView()
    case .dashboard:
        DashboardView()
    case .interaction:
        AIInteractionView()
    }
}
```

### 7.2 주요 뷰

| 뷰 | 역할 |
|----|------|
| **ContentView** | 메인 레이아웃, NavigationSplitView |
| **SidebarView** | 세션 목록, 검색, 필터, 태그 |
| **SessionDetailView** | 대화 내용 표시, 마크다운 렌더링 |
| **DashboardView** | 통계, 캘린더, 차트 |
| **NativeMonitorView** | 내장 사용량 모니터링 |
| **BurnRateChartView** | Burn Rate 예측 차트 (Swift Charts) |
| **SettingsView** | 앱 설정 UI |

### 7.3 Usage Tools Integration

```swift
// ccusage 실행 (JSON 출력)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/zsh")
process.arguments = ["-l", "-c", "ccusage blocks --active --json --breakdown 2>/dev/null"]
```

> ⚠️ **중요**: GUI 앱에서 CLI 실행 시 `2>/dev/null`로 stderr를 분리해야 JSON 파싱 오류 방지

---

## 8. URL Scheme

### 8.1 Deep Link 지원

```
cmdtrace://session/{session-id}
```

### 8.2 Info.plist 설정

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>CmdTrace Session</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>cmdtrace</string>
        </array>
    </dict>
</array>
```

---

## 9. 빌드 설정 (Build Configuration)

### 9.1 Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CmdTrace",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CmdTrace", targets: ["CmdTrace"])
    ],
    targets: [
        .executableTarget(
            name: "CmdTrace",
            path: "Sources"
        )
    ]
)
```

### 9.2 빌드 스크립트 (build-app.sh)

```bash
#!/bin/bash
APP_NAME="CmdTrace"
BUNDLE_ID="com.cmdspace.cmdtrace"
VERSION="2.1.0-alpha"

# Build release
swift build -c release

# Create app bundle
cp .build/release/CmdTrace "$MACOS_DIR/$APP_NAME"
cp Resources/AppIcon.icns "$RESOURCES_DIR/"

# Generate Info.plist
# ...
```

### 9.3 빌드 명령어

```bash
# 디버그 빌드
swift build

# 릴리즈 빌드
swift build -c release

# 앱 번들 생성
./build-app.sh

# 실행
swift run
# 또는
./build/CmdTrace.app/Contents/MacOS/CmdTrace
```

---

## 10. 외부 연동 (External Integrations)

### 10.1 ccusage 연동

| 명령어 | 용도 |
|--------|------|
| `ccusage daily --json` | 일간 사용량 |
| `ccusage monthly --json` | 월간 사용량 |
| `ccusage blocks --active --json --breakdown` | 현재 빌링 블록 (실시간) |

### 10.2 claude-monitor 연동

| 명령어 | 용도 |
|--------|------|
| `claude-monitor --plan pro` | 실시간 모니터링 |

### 10.3 Obsidian 연동

```swift
// 노트 내보내기
let obsidianPath = settings.obsidianVaultPath
let filename = "\(prefix)\(session.title)\(suffix).md"
let content = """
---
title: \(session.title)
date: \(session.lastActivity)
tags: [\(tags.joined(separator: ", "))]
---

\(markdownContent)
"""
```

---

## 11. 성능 최적화 (Performance)

### 11.1 세션 캐싱

- 앱 시작 시 모든 CLI 세션 백그라운드 프리로드
- CLI 전환 시 즉시 표시 (캐시 히트)

### 11.2 비동기 로딩

```swift
Task { @MainActor in
    await loadSessions()
}
```

### 11.3 필터링 최적화

- 검색 쿼리 변경 시 `filterSessions()` 호출
- 메모리 내 필터링으로 즉각적인 응답

---

## 12. 보안 고려사항 (Security)

### 12.1 Local-first 원칙

- 모든 데이터 로컬 저장
- 네트워크 전송 없음 (API 키 제외)
- 클라우드 동기화 미지원

### 12.2 API 키 저장

- 현재: UserDefaults (평문)
- 향후 고려: Keychain Services

### 12.3 파일 접근

- 세션 파일: 읽기 전용
- 메타데이터: 읽기/쓰기

---

## 13. 향후 로드맵 (Roadmap)

### v2.2 (계획)
- [ ] Spotlight 통합
- [ ] 위젯 지원 (WidgetKit)
- [ ] 메뉴바 앱 모드

### v3.0 (향후)
- [ ] iOS/iPadOS 버전 (SwiftUI 코드 재사용)
- [ ] Safari Extension (Claude.ai 연동)
- [ ] 플러그인 아키텍처
- [ ] 팀 동기화 (선택적)

---

## 14. 버전 히스토리 (Version History)

| 버전 | 날짜 | 주요 변경사항 |
|------|------|---------------|
| v2.1.0-alpha | 2025-01 | 내장 모니터링, Burn Rate 차트 |
| v2.0.0-alpha | 2025-01 | Swift 네이티브 재작성, 대시보드 |
| v1.x | 2024 | 초기 프로토타입 |

---

## 15. 라이선스 (License)

```
Copyright (c) 2025 CMDSPACE. All Rights Reserved.

This is proprietary software. Unauthorized copying, modification,
distribution, or use is strictly prohibited.
```

---

*문의: johnfkoo951@gmail.com*
