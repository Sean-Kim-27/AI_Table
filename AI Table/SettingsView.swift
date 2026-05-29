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
    
    @AppStorage("gemini_model") private var geminiModel = "gemini-3.1-flash-preview"
    @AppStorage("groq_model") private var groqModel = "openai/gpt-oss-120b"
    @AppStorage("claude_model") private var claudeModel = "claude-sonnet-4-6"
    @AppStorage("openai_model") private var openAIModel = "gpt-5.4"
    @AppStorage("system_prompt") private var systemPrompt = "너는 친절하고 똑똑한 AI 조수야."
    @AppStorage("max_history") private var maxHistory = 10
    
    // 🚨 니가 원한 대로 OpenAI랑 Gemini는 빈칸(빈 배열)으로 냅뒀다 썅! 나중에 채워넣어라! 🚨
    let openAIModels: [String] = ["gpt-5.4","gpt-5.4-pro","gpt-5.4-mini","gpt-5","gpt-5.3-codex","gpt-5.2-codex","gpt-5.1-codex-max","gpt-5.1-codex","o3-deep-research"]
    let geminiModels: [String] = ["gemini-3.1-pro","gemini-3.1-flash-preview","gemini-3-flash-preview","gemma-3-27b-it","gemma-3-12b-it","gemini-2.5-pro","gemini-2.5-flash"]
    
    let groqModels = ["openai/gpt-oss-120b", "llama-3.3-70b-versatile", "qwen/qwen3-32b", "openai/gpt-oss-20b", "meta-llama/llama-4-scout-17b-16e-instruct"]
    let claudeModels = ["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5-20251001", "claude-opus-4-5-20251101", "claude-sonnet-4-5-20250929", "claude-opus-4-1-20250805", "claude-opus-4-20250514", "claude-sonnet-4-20250514"]

    var body: some View {
        mainSettingsView
            .overlay(
                Group {
                    if !isUnlocked {
                        lockScreenView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(NSColor.windowBackgroundColor))
                    }
                }
            )
            .onAppear { authenticate() }
    }
    
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
                            // 🚨 설정창 Grid에 모델 Picker들 싹 다 정렬해서 쑤셔넣음 썅! 🚨
                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                                GridRow { Text("OpenAI:").font(.subheadline).frame(width: 70, alignment: .leading); SecureField("Key", text: $openAIKey).textFieldStyle(.roundedBorder).frame(width: 190) }
                                GridRow { Text("OpenAI 모델:"); Picker("", selection: $openAIModel) { ForEach(openAIModels, id: \.self) { Text($0) } }.labelsHidden().controlSize(.small).frame(width: 190) }
                                
                                GridRow { Text("Gemini:"); SecureField("Key", text: $geminiKey).textFieldStyle(.roundedBorder).frame(width: 190) }
                                GridRow { Text("Gemini 모델:"); Picker("", selection: $geminiModel) { ForEach(geminiModels, id: \.self) { Text($0) } }.labelsHidden().controlSize(.small).frame(width: 190) }
                                
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

                OrchestrationSettingsPanel()
                    .tabItem { Label("오케스트", systemImage: "square.grid.2x2") }
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
        .frame(minWidth: 980, idealWidth: 980, maxWidth: 980, minHeight: 640, idealHeight: 640, maxHeight: 720)
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
