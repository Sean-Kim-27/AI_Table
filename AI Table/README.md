# 🚀 AI Table 개발 기록 (2026-03-21)

> **"Native의 성능과 개인정보 보안에 집착한 macOS 전용 지능형 워크스테이션"**

## 1. 🛠 핵심 구현 기능 (Key Features)

| 기능 | 상세 기술 (Technical Detail) | 사용자 경험 (UX) |
| :--- | :--- | :--- |
| **Multi-LLM Streaming** | `AsyncSequence` 기반 Groq, Claude, Gemini API 병렬 연동 | 타자기 효과로 체감 대기 시간 0초 구현 |
| **Real-time Auto Scroll** | `ScrollViewReader` & `bottom_anchor` 기반 동적 추적 | 대화가 길어져도 항상 최신 응답 노출 |
| **Biometric Security** | **Touch ID (LocalAuthentication)** 연동 설정창 보호 | API Key 등 민감 정보의 물리적 보안 확보 |
| **Stealth Mode** | `UIElement` 설정을 통한 Dock 제거 및 Menu Bar 상주 | 작업 방해 최소화 및 빠른 접근성 제공 |
| **Window Orchestration** | `AppKit` 기반 글로벌 단축키(`Opt+Space`) 제어 | 부드러운 Fade-in/out 애니메이션 최적화 |

---

## 2. ⚡️ 주요 트러블슈팅 (Troubleshooting)

### ✅ AppKit Runtime Crash 해결
- **Issue:** 인증 전후로 `TabView` 구조를 동적으로 제거 시 시스템이 상단 탭 바를 렌더링하지 못해 크래시 발생.
- **Solution:** `TabView` 뼈대는 상시 유지하되, 미인증 상태에서는 `overlay`와 `windowBackgroundColor`를 활용해 UI를 완전히 가리는 방식으로 전환하여 안정성 확보.

### ✅ 스트리밍 시 UI Flickering(빈 말풍선) 방지
- **Issue:** 서버 응답 전 생성된 빈 메시지 객체가 회색 말풍선으로 노출되어 시각적 노이즈 발생.
- **Solution:** `MessageRowView` 내부에서 `!text.isEmpty` 조건부 렌더링을 적용, 데이터 수신 시점에 말풍선이 나타나도록 UX 개선.

### ✅ Window Animation Ghosting 해결
- **Issue:** 창 활성화(`makeKeyAndOrderFront`)와 애니메이션 명령이 동시에 실행되어 페이드 효과가 무시되는 현상.
- **Solution:** `DispatchQueue.main.asyncAfter`로 **0.05s의 마이크로 딜레이**를 삽입하여 윈도우 서버가 투명 상태를 인지할 시간을 확보함으로써 해결.

---

## 3. 🔑 코드 아키텍처 (Core Logic)
- **Language:** Swift 6.0 (SwiftUI / AppKit)
- **Security:** Apple Keychain Services (API Key Encryption)
- **Network:** `URLSession.bytes` 기반의 서버 사이드 이벤트(SSE) 파싱

---

## 4. 🎯 Next Roadmap: Agent Cowork
- [ ] **Unified Memory:** 모든 모델이 동일한 컨텍스트를 공유하는 통합 DB 설계.
- [ ] **Sequential Relay:** 기획(Gemini) -> 구현(Claude) -> 검수(Groq)로 이어지는 자동화 파이프라인.
- [ ] **Orchestrator:** 마스터 AI가 과업을 판단하고 서브 에이전트에게 업무를 할당하는 로직 개발.
