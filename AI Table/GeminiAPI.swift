import Foundation

// 1. 제미나이 요청 모델
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

// 2. 스트리밍용 응답 모델
struct GeminiStreamResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        // 제미나이는 content가 비어있는 경우가 있어 옵셔널로 둡니다.
        let content: Content?
    }
    let candidates: [Candidate]?
}

class GeminiAPI {
    static let shared = GeminiAPI()
    private init() {}

    // 3. 리턴 타입을 스트리밍(AsyncThrowingStream)으로 제공합니다.
    func sendMessageStream(history: [ChatMessage]) async throws -> AsyncThrowingStream<String, Error> {

        // 키 매니저에서 제미나이 키를 가져옵니다.
        let apiKey = KeyManager.loadAll().gemini
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GeminiAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "설정에서 Gemini API 키를 먼저 등록해주세요."])
        }

        let systemPrompt = UserDefaults.standard.string(forKey: "system_prompt") ?? "너는 친절하고 똑똑한 AI 조수야."

        // URL 문자열 구성
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-preview:streamGenerateContent"
        let urlString = "\(baseURL)?alt=sse&key=\(cleanKey)"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "GeminiAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL 문자열이 올바르지 않습니다. 다시 확인해주세요."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // 히스토리 변환 (제미나이는 AI를 model로 지칭)
        var contents: [GeminiRequest.Content] = []
        for msg in history {
            contents.append(GeminiRequest.Content(
                role: msg.isUser ? "user" : "model",
                parts: [GeminiRequest.Content.Part(text: msg.text)]
            ))
        }

        let systemInstructionContent = GeminiRequest.Content(role: nil, parts: [GeminiRequest.Content.Part(text: systemPrompt)])

        let requestBody = GeminiRequest(
            system_instruction: systemInstructionContent,
            contents: contents
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        // 스트리밍 파이프 연결
        let (result, response) = try await URLSession.shared.bytes(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard statusCode == 200 else {
            throw NSError(domain: "GeminiAPI", code: statusCode, userInfo: nil)
        }

        // 스트림으로 받아 UI에 실시간 반영
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
