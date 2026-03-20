import SwiftUI
import KeyboardShortcuts
import LocalAuthentication

struct SettingsView: View {
    @State private var openAIKey = ""
    @State private var geminiKey = ""
    @State private var groqKey = ""
    @State private var claudeKey = ""
    @State private var isSaved = false
    
    @State private var isUnlocked = false
    
    @AppStorage("groq_model") private var groqModel = "openai/gpt-oss-120b"
    @AppStorage("claude_model") private var claudeModel = "claude-3-7-sonnet-20250219"
    @AppStorage("system_prompt") private var systemPrompt = "너는 친절하고 똑똑한 AI 조수야."
    @AppStorage("max_history") private var maxHistory = 10
    
    let groqModels = ["openai/gpt-oss-120b", "llama-3.3-70b-versatile", "qwen/qwen3-32b", "openai/gpt-oss-20b", "meta-llama/llama-4-scout-17b-16e-instruct"]
    let claudeModels = ["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5-20251001", "claude-opus-4-5-20251101", "claude-sonnet-4-5-20250929", "claude-opus-4-1-20250805", "claude-opus-4-20250514", "claude-sonnet-4-20250514"]

    var body: some View {
        // TabView 구조를 유지해 안정성을 확보합니다.
        mainSettingsView
            .overlay(
                Group {
                    if !isUnlocked {
                        lockScreenView
                            // 설정 내용을 창 배경색으로 가려 노출을 방지합니다.
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(NSColor.windowBackgroundColor))
                    }
                }
            )
            .onAppear { authenticate() }
    }
    
    // --- 🔒 지문 인식 대기 화면 ---
    var lockScreenView: some View {
        VStack(spacing: 20) {
            Image(systemName: "touchid")
                .font(.system(size: 60))
                .foregroundColor(.pink)
                .symbolEffect(.pulse)
            
            Text("보안 영역")
                .font(.title3).bold()
            
            Text("API 키를 보려면 지문 인증을 해주세요.")
                .font(.caption)
                .foregroundColor(.gray)
            
            Button("암호 입력 / 다시 시도") { authenticate() }
                .buttonStyle(.bordered)
                .padding(.top, 10)
        }
    }
    
    // --- ⚙️ 진짜 설정 화면 ---
    var mainSettingsView: some View {
        VStack(spacing: 0) {
            TabView {
                // 연동 탭
                VStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("독 토글:").font(.subheadline).bold().frame(width: 70, alignment: .leading)
                                KeyboardShortcuts.Recorder("", name: .toggleDock)
                            }
                            Divider()
                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                                GridRow { Text("OpenAI:").font(.subheadline).frame(width: 70, alignment: .leading); SecureField("Key", text: $openAIKey).textFieldStyle(.roundedBorder).frame(width: 190) }
                                GridRow { Text("Gemini:"); SecureField("Key", text: $geminiKey).textFieldStyle(.roundedBorder).frame(width: 190) }
                                GridRow { Text("Groq Key:"); SecureField("Key", text: $groqKey).textFieldStyle(.roundedBorder).frame(width: 190) }
                                GridRow { Text("Groq 모델:"); Picker("", selection: $groqModel) { ForEach(groqModels, id: \.self) { Text($0) } }.labelsHidden().controlSize(.small).frame(width: 190) }
                                GridRow { Text("Claude Key:"); SecureField("Key", text: $claudeKey).textFieldStyle(.roundedBorder).frame(width: 190) }
                                GridRow { Text("Claude 모델:"); Picker("", selection: $claudeModel) { ForEach(claudeModels, id: \.self) { Text($0) } }.labelsHidden().controlSize(.small).frame(width: 190) }
                            }
                        }
                        .padding(20)
                    }
                }
                .tabItem { Label("연동", systemImage: "key.fill") }
                
                // 프롬프트 탭
                VStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("최근 대화 유지:").font(.subheadline).bold()
                                Stepper("", value: $maxHistory, in: 2...50).labelsHidden()
                                Spacer()
                                Text("\(maxHistory)개").foregroundColor(.blue).bold()
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 5) {
                                Text("시스템 프롬프트").font(.subheadline).bold()
                                TextEditor(text: $systemPrompt)
                                    .font(.system(size: 11))
                                    .frame(width: 280, height: 130)
                                    .padding(4)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            }
                        }
                        .padding(20)
                    }
                }
                .tabItem { Label("프롬프트", systemImage: "brain.head.profile") }
            }
            
            Divider()
            HStack {
                if isSaved { Text("저장 완료 !").foregroundColor(.green).font(.caption).bold() }
                Spacer()
                Button("저장") { saveKeys() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 340, idealWidth: 340, maxWidth: 340, minHeight: 460, idealHeight: 460, maxHeight: 460)
        .fixedSize()
    }
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "지문 또는 비밀번호를 입력해주세요."
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                        self.loadKeys()
                    } else {
                        print("인증을 실패하였습니다 : \(authError?.localizedDescription ?? "")")
                    }
                }
            }
        } else {
            print("이 맥북은 보안 설정이 안 되어있습니다.")
            self.isUnlocked = true
            self.loadKeys()
        }
    }
    
    func saveKeys() {
        KeyManager.saveAll(openai: openAIKey, gemini: geminiKey, groq: groqKey, claude: claudeKey)
        NotificationCenter.default.post(name: Notification.Name("APIKeysUpdated"), object: nil)
        withAnimation { isSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { isSaved = false } }
    }
    
    func loadKeys() {
        let keys = KeyManager.loadAll()
        openAIKey = keys.openai
        geminiKey = keys.gemini
        groqKey = keys.groq
        claudeKey = keys.claude
    }
}
