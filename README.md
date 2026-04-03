# 🚀 AI Table 개발 기록 (2026-03-21)

> **"Native의 성능과 개인정보 보안에 집착한 macOS 전용 지능형 워크스테이션"**

## 1. 🛠 핵심 구현 기능 (Key Features)

| 기능 | 상세 기술 (Technical Detail) | 사용자 경험 (UX) |
| :--- | :--- | :--- |
| **LLM 사대천왕 통합** | `AsyncSequence` 기반 OpenAI, Claude, Gemini, Groq API 완벽 연동 | 타자기 효과로 체감 대기 시간 0초 구현 |
| **Dynamic Model Switching** | `@AppStorage`를 활용한 실시간 모델(gpt-4o, gemma 등) 전환 | 상황에 맞는 최적의 AI 모델 즉각 선택 |
| **Control Center Dock** | `ultraThinMaterial` 블러 엣지가 적용된 리스트형 에이전트 뷰 | 모델명과 아이콘을 직관적으로 확인 |
| **BYOK Biometric Security** | **Touch ID** 연동 설정창 보호 및 Keychain 물리 암호화 | 외부 OAuth 없이 완벽한 프라이버시 확보 |
| **Window Orchestration** | `AppKit` 기반 글로벌 단축키(`Opt+Space`) 제어 및 투명 창 관리 | 부드러운 Fade-in/out 및 작업 방해 최소화 |
| **Real-time Auto Scroll** | `ScrollViewReader` & `bottom_anchor` 기반 동적 추적 | 대화가 길어져도 항상 최신 응답 노출 |

---

## 2. ⚡️ 주요 트러블슈팅 (Troubleshooting)

### ✅ Gemma Model 400 Bad Request 해결
- **Issue:** 구글 API 사용 시 `gemma` 계열 모델에 `system_instruction` 파라미터를 포함하면 서버가 400 에러를 반환하며 연결을 거부함.
- **Solution:** `model.contains("gemma")` 판독기를 추가하여, 해당 모델일 경우 JSON 파라미터에서 `system_instruction`을 `nil`로 날려버리고 첫 번째 유저 메시지 텍스트에 시스템 프롬프트를 강제 병합하여 전송하는 방식으로 우회.

### ✅ API 아키텍처 규격 통일 및 파편화 해결
- **Issue:** 각 LLM(OpenAI, Anthropic, Google)의 API 규격과 스트리밍 응답(SSE) 방식이 달라 메인 View의 비즈니스 로직이 뚱뚱해짐.
- **Solution:** 모든 API 연동 로직을 독립된 Singleton 클래스로 분리. `AsyncThrowingStream<String, Error>` 리턴 타입과 `[ChatMessage]` 파라미터 규격을 완벽히 통일하여 뷰 단의 분기문을 단일 `for await` 루프로 압축 최적화.

### ✅ 투명 UI (NSWindow) Frame Clipping 현상
- **Issue:** 에이전트가 4개로 늘어나고 리스트 뷰로 UI를 마개조하면서, 기존 300px로 하드코딩된 투명 창 밖으로 뷰가 삐져나가 상단부가 잘리는 현상 발생.
- **Solution:** `AppDelegate`의 `NSRect` height와 `DockView`의 frame height를 450으로 동기화하여 여유 공간 확보.

### ✅ AppKit Runtime Crash 및 Window Ghosting 해결
- **Issue:** 뷰 동적 제거 시 상단 탭 바 렌더링 누락 크래시 및 창 띄우기 타이밍 꼬임 발생.
- **Solution:** `TabView` 상시 유지 후 `overlay` 덮어쓰기 적용. `DispatchQueue.main.asyncAfter`를 통한 0.05s 마이크로 딜레이로 윈도우 서버 애니메이션 인지 시간 확보.

---

## 3. 🔑 코드 아키텍처 (Core Logic)
- **Language:** Swift 6.0 (SwiftUI / AppKit)
- **Security:** Apple Keychain Services (API Key Encryption) + AES-GCM encrypted local chat history storage
- **Network:** `URLSession.bytes` 기반의 서버 사이드 이벤트(SSE) 파싱

---

## 4. 🎯 Next Roadmap: Agent Cowork
- [ ] **Unified Memory:** 모든 모델이 동일한 컨텍스트(대화 내역)를 공유하는 통합 DB 설계.
- [ ] **Sequential Relay:** 기획(Gemini) -> 구현(Claude) -> 검수(Groq)로 이어지는 자동화 파이프라인.
- [ ] **Orchestrator:** 마스터 AI가 과업을 판단하고 서브 에이전트에게 업무를 할당하는 로직 개발.
