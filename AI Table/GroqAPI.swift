import Foundation

// 1. 요청 모델에 stream 변수를 추가합니다.
struct GroqRequest: Codable {
    let model: String
    let messages: [[String: String]]
    let stream: Bool
}

// 2. 스트리밍 응답 모델
struct GroqStreamResponse: Codable {
    struct Choice: Codable {
        struct Delta: Codable {
            let content: String?
        }
        let delta: Delta
    }
    let choices: [Choice]
}

class GroqAPI {
    static let shared = GroqAPI()
    private init() {}

    // 3. 리턴 타입을 스트리밍(AsyncThrowingStream)으로 제공합니다.
    func sendMessageStream(history: [ChatMessage], model: String) async throws -> AsyncThrowingStream<String, Error> {
        let apiKey = KeyManager.loadKey(for: .groq)
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GroqAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "설정에서 Groq API 키를 먼저 등록해주세요."])
        }

        let systemPrompt = UserDefaults.standard.string(forKey: "system_prompt") ?? "너는 친절하고 똑똑한 AI 조수야."

        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // 첫 메시지에 시스템 프롬프트를 주입합니다.
        var requestMessages: [[String: String]] = []
        for (index, msg) in history.enumerated() {
            var content = msg.text
            if index == 0 && msg.isUser {
                content = "[System Instruction]\n\(systemPrompt)\n\n[User Input]\n\(content)"
            }
            requestMessages.append([
                "role": msg.isUser ? "user" : "assistant",
                "content": content
            ])
        }

        // stream: true 로 설정해 스트리밍을 활성화합니다.
        let requestBody = GroqRequest(model: model, messages: requestMessages, stream: true)
        request.httpBody = try JSONEncoder().encode(requestBody)

        // URLSession.bytes로 줄 단위 데이터를 수신합니다.
        let (result, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "GroqAPI", code: statusCode, userInfo: nil)
        }

        // 스트림으로 받아 UI에 실시간 반영
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in result.lines {
                        // 스트리밍 데이터는 항상 "data: " 로 시작합니다.
                        if line.hasPrefix("data: ") {
                            let jsonStr = line.dropFirst(6)

                            // 서버 종료 신호
                            if jsonStr == "[DONE]" {
                                break
                            }

                            if let data = jsonStr.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(GroqStreamResponse.self, from: data),
                               let text = chunk.choices.first?.delta.content {
                                continuation.yield(text)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
