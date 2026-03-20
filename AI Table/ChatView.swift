import SwiftUI
import MarkdownUI
import AppKit

// 스크롤뷰 안에서 텍스트 선택(복사)이 막히는 문제를 완화
extension View {
    func enableTextSelection() -> some View {
        if #available(macOS 12.0, *) {
            return self.textSelection(.enabled)
        } else {
            return self
        }
    }
}

struct ChatView: View {
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isThinking = false
    @FocusState private var isInputFocused: Bool
    @State private var eventMonitor: Any?
    @AppStorage("active_agent") private var activeAgent = "Gemini"
    @AppStorage("gemini_model") private var geminiModel = "gemini-3.1-flash-preview"
    @AppStorage("groq_model") private var groqModel = "openai/gpt-oss-120b"
    @AppStorage("claude_model") private var claudeModel = "claude-3-7-sonnet-20250219"
    @AppStorage("openai_model") private var openAIModel = "gpt-5.4"
    @AppStorage("max_history") private var maxHistory = 10
    @State private var showClearAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // 상단 헤더
            HStack {
                // 에이전트 이름 표시
                Text(activeAgent == "Gemini" ? "Google (\(geminiModel))" :
                        (activeAgent == "Groq" ? "Groq (\(groqModel))" :
                            (activeAgent == "OpenAI" ? "OpenAI (\(openAIModel))" : "Claude (\(claudeModel))")))
                .font(.headline)
                .foregroundColor(.white)

                Spacer()

                // --- 안전장치 달린 초기화 버튼 ---
                Button(action: {
                    showClearAlert = true
                }) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .alert("초기화 확인", isPresented: $showClearAlert) {
                    Button("모두 삭제", role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            messages.removeAll()
                        }
                        saveMessages()
                    }
                    Button("취소", role: .cancel) { }
                } message: {
                    Text("지금까지의 대화가 모두 삭제됩니다. 계속하시겠습니까?")
                }

                // 닫기 버튼
                Button(action: { NotificationCenter.default.post(name: Notification.Name("ToggleChatWindow"), object: nil) }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray).font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(SwiftUI.Color.black.opacity(0.2))

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // 메시지 목록 렌더링
                        ForEach(messages, id: \.id) { (msg: ChatMessage) in
                            MessageRowView(msg: msg)
                        }

                        if isThinking {
                            HStack {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Spacer()
                            }
                        }

                        SwiftUI.Color.clear
                            .frame(height: 1)
                            .id("bottom_anchor")
                    }
                    .padding()
                }
                .onChange(of: messages.last?.text) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("bottom_anchor", anchor: .bottom)
                    }
                }
                .onChange(of: messages.count) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom_anchor", anchor: .bottom)
                    }
                }
                .onChange(of: isThinking) {
                    withAnimation {
                        proxy.scrollTo("bottom_anchor", anchor: .bottom)
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo("bottom_anchor", anchor: .bottom)
                    }
                }
            }

            // 하단 입력창
            HStack {
                TextField("메시지를 입력하세요... (Shift+Enter로 줄바꿈)", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(SwiftUI.Color.black.opacity(0.3))
                    .cornerRadius(8)

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(inputText.isEmpty || isThinking ? .gray : .blue)
                        .padding(10)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || isThinking)
            }
            .padding()
        }
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .onAppear {
            loadMessages()

            // 키보드 입력 감시 (Shift+Enter)
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if isInputFocused && event.keyCode == 36 {
                    if event.modifierFlags.contains(.shift) {
                        inputText += "\n"
                        return nil
                    } else {
                        sendMessage()
                        return nil
                    }
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ToggleChatWindow"))) { notification in
            if let agentName = notification.object as? String {
                if activeAgent != agentName {
                    activeAgent = agentName
                    loadMessages()
                }
            }
        }
    }

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let userText = inputText
        inputText = ""

        // 사용자 메시지를 먼저 추가해 이번 요청에 포함합니다.
        messages.append(ChatMessage(text: userText, isUser: true))
        saveMessages()
        isThinking = true

        let chatHistory = messages.count > maxHistory ? Array(messages.suffix(maxHistory)) : messages

        Task {
            do {
                // AI 응답용 빈 메시지를 먼저 추가합니다.
                await MainActor.run {
                    messages.append(ChatMessage(text: "", isUser: false))
                }
                let aiMessageIndex = messages.count - 1

                let stream: AsyncThrowingStream<String, Error>

                // 스트리밍 전용 함수로 호출합니다.
                if activeAgent == "Gemini" {
                    stream = try await GeminiAPI.shared.sendMessageStream(history: chatHistory, model: geminiModel)
                } else if activeAgent == "Groq" {
                    stream = try await GroqAPI.shared.sendMessageStream(history: chatHistory, model: groqModel)
                } else if activeAgent == "OpenAI" {
                    stream = try await OpenAIAPI.shared.sendMessageStream(history: chatHistory, model: openAIModel)
                } else {
                    stream = try await ClaudeAPI.shared.sendMessageStream(history: chatHistory, model: claudeModel)
                }

                // 로딩 애니메이션 종료
                await MainActor.run { isThinking = false }

                // 스트림에서 들어오는 조각을 실시간으로 누적합니다.
                for try await chunk in stream {
                    await MainActor.run {
                        messages[aiMessageIndex].text += chunk
                    }
                }

                // 완료 후 저장
                await MainActor.run { saveMessages() }

            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(text: "에러가 발생했습니다: \(error.localizedDescription)", isUser: false))
                    isThinking = false
                }
            }
        }
    }

    func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(encoded, forKey: "chat_history_\(activeAgent)")
        }
    }

    func loadMessages() {
        if let data = UserDefaults.standard.data(forKey: "chat_history_\(activeAgent)"),
           let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = decoded
        } else {
            messages = []
        }
    }
}

// 컴파일러 부담을 줄이기 위해 말풍선 뷰를 분리합니다.
struct MessageRowView: View {
    let msg: ChatMessage

    var body: some View {
        HStack {
            if msg.isUser {
                Spacer()
                Text(msg.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(SwiftUI.Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // 텍스트가 비어있지 않을 때만 말풍선을 표시합니다.
                if !msg.text.isEmpty {
                    Markdown(msg.text)
                        .markdownTheme(.aiDockTheme)
                        .enableTextSelection()
                        .padding(15)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(SwiftUI.Color.white.opacity(0.1))
                                .frame(maxWidth: .infinity)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
        }
    }
}
