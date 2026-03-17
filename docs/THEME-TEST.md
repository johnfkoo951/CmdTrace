# Markdown 렌더링 테스트

| 항목 | 내용 |
|------|------|
| 목적 | md-to-pdf report 테마의 마크다운 렌더링 검증 |
| 작성일 | 2026-03-15 |

---

## 1. 인라인 서식

일반 텍스트에 **볼드**, *이탤릭*, ***볼드 이탤릭***을 섞어 쓸 수 있다. `인라인 코드`는 모노스페이스로 표시된다. 링크는 [Google](https://google.com)처럼 표현하고, 위키링크는 [[노트 이름]]이나 [[원본|별칭]]으로 쓴다.

---

## 2. 제목 계층

### 2.1 H3 제목

#### 2.1.1 H4 제목 (Report 테마에서 uppercase)

일반 본문 텍스트가 여기에 온다.

---

## 3. 테이블

### 3.1 기본 테이블

| 이름 | 역할 | 상태 |
|------|------|------|
| AppState.swift | 글로벌 상태 관리 | 완료 |
| SessionService.swift | JSONL 파싱 | 완료 |
| CloudSyncService.swift | iCloud 동기화 | 진행중 |

### 3.2 넓은 테이블 (컬럼 많음)

| 버전 | 날짜 | 주요 변경 | 파일 수 | 라인 변경 | 상태 | 비고 |
|------|------|-----------|---------|-----------|------|------|
| v2.0.0 | 2026-01-13 | 초기 빌드 | 12 | +3,200 | 릴리즈 | 첫 커밋 |
| v2.1.0 | 2026-01-14 | API 호환 | 18 | +2,100 | 릴리즈 | 공개 배포 |
| v2.4.2 | 2026-03-15 | 성능 최적화 | 44 | +14,800 | 릴리즈 | 현재 버전 |

### 3.3 코드가 포함된 테이블

| 함수 | 설명 | 반환값 |
|------|------|--------|
| `filterSessions()` | 검색 필터 적용 | `[Session]` |
| `saveUserData()` | 500ms 디바운스 저장 | `Void` |
| `generateSummary(for:)` | AI 요약 생성 | `String?` |

---

## 4. 리스트

### 4.1 순서 없는 리스트

- 첫 번째 항목
- 두 번째 항목
  - 중첩 항목 A
  - 중첩 항목 B
- 세 번째 항목

### 4.2 순서 있는 리스트

1. 빌드 확인 (`swift build`)
2. 버전 업데이트
3. 커밋 및 푸시
4. 앱 번들 생성 (`./build-app.sh`)
5. Applications 배포

### 4.3 체크리스트

- [x] 검색 디바운스 구현
- [x] 저장 디바운스 구현
- [x] JSONL 파싱 최적화
- [ ] Cloud Sync 백엔드
- [ ] Menu Bar App

---

## 5. 코드 블록

인라인 코드: `let x = 42`

```swift
// Swift 코드 블록
@Observable
final class AppState {
    var sessions: [Session] = []
    var searchText: String = "" {
        didSet { debouncedSearch() }
    }

    private func debouncedSearch() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            filterSessions()
        }
    }
}
```

```bash
# 쉘 명령어
swift build
./build-app.sh
cp -r ./build/CmdTrace.app /Applications/
```

---

## 6. 인용문 (Blockquote)

> 이것은 일반적인 인용문이다.
> 여러 줄로 이어질 수 있다.

> **참고**: 볼드가 포함된 인용문도 가능하다. `코드`도 섞을 수 있다.

---

## 7. 콜아웃 블록

> [!info] 정보
> 이 문서는 md-to-pdf 스킬의 report 테마 렌더링을 검증하기 위한 테스트 문서입니다.

> [!tip] 팁
> report 테마는 좌측 정렬 커버, 무배경 테이블 헤더, uppercase h4를 특징으로 합니다.

> [!warning] 주의
> 기존 5개 테마(default, academic, minimal, warm, editorial)는 색상만 다르고 레이아웃은 동일합니다. 추후 개선이 필요합니다.

> [!danger] 위험
> API 키가 설정되지 않은 상태에서 AI Summary를 실행하면 에러가 발생합니다.

---

## 8. 수평선과 구분

위 내용과 아래 내용 사이에 수평선(`---`)을 사용한다.

---

아래는 새로운 섹션이다.

---

## 9. 긴 텍스트 (줄바꿈/단어 분리)

CmdTrace는 macOS 네이티브 SwiftUI 앱으로, CLI 기반 AI 코딩 어시스턴트의 대화 기록을 JSONL 형식에서 파싱하여 세션 탐색, 태그 관리, 사용량 모니터링, AI 기반 컨텍스트 요약 등 다양한 기능을 제공합니다. `enumerateSubstrings(in:options:.byLines)` 메서드를 활용한 메모리 효율적 라인 이터레이션, `DispatchQueue.global(qos: .utility)` 기반 백그라운드 I/O, 300ms/500ms 디바운싱 패턴 등 성능 최적화가 v2.4.2에서 적용되었습니다.

영문 긴 텍스트: The `SessionService` actor handles all JSONL file parsing with memory-efficient line iteration using `enumerateSubstrings`. It pre-allocates message arrays with `reserveCapacity` based on the known `messageCount` from session metadata, avoiding unnecessary array resizing during parsing.

---

## 10. 혼합 표현

### 핵심 아키텍처 결정사항

| 결정 | 근거 | 대안 |
|------|------|------|
| **`@Observable`** 사용 | SwiftUI 네이티브 통합, 보일러플레이트 감소 | `ObservableObject` + `@Published` |
| **JSON 파일 저장** | 단순성, 디버깅 용이 | SQLite, CoreData |
| **Actor 기반 서비스** | 동시성 안전, 데이터 레이스 방지 | GCD + Lock |

> [!info] 설계 원칙
> - 단일 진실 원천 (AppState)
> - 읽기 전용 세션 파일 + 별도 메타데이터 저장
> - 디바운싱으로 불필요한 I/O 최소화

**다음 단계**:
1. Cloud Sync 백엔드 구현 (`CloudKit`)
2. Menu Bar App 개발
3. `ConfigurationView.swift` 분리 리팩토링

---

*문서 끝*
