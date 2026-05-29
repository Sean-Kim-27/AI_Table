# AI_Table 에이전트 오케스트레이션 최종 플랜

> 기반 자료: Obsidian vault `agents/` + `skills/` (planner/architect/loop-operator/harness-optimizer/security-reviewer 및 meta‑orchestration toml, context-budget/iterative-retrieval/cost-aware-llm-pipeline/verification-loop/swift‑actor‑persistence/swift‑concurrency‑6‑2/swiftui‑patterns)

---

## 1) 목표
- 앱 내부에서 **멀티 에이전트 오케스트레이션** 제공
- UI/UX는 복잡도를 숨기고, **작업 흐름을 단계별로 명확화**
- 토큰 비용을 **최소화**하면서도 결과 품질 유지

---

## 2) 설계 원칙 (합의)
- **Hub‑and‑Spoke**: 오케스트레이터만 풀 컨텍스트 보유, 서브에이전트는 최소 패킷만
- **Context Budget**: 토큰 예산 분배 고정 (정책/제약/메모리/검색/여유)
- **Iterative Retrieval**: 3회 이하 점진 검색 + Top‑K + re-rank 임계값
- **Summary‑on‑Threshold**: 매턴 요약 금지, 임계치 초과 시에만 요약 생성
- **Verification Loop**: 오케스트레이션 완료 후 검증 게이트 필수

---

## 3) 아키텍처 (SwiftUI/AppKit 기준)

### Core Modules
- **Orchestrator (actor)**
  - 작업 그래프 생성/실행/결과 통합
- **TaskRouter**
  - 작업 분류 → 에이전트/모델 라우팅
- **AgentRegistry**
  - 에이전트 능력/권한/툴 메타 관리
- **PolicyEngine**
  - 비용/지연/보안 정책
- **ProviderManager**
  - OpenAI/Claude/Gemini/Groq 선택 + fallback
- **ContextManager**
  - 서브에이전트용 **컴팩트 컨텍스트 패킷** 생성
- **TaskDistributor**
  - 병렬 분해 + ownership 확정
- **Stores**
  - TaskStore / ConversationStore / SettingsStore

### Concurrency & Persistence
- Orchestrator 및 저장소는 **Swift actor** 기반
- Swift 6.2 Approachable Concurrency 원칙 적용

---

## 4) UI/UX 플로우

### Navigation
- Sidebar: Workspaces / Runs
- Main tabs: **Orchestrate / History**

### Orchestrate Flow
1) **Task Definition**
   - 제목/요약, 입력/첨부, 제약, 출력형식
2) **Agent Selection**
   - Auto‑assign 기본
   - Manual: 카드 드래그 & 드롭
3) **Run & Progress**
   - Subtask lane별 상태 + 로그 스트림
4) **Results**
   - 요약 + subtask 결과 + 아티팩트

---

## 5) 토큰/비용 최소화 전략

### Context Packing 순서
1. Task Header (목표/출력)
2. 제약 요약
3. Top‑K 검색 결과
4. State Snapshot

### 캐싱
- Prompt Cache
- Retrieval Cache
- Summary Cache

### 비용 제어
- 비용/지연 기준으로 모델 자동 라우팅
- Retry는 transient 에러만

---

## 6) 검증 게이트 (Verification Loop)
- Build
- Lint
- Tests
- Security scan
- Diff review

---

## 7) 구현 단계 (MVP → 확장)

### Phase 1 — MVP
- Orchestrator actor
- ProviderManager (OpenAI/Claude)
- AgentRegistry (Writer/Research)
- Orchestrate 탭 + Progress UI

### Phase 2 — Multi‑Agent 확장
- TaskDistributor + ContextManager
- Agent Pool 확장 (Planner/Architect/Reviewer)
- History/Run 복기 뷰

### Phase 3 — 비용/성능 최적화
- Context Budget Manager
- Iterative Retrieval
- Cache 레이어

### Phase 4 — Advanced Orchestration
- DAG 작업 분해
- 자동 회복/재시도 정책
- Loop Operator 가드레일

---

## 8) 위험요소 & 대응
- **토큰 폭발** → Hub‑and‑Spoke + Budget
- **에이전트 중복** → TaskDistributor에서 ownership 고정
- **컨텍스트 부족** → Iterative Retrieval
- **장기 실행 루프 리스크** → Loop Operator 규칙 적용

---

## 9) 산출물
- 이 문서 (orchestration-plan.md)
- 이후 설계 문서: JSON schema / DB 설계 / 에이전트 템플릿

---

## 다음 액션
- 원하시면 위 플랜을 기준으로 **파일 구조 / 데이터 모델 / 컨텍스트 패킷 JSON schema**까지 바로 작성합니다.
