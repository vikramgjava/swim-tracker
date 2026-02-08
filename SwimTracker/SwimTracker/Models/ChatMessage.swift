import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var content: String
    var isUser: Bool
    var timestamp: Date

    init(content: String, isUser: Bool, timestamp: Date = .now) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}
