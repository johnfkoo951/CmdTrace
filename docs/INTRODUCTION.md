# CmdTrace - 제품 소개 (Product Introduction)

<p align="center">
  <img src="../Resources/AppIcon.png" width="128" height="128" alt="CmdTrace Icon">
</p>

<p align="center">
  <strong>AI CLI 에이전트 세션을 추적하고 관리하는 macOS 네이티브 앱</strong>
</p>

---

## 1. 제품 개요 (Overview)

### 1.1 한 줄 정의
> **CmdTrace** — AI 에이전트 세션을 추적하고 관리하는 로컬 우선(Local-first) macOS 데스크톱 도구

### 1.2 이름의 의미
| 요소 | 의미 |
|------|------|
| **Cmd** | Command의 축약형. CLI/터미널 환경의 "명령" 개념, 사용자가 AI 작업을 "지휘(Command)"한다는 철학 |
| **Trace** | 추적, 흔적. 세션 기록의 추적(Tracking), 작업 이력의 보존, 디버깅/로깅 문화의 "Trace" 개념 |

### 1.3 Tagline
> **"Trace what you command."**

---

## 2. 핵심 가치 (Core Values)

### 2.1 제품 원칙

| 원칙 | 설명 |
|------|------|
| **Local-first** | 모든 데이터는 로컬에 저장, 클라우드 의존 없음 |
| **Private-by-default** | 기본 비공개, 사용자 완전 통제 |
| **Desktop-first** | macOS 네이티브 최적화, 키보드 중심 UX |
| **Agent-agnostic** | Claude Code, OpenCode, Antigravity 등 다양한 AI CLI 지원 |

### 2.2 가치 제안

| 대상 | 가치 제안 |
|------|-----------|
| **개발자** | 흩어진 AI 세션을 한 곳에서 검색(Search), 재사용(Reuse), 재개(Resume) |
| **연구자** | 대화 기록을 연구 자산으로 축적, Obsidian Vault 연동 |
| **지식 노동자** | 로컬 우선으로 민감 데이터 보호, 감사 추적(Audit Trail) 가능 |

---

## 3. 주요 기능 (Key Features)

### 3.1 세션 관리
- **Multi-CLI 지원**: Claude Code, OpenCode, Antigravity
- **즉시 전환**: CLI 간 세션 캐싱으로 즉시 전환
- **세션 조직화**: 즐겨찾기, 고정, 사용자 정의 이름, 태그 시스템

### 3.2 검색 & 필터
- **전체 검색**: 세션 전체에서 키워드 검색
- **검색 연산자**: `title:`, `tag:`, `project:`, `content:` 지원
- **태그 필터링**: 태그별 세션 필터링

### 3.3 대시보드
- **세션 통계**: 전체 세션, 메시지, 토큰 요약
- **활동 캘린더**: GitHub 스타일 기여 히트맵
- **모델 분포**: AI 모델별 사용량 시각화

### 3.4 사용량 모니터링
- **ccusage 연동**: 일간/주간/월간 리포트
- **내장 모니터링**: 실시간 사용량 + Burn Rate 예측 차트
- **claude-monitor 지원**: 5시간 빌링 블록 뷰

### 3.5 AI 통합
- **다중 API 지원**: OpenAI, Anthropic, Gemini, Grok
- **세션 요약**: AI 기반 자동 요약 생성
- **Obsidian 연동**: Vault로 노트 내보내기

---

## 4. 지원 CLI 도구 (Supported CLI Tools)

| CLI 도구 | 데이터 경로 | 상태 |
|----------|-------------|------|
| **Claude Code** | `~/.claude/projects/*/sessions/*.jsonl` | ✅ 지원 |
| **OpenCode** | `~/.opencode/sessions/*.jsonl` | ✅ 지원 |
| **Antigravity** | `~/.opencode/sessions/*.jsonl` | ✅ 지원 |

---

## 5. 시스템 요구사항 (Requirements)

| 항목 | 요구사항 |
|------|----------|
| **운영체제** | macOS 14.0 (Sonoma) 이상 |
| **프로세서** | Apple Silicon (M1/M2/M3) 또는 Intel |
| **메모리** | 4GB RAM 이상 권장 |
| **저장공간** | 100MB 이상 |

### 선택적 CLI 도구
```bash
# ccusage (Node.js) - 사용량 모니터링
npm install -g ccusage
# 또는 npx ccusage@latest

# claude-monitor (Python) - 실시간 모니터링
pip install claude-monitor
# 또는 uv tool install claude-monitor
```

---

## 6. 타겟 사용자 (Target Users)

### 6.1 주요 페르소나

| 페르소나 | 설명 | 핵심 니즈 |
|----------|------|-----------|
| **개발자** | Claude Code, Cursor 등으로 코딩하는 사용자 | 코드 세션 검색, 스니펫 재사용, 빠른 탐색 |
| **연구자** | AI로 문헌 리뷰, 분석하는 학자/연구원 | 대화 기록 축적, Obsidian 연동, 근거 추적 |
| **지식 노동자** | AI로 기획, 문서 작성하는 직장인 | 작업 이력 관리, 재개, 마크다운 복사 |
| **PKM 파워유저** | Obsidian 등 PKM 시스템 운영자 | Vault 연동, 노트 자동 생성, 백링크 |

### 6.2 사용자 세그먼트

| 세그먼트 | 비중 | 특징 |
|----------|------|------|
| **Primary** | 60% | 개발자, CLI 친화, 단축키 선호 |
| **Secondary** | 25% | 연구자, Obsidian 사용자, 지식 관리 중시 |
| **Tertiary** | 15% | 일반 지식 노동자, GUI 선호 |

---

## 7. 브랜드 체계 (Brand System)

### 7.1 CommandSpace 아키텍처
```
CommandSpace (마스터 브랜드)
├── CMDS (방법론/운영 모델)
├── CMDSPACE (Control Plane/플랫폼)
└── CmdTrace (세션 추적 도구) ← 현재 제품
```

### 7.2 표기 규칙

| 맥락 | 표기 | 예시 |
|------|------|------|
| **공식 브랜드명** | CmdTrace | "CmdTrace를 소개합니다" |
| **로고/배너** | CMD Trace | 시각물 전용 |
| **CLI/코드** | cmdtrace | `cmdtrace://session/{id}` |
| **발음** | 씨엠디 트레이스 | 구두 커뮤니케이션 |

---

## 8. 차별화 요소 (Differentiators)

| 차별점 | 설명 |
|--------|------|
| **Local-first** | 모든 데이터 로컬 저장, 프라이버시 완전 보장 |
| **Native Performance** | Swift/SwiftUI 기반 macOS 네이티브, 빠른 성능 |
| **Multi-CLI** | 다양한 AI CLI 도구 통합 지원 |
| **Usage Monitoring** | 내장 사용량 모니터링 + Burn Rate 예측 |
| **Obsidian Native** | Obsidian Vault와 네이티브 연동 |
| **Developer UX** | 키보드 중심, CLI 감각, 빠른 검색 |

---

## 9. 버전 정보 (Version)

| 항목 | 내용 |
|------|------|
| **현재 버전** | v2.1.0-alpha |
| **출시일** | 2025년 |
| **라이선스** | Proprietary (CMDSPACE) |
| **문의** | johnfkoo951@gmail.com |

---

## 10. 관련 링크

- [GitHub Repository](https://github.com/johnfkoo951/CmdTrace)
- [사용 설명서](USER-GUIDE.md)
- [기술 사양서](TECHNICAL-SPEC.md)

---

*Copyright (c) 2025 CMDSPACE. All Rights Reserved.*
