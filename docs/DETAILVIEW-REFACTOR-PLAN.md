# DetailView.swift 분리 계획

## 현재 상태
- **파일 크기**: 4,664줄
- **문제점**: 단일 파일에 너무 많은 뷰와 로직이 혼재

## 분리 계획

### Phase 1: 독립적인 대형 뷰 분리 (우선순위 높음)

| 새 파일 | 포함 내용 | 예상 줄 수 | 원본 위치 |
|---------|----------|-----------|----------|
| `DashboardView.swift` | DashboardView, DashboardInspectorPanel | ~500줄 | line 1889-2182 |
| `NativeMonitorView.swift` | NativeMonitorView, MonitorData, BurnRateChartView, MonitorBarView, ColorCustomizationView | ~700줄 | line 3492-4264 |
| `UsageViews.swift` | UsageSection, ClaudePlan, UsageStatCard, DailyUsageRow, MonthlyUsageRow, BlockUsageRow, ModelBreakdownRow, UsageToolsSection, UsageToolCard, PlanBadge | ~700줄 | line 2183-2884 |

### Phase 2: 중형 뷰 분리 (우선순위 중간)

| 새 파일 | 포함 내용 | 예상 줄 수 | 원본 위치 |
|---------|----------|-----------|----------|
| `InspectorPanelView.swift` | InspectorPanel (세션 인스펙터) | ~1000줄 | line 722-1740 |
| `SessionHeaderView.swift` | SessionHeader, 관련 헬퍼 메서드 | ~400줄 | line 140-520 |
| `MarkdownTextView.swift` | MarkdownText (마크다운 렌더링) | ~300줄 | line 3221-3491 |
| `SessionInsightsView.swift` | SessionInsightsSection, InsightMetricView, TokenUsageView, ToolUsageView, ModelUsageView, SessionConfigUsageSection | ~300줄 | line 4292-끝 |

### Phase 3: 소형 뷰 및 유틸리티 분리 (우선순위 낮음)

| 새 파일 | 포함 내용 | 예상 줄 수 | 원본 위치 |
|---------|----------|-----------|----------|
| `InteractionView.swift` | InteractionView, AIInspectorPanel, APIStatusRow | ~200줄 | line 2886-3056 |
| `MessageViews.swift` | MessageBubble, HighlightedText | ~150줄 | line 1741-1888 |
| `HelperViews.swift` | RibbonButton, InfoRow, ResumeButton, QuickActionButton, SectionHeader, StatCard | ~200줄 | line 521-720, 2678-2705 |
| `ModelDisplayUtils.swift` | ModelDisplayUtils enum | ~30줄 | line 4-34 |

### Phase 4: Models 폴더로 이동

| 새 파일 | 포함 내용 | 예상 줄 수 | 원본 위치 |
|---------|----------|-----------|----------|
| `Models/UsageData.swift` | UsageData, UsageViewMode, 관련 nested types | ~200줄 | line 3057-3220 |
| `Models/MonitorData.swift` | MonitorData, ProjectionPoint | ~30줄 | line 3926-3949, 4149-4155 |

## 분리 후 DetailView.swift 구조

```swift
// DetailView.swift (~200줄)
import SwiftUI

struct DetailView: View { ... }
struct SessionDetailView: View { ... }
struct ConversationView: View { ... }

// Resume 관련 전역 함수
func executeResumeSession(...) { ... }
func runOsascriptGlobal(...) { ... }
```

## 분리 순서 (권장)

1. **DashboardView.swift** - 가장 독립적, 의존성 적음
2. **NativeMonitorView.swift** - 독립적, MonitorData 포함
3. **UsageViews.swift** - UsageData 의존성 있음
4. **Models/UsageData.swift** - 3번과 함께 진행
5. **InspectorPanelView.swift** - 복잡하지만 분리 가능
6. **나머지** - 점진적 분리

## 주의사항

1. **Import 관리**: 분리된 파일에서 필요한 import 확인
2. **접근 제어**: internal 유지 (같은 모듈)
3. **테스트**: 각 분리 후 빌드 테스트 필수
4. **의존성**: 순환 의존성 주의

## 예상 결과

| 파일 | 예상 줄 수 |
|------|-----------|
| DetailView.swift | ~200줄 |
| DashboardView.swift | ~500줄 |
| NativeMonitorView.swift | ~700줄 |
| UsageViews.swift | ~700줄 |
| InspectorPanelView.swift | ~1000줄 |
| SessionHeaderView.swift | ~400줄 |
| MarkdownTextView.swift | ~300줄 |
| SessionInsightsView.swift | ~300줄 |
| InteractionView.swift | ~200줄 |
| MessageViews.swift | ~150줄 |
| HelperViews.swift | ~200줄 |
| ModelDisplayUtils.swift | ~30줄 |
| Models/UsageData.swift | ~200줄 |
| Models/MonitorData.swift | ~30줄 |

**총 14개 파일로 분리, 각 파일 200-1000줄 범위 유지**
