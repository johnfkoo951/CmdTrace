# CmdTrace 사용 설명서 (User Guide)

<p align="center">
  <img src="../Resources/AppIcon.png" width="96" height="96" alt="CmdTrace Icon">
</p>

---

## 목차
1. [설치](#1-설치-installation)
2. [시작하기](#2-시작하기-getting-started)
3. [세션 탐색](#3-세션-탐색-session-navigation)
4. [검색 및 필터](#4-검색-및-필터-search--filter)
5. [세션 관리](#5-세션-관리-session-management)
6. [대시보드](#6-대시보드-dashboard)
7. [사용량 모니터링](#7-사용량-모니터링-usage-monitoring)
8. [AI 상호작용](#8-ai-상호작용-ai-interaction)
9. [설정](#9-설정-settings)
10. [키보드 단축키](#10-키보드-단축키-keyboard-shortcuts)
11. [문제 해결](#11-문제-해결-troubleshooting)

---

## 1. 설치 (Installation)

### 1.1 소스에서 빌드

```bash
# 저장소 클론
git clone https://github.com/johnfkoo951/CmdTrace.git
cd CmdTrace

# 릴리즈 앱 번들 빌드
./build-app.sh

# Applications 폴더에 설치
cp -r ./build/CmdTrace.app /Applications/
```

### 1.2 개발 모드 실행

```bash
swift build
swift run
```

### 1.3 선택적 CLI 도구 설치

사용량 모니터링 기능을 사용하려면:

```bash
# ccusage (Node.js)
npm install -g ccusage
# 또는
npx ccusage@latest

# claude-monitor (Python)
pip install claude-monitor
# 또는
uv tool install claude-monitor
```

---

## 2. 시작하기 (Getting Started)

### 2.1 첫 실행

1. CmdTrace.app을 실행합니다
2. 자동으로 Claude Code 세션을 스캔합니다
3. 사이드바에 세션 목록이 표시됩니다

### 2.2 화면 구성

```
┌─────────────────────────────────────────────────────────────┐
│  [Sessions] [Dashboard] [Interaction]        🔍 검색        │
├──────────────────┬──────────────────────────────────────────┤
│                  │                                          │
│   사이드바        │           메인 콘텐츠 영역               │
│   (세션 목록)     │         (세션 상세/대시보드)              │
│                  │                                          │
│   - Session 1    │                                          │
│   - Session 2    │                                          │
│   - Session 3    │                                          │
│                  │                                          │
└──────────────────┴──────────────────────────────────────────┘
```

### 2.3 CLI 도구 전환

상단의 CLI 선택기에서 전환할 수 있습니다:
- **Claude Code**: Claude Code 세션
- **OpenCode**: OpenCode 세션
- **Antigravity**: Antigravity 세션

> 💡 **Tip**: CLI 전환 시 세션이 캐싱되어 즉시 전환됩니다.

---

## 3. 세션 탐색 (Session Navigation)

### 3.1 세션 목록

사이드바에서 세션 목록을 확인할 수 있습니다:
- **프로젝트명**: 세션이 속한 프로젝트
- **제목**: 세션 제목 또는 사용자 정의 이름
- **시간**: 마지막 활동 시간
- **미리보기**: 첫 번째 메시지 미리보기

### 3.2 세션 상세 보기

세션을 클릭하면 상세 내용을 볼 수 있습니다:
- **대화 내용**: 전체 대화 기록
- **메시지 타입**: 사용자/어시스턴트 구분
- **도구 호출**: Tool 사용 내역 (설정에서 표시/숨김 가능)

### 3.3 보기 모드

사이드바 상단에서 보기 모드를 전환할 수 있습니다:
- **List**: 일반 목록 뷰
- **Tags**: 태그별 그룹 뷰

---

## 4. 검색 및 필터 (Search & Filter)

### 4.1 기본 검색

검색창(`Cmd+F`)에 키워드를 입력하면 다음 항목에서 검색합니다:
- 세션 제목
- 프로젝트명
- 대화 내용 미리보기
- 사용자 정의 이름
- 태그

### 4.2 검색 연산자

특정 필드만 검색하려면 연산자를 사용합니다:

| 연산자 | 설명 | 예시 |
|--------|------|------|
| `title:` | 제목에서만 검색 | `title:python` |
| `tag:` | 태그에서만 검색 | `tag:important` |
| `project:` | 프로젝트명에서만 검색 | `project:CmdTrace` |
| `content:` | 대화 내용에서만 검색 | `content:error` |

### 4.3 필터링

- **즐겨찾기만 보기**: 즐겨찾기한 세션만 표시
- **태그 필터**: 특정 태그가 지정된 세션만 표시

---

## 5. 세션 관리 (Session Management)

### 5.1 즐겨찾기

세션을 우클릭하거나 상세 보기에서 ⭐️ 아이콘을 클릭하여 즐겨찾기할 수 있습니다.

### 5.2 고정 (Pin)

중요한 세션을 목록 상단에 고정할 수 있습니다.

### 5.3 이름 변경

세션에 사용자 정의 이름을 지정할 수 있습니다:
1. 세션 우클릭
2. "이름 변경" 선택
3. 새 이름 입력

### 5.4 태그 관리

#### 태그 추가
1. 세션 상세 보기에서 태그 영역 클릭
2. 새 태그 이름 입력 또는 기존 태그 선택

#### 태그 설정
- **색상**: 태그별 색상 지정
- **중요**: 중요 태그로 표시 (정렬 우선순위 상승)
- **계층 구조**: 상위 태그 지정 가능

#### 태그 정렬 옵션
| 옵션 | 설명 |
|------|------|
| Important First | 중요 태그 먼저 |
| Alphabetical | 알파벳순 |
| Most Used | 많이 사용된 순 |
| Least Used | 적게 사용된 순 |

---

## 6. 대시보드 (Dashboard)

### 6.1 세션 통계

- **전체 세션 수**: 현재 CLI의 총 세션 수
- **총 메시지 수**: 모든 메시지 합계
- **총 토큰 수**: 사용된 토큰 합계

### 6.2 활동 캘린더

GitHub 스타일의 기여 히트맵으로 일별 활동량을 시각화합니다:
- 색상 진하기 = 활동량
- 마우스 오버 시 상세 정보 표시

### 6.3 모델 분포

사용된 AI 모델별 분포를 차트로 표시합니다.

---

## 7. 사용량 모니터링 (Usage Monitoring)

### 7.1 Usage Tools 섹션

대시보드의 "Usage Tools" 섹션에서 사용량을 모니터링할 수 있습니다.

### 7.2 ccusage 탭

| 탭 | 설명 |
|----|------|
| **Daily** | 일간 사용량 |
| **Monthly** | 월간 사용량 |
| **Weekly** | 주간 사용량 |
| **5h Blocks** | 5시간 빌링 블록 |

### 7.3 내장 모니터링 (Native Monitoring)

메뉴 버튼(•••)에서 "내장 모니터링"을 선택하면:

#### 사용량 바
- **Cost**: 현재 비용 / 한도
- **Tokens**: 현재 토큰 / 한도
- **Messages**: 현재 메시지 / 한도

#### 커스터마이징
- 🎨 팔레트 아이콘으로 바 색상 변경 가능
- 자동 새로고침: 5초, 10초, 30초, 60초

#### Burn Rate 차트
- **토큰 모드**: 토큰 소비 예측
- **비용 모드**: 비용 예측
- 빌링 블록 종료까지 예측 그래프
- 한도 초과 예상 시 경고 표시

### 7.4 claude-monitor 지원

Settings에서 claude-monitor를 설정하면:
- 플랜 선택: Pro, Max5, Max20
- 뷰 모드: Realtime, Daily, Monthly

---

## 8. AI 상호작용 (AI Interaction)

### 8.1 AI 제공자 설정

Settings에서 API 키를 설정합니다:
- **OpenAI**: GPT 모델 사용
- **Anthropic**: Claude 모델 사용
- **Gemini**: Google Gemini 사용
- **Grok**: xAI Grok 사용

### 8.2 세션 요약

AI를 사용하여 세션 요약을 생성할 수 있습니다:
- **요약**: 핵심 내용 요약
- **주요 포인트**: 중요 사항 목록
- **다음 단계 제안**: 후속 작업 제안

### 8.3 Obsidian 내보내기

세션을 Obsidian 노트로 내보낼 수 있습니다:
1. Settings에서 Vault 경로 설정
2. 세션 상세에서 "Export to Obsidian" 클릭
3. YAML Frontmatter + Markdown 형식으로 저장

---

## 9. 설정 (Settings)

### 9.1 일반 설정

| 설정 | 설명 |
|------|------|
| **Theme** | System / Light / Dark |
| **Show Tool Calls** | 도구 호출 표시 여부 |
| **Render Markdown** | 마크다운 렌더링 여부 |

### 9.2 CLI 설정

- **Enabled CLIs**: 활성화할 CLI 도구 선택
- **CLI Icons**: CLI별 커스텀 아이콘 설정

### 9.3 API 키 설정

각 AI 제공자의 API 키를 입력합니다.

### 9.4 Obsidian 설정

| 설정 | 설명 |
|------|------|
| **Vault Path** | Obsidian Vault 경로 |
| **Prefix** | 노트 파일명 접두사 |
| **Suffix** | 노트 파일명 접미사 |

---

## 10. 키보드 단축키 (Keyboard Shortcuts)

### 10.1 전역 단축키

| 단축키 | 동작 |
|--------|------|
| `Cmd+R` | 세션 새로고침 |
| `Cmd+F` | 검색창 포커스 |
| `Cmd+1` | Sessions 탭 |
| `Cmd+2` | Dashboard 탭 |
| `Cmd+3` | AI Interaction 탭 |
| `Cmd+,` | 설정 열기 |

### 10.2 세션 관련

| 단축키 | 동작 |
|--------|------|
| `↑` / `↓` | 세션 목록 탐색 |
| `Enter` | 선택한 세션 열기 |
| `Cmd+C` | 선택 영역 복사 |

---

## 11. 문제 해결 (Troubleshooting)

### 11.1 세션이 표시되지 않음

1. CLI 도구가 올바르게 선택되었는지 확인
2. `Cmd+R`로 새로고침
3. 해당 CLI의 세션 파일 경로 확인:
   - Claude Code: `~/.claude/projects/*/sessions/*.jsonl`
   - OpenCode: `~/.opencode/sessions/*.jsonl`

### 11.2 사용량 모니터링 오류

1. ccusage가 설치되었는지 확인: `npx ccusage@latest --version`
2. 터미널에서 직접 실행하여 확인: `ccusage blocks --active --json`

### 11.3 데이터 파일 위치

CmdTrace 데이터는 다음 위치에 저장됩니다:
```
~/Library/Application Support/CmdTrace/
├── settings.json          # 앱 설정
├── session-metadata.json  # 세션 메타데이터
├── tag-database.json      # 태그 데이터베이스
└── summaries.json         # AI 요약
```

### 11.4 앱 초기화

설정을 초기화하려면:
```bash
rm -rf ~/Library/Application\ Support/CmdTrace/
```

---

## 부록: Deep Link

CmdTrace는 URL Scheme을 지원합니다:
```
cmdtrace://session/{session-id}
```

터미널에서 세션을 직접 열 수 있습니다:
```bash
open "cmdtrace://session/abc123"
```

---

*Copyright (c) 2025 CMDSPACE. All Rights Reserved.*
