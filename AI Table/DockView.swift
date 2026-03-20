import SwiftUI

struct DockView: View {
    @State private var hasGeminiKey = false
    @State private var hasGroqKey = false
    @State private var hasClaudeKey = false
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 15) {
            Spacer()

            if isExpanded {
                Button(action: { openChat(agent: "Gemini") }) {
                    agentIcon(icon: "sparkles", color: SwiftUI.Color.blue, hasKey: hasGeminiKey)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity).combined(with: .offset(y: 20)))

                Button(action: { openChat(agent: "Groq") }) {
                    agentIcon(icon: "bolt.fill", color: .orange, hasKey: hasGroqKey)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity).combined(with: .offset(y: 20)))

                // Claude 버튼은 커스텀 이미지를 사용
                Button(action: { openChat(agent: "Claude") }) {
                    agentIcon(icon: "claude_logo", color: .white, hasKey: hasClaudeKey, isCustom: true)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity).combined(with: .offset(y: 20)))
            }

            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(SwiftUI.Color.black.opacity(0.3))
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
        }
        .frame(width: 80, height: 250)
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

    // 커스텀 아이콘을 사용할지 여부를 선택합니다.
    func agentIcon(icon: String, color: SwiftUI.Color, hasKey: Bool, isCustom: Bool = false) -> some View {
        ZStack {
            Circle()
                .fill(hasKey ? color.opacity(0.8) : SwiftUI.Color.red.opacity(0.8))
                .frame(width: 50, height: 50)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(radius: 5)

            if hasKey {
                if isCustom {
                    // Assets에 넣은 커스텀 이미지를 표시
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                } else {
                    Image(systemName: icon).font(.title3).foregroundColor(.white)
                }
            } else {
                Image(systemName: "key.fill").font(.title3).foregroundColor(.white)
            }
        }
    }

    func checkKeys() {
        let keys = KeyManager.loadAll()
        hasGeminiKey = !keys.gemini.isEmpty
        hasGroqKey = !keys.groq.isEmpty
        hasClaudeKey = !keys.claude.isEmpty
    }
}
