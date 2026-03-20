import Foundation

// 채팅 메시지 껍데기
struct ChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var isUser: Bool
}
