import Foundation

// 클로드 스트리밍 응답 모델
struct ClaudeStreamResponse: Codable {
    let type: String?
    struct Delta: Codable {
        let text: String?
    }
    let delta: Delta?
}

class ClaudeAPI {
    static let shared = ClaudeAPI()
    private init() {}

    // 리턴 타입을 스트리밍(AsyncThrowingStream)으로 제공합니다.
    func sendMessageStream(history: [ChatMessage], model: String) async throws -> AsyncThrowingStream<String, Error> {

        // 키 매니저에서 클로드 키를 가져옵니다.
        let apiKey = KeyManager.loadKey(for: .claude)
        guard !apiKey.isEmpty else {
            throw NSError(domain: "ClaudeAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "클로드 API 키가 없습니다. 설정에서 등록해주세요."])
        }

        let systemPrompt = UserDefaults.standard.string(forKey: "system_prompt") ?? "You are a helpful assistant."
        let claudeModel = UserDefaults.standard.string(forKey: "claude_model") ?? model

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "content-type")

        // 히스토리 변환 (UI 모델 -> 클로드 전용 모델)
        var requestMessages: [[String: String]] = []
        for msg in history {
            requestMessages.append([
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.text
            ])
        }

        // stream: true 로 설정해 스트리밍을 활성화합니다.
        let body: [String: Any] = [
            "model": claudeModel,
            "system": systemPrompt,
            "max_tokens": 4096,
            "stream": true,
            "messages": requestMessages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // 스트리밍 파이프 연결
        let (result, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "ClaudeAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "클로드 통신 중 오류가 발생했습니다."])
        }

        // 스트림으로 받아 UI에 실시간 반영
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in result.lines {
                        // 클로드는 "data: " 로 시작하는 줄에 JSON을 담아줍니다.
                        if line.hasPrefix("data: ") {
                            let jsonStr = line.dropFirst(6)

                            if let data = jsonStr.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(ClaudeStreamResponse.self, from: data) {

                                // type이 "content_block_delta"일 때만 텍스트 조각을 제공합니다.
                                if chunk.type == "content_block_delta", let text = chunk.delta?.text {
                                    continuation.yield(text)
                                }
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
