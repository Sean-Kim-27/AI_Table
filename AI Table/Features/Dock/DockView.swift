import SwiftUI

struct DockView: View {
    @State private var hasGeminiKey = false
    @State private var hasGroqKey = false
    @State private var hasClaudeKey = false
    @State private var isExpanded = false
    @State private var hasOpenAIKey = false
    
    // 🚨 설정창에서 저장한 모델명 실시간으로 훔쳐오기 썅! 🚨
    @AppStorage("gemini_model") private var geminiModel = "gemini-3.1-flash-preview"
    @AppStorage("openai_model") private var openAIModel = "gpt-5.4"
    @AppStorage("groq_model") private var groqModel = "openai/gpt-oss-120b"
    @AppStorage("claude_model") private var claudeModel = "claude-sonnet-4-6"
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 15) { // 무조건 오른쪽 정렬!
            Spacer()
            
            if isExpanded {
                // 🚨 에이전트 리스트 패널 🚨
                VStack(spacing: 0) {
                    agentListRow(agent: "OpenAI", model: openAIModel, icon: "brain", color: .green, hasKey: hasOpenAIKey, isCustom: false)
                                        Divider().background(Color.white.opacity(0.1))
                    agentListRow(agent: "Gemini", model: geminiModel, icon: "sparkles", color: .blue, hasKey: hasGeminiKey, isCustom: false)
                    Divider().background(Color.white.opacity(0.1)) // 찌익 선긋기
                    agentListRow(agent: "Groq", model: groqModel, icon: "bolt.fill", color: .orange, hasKey: hasGroqKey, isCustom: false)
                    Divider().background(Color.white.opacity(0.1))
                    agentListRow(agent: "Claude", model: claudeModel, icon: "claude_logo", color: .white, hasKey: hasClaudeKey, isCustom: true)
                }
                .background(.ultraThinMaterial) // 반투명 유리창 효과 썅!
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 원래 있던 동그란 메인 토글 버튼
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(radius: 5)
                    
                    Image(systemName: isExpanded ? "xmark" : "brain.head.profile")
                        .font(.title)
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10) // 토글 버튼 살짝 오른쪽으로 밀착
        }
        .frame(width: 250, height: 450, alignment: .bottomTrailing)
        .padding(.bottom, 20)
        .onAppear { checkKeys() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("APIKeysUpdated"))) { _ in checkKeys() }
    }
    
    func openChat(agent: String) {
        NotificationCenter.default.post(name: Notification.Name("ToggleChatWindow"), object: agent)
        withAnimation(.spring()) {
            isExpanded = false
        }
    }
    
    // 🚨 텍스트랑 아이콘 가로로 묶어주는 리스트 행 UI 🚨
    func agentListRow(agent: String, model: String, icon: String, color: Color, hasKey: Bool, isCustom: Bool) -> some View {
        Button(action: { openChat(agent: agent) }) {
            HStack(spacing: 12) {
                // 아이콘
                ZStack {
                    Circle()
                        .fill(hasKey ? color.opacity(0.8) : Color.red.opacity(0.8))
                        .frame(width: 40, height: 40)
                    
                    if hasKey {
                        if isCustom {
                            Image(icon).resizable().scaledToFit().frame(width: 20, height: 20).clipShape(Circle())
                        } else {
                            Image(systemName: icon).font(.body).foregroundColor(.white)
                        }
                    } else {
                        Image(systemName: "key.fill").font(.body).foregroundColor(.white)
                    }
                }
                
                // 텍스트 (이름 + 모델명)
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(model)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1) // 너무 길면 짤리게
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .contentShape(Rectangle()) // 빈 공간 눌러도 클릭되게 만듦 썅!
        }
        .buttonStyle(.plain)
    }
    
    func checkKeys() {
        let keys = KeyManager.loadAll()
        hasOpenAIKey = !keys.openai.isEmpty
        hasGeminiKey = !keys.gemini.isEmpty
        hasGroqKey = !keys.groq.isEmpty
        hasClaudeKey = !keys.claude.isEmpty
    }
}
