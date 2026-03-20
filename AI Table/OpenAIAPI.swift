import Foundation

struct OpenAIRequest: Codable {
    let model: String
    let messages: [[String: String]]
    let stream: Bool
}

struct OpenAIStreamResponse: Codable {
    struct Choice: Codable {
        struct Delta: Codable {
            let content: String?
        }
        let delta: Delta
    }
    let choices: [Choice]
}

class OpenAIAPI {
    
    static let shared = OpenAIAPI()
    private init() {}

    // 🚨 파라미터에 model 강제! 🚨
    func sendMessageStream(history: [ChatMessage], model: String) async throws -> AsyncThrowingStream<String, Error> {
        
        let apiKey = KeyManager.loadAll().openai
        guard !apiKey.isEmpty else {
            throw NSError(domain: "OpenAIAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "설정에서 OpenAI API 키를 먼저 등록해주세요."])
        }

        let systemPrompt = UserDefaults.standard.string(forKey: "system_prompt") ?? "너는 친절하고 똑똑한 AI 조수야."

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var requestMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        
        for msg in history {
            requestMessages.append([
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.text
            ])
        }

        // 여기서 받은 모델명 그대로 꽂음
        let requestBody = OpenAIRequest(model: model, messages: requestMessages, stream: true)
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (result, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "OpenAIAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI 통신 중 오류가 발생했습니다."])
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in result.lines {
                        if line.hasPrefix("data: ") {
                            let jsonStr = line.dropFirst(6)

                            if jsonStr == "[DONE]" { break }

                            if let data = jsonStr.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(OpenAIStreamResponse.self, from: data),
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
