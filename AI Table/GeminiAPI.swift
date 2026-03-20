import Foundation

struct GeminiRequest: Codable {
    struct Content: Codable {
        let role: String?
        struct Part: Codable {
            let text: String
        }
        let parts: [Part]
    }
    let system_instruction: Content?
    let contents: [Content]
}

struct GeminiStreamResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content?
    }
    let candidates: [Candidate]?
}

class GeminiAPI {
    static let shared = GeminiAPI()
    private init() {}

    // 🚨 파라미터에 model 받음 🚨
    func sendMessageStream(history: [ChatMessage], model: String) async throws -> AsyncThrowingStream<String, Error> {

        let apiKey = KeyManager.loadAll().gemini
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GeminiAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "설정에서 Gemini API 키를 먼저 등록해주세요."])
        }

        let systemPrompt = UserDefaults.standard.string(forKey: "system_prompt") ?? "너는 친절하고 똑똑한 AI 조수야."

        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 🚨 URL에 모델명 동적 주입 🚨
        let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent"
        let urlString = "\(baseURL)?alt=sse&key=\(cleanKey)"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "GeminiAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL 문자열이 올바르지 않습니다. 다시 확인해주세요."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // 🚨 Gemma 판독기 & 프롬프트 쑤셔넣기 로직 🚨
        let isGemma = model.lowercased().contains("gemma")

        var contents: [GeminiRequest.Content] = []
        for (index, msg) in history.enumerated() {
            var text = msg.text
            
            // Gemma일 때는 첫 번째 유저 메시지에 시스템 프롬프트를 강제로 기입
            if isGemma && index == 0 && msg.isUser {
                text = "[System Instruction]\n\(systemPrompt)\n\n[User Input]\n\(text)"
            }
            
            contents.append(GeminiRequest.Content(
                role: msg.isUser ? "user" : "model",
                parts: [GeminiRequest.Content.Part(text: text)]
            ))
        }

        // Gemma면 system_instruction 필드를 아예 nil로 만들어서 없애버림
        let systemInstructionContent = isGemma ? nil : GeminiRequest.Content(role: nil, parts: [GeminiRequest.Content.Part(text: systemPrompt)])

        let requestBody = GeminiRequest(
            system_instruction: systemInstructionContent,
            contents: contents
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (result, response) = try await URLSession.shared.bytes(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard statusCode == 200 else {
            throw NSError(domain: "GeminiAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini 통신 중 오류 발생 (상태 코드: \(statusCode)). API 키나 모델명을 확인해주세요. "])
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in result.lines {
                        if line.hasPrefix("data: ") {
                            let jsonStr = line.dropFirst(6)

                            if jsonStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }

                            if let data = jsonStr.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(GeminiStreamResponse.self, from: data),
                               let text = chunk.candidates?.first?.content?.parts.first?.text {

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
