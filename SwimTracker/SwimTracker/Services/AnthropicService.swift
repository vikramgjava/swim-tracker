import Foundation

enum AnthropicError: LocalizedError {
    case missingAPIKey
    case apiError(String)
    case invalidResponse
    case parseError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not set. Tap the gear icon to add your Anthropic API key."
        case .apiError(let message):
            return message
        case .invalidResponse:
            return "Invalid response from server."
        case .parseError:
            return "Failed to parse response."
        }
    }
}

@MainActor
@Observable
final class AnthropicService {
    var isLoading = false
    var errorMessage: String?

    private let systemPrompt = """
    You are "Coach Alcatraz," an expert open-water swim coach specializing in preparing swimmers \
    for the Alcatraz Island to San Francisco crossing (~2,400 meters / 1.5 miles). You provide \
    personalized training advice, technique tips, workout adjustments, and motivational coaching. \
    Keep responses concise and actionable. When given swim data, analyze it and suggest improvements. \
    Consider factors like distance progression, pace, difficulty ratings, and consistency.
    """

    func sendMessage(userContent: String, conversationHistory: [ChatMessage]) async throws -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: "anthropicAPIKey"), !apiKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let recentHistory = conversationHistory.suffix(20)
        var messages: [[String: String]] = []
        for msg in recentHistory {
            messages.append([
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.content
            ])
        }
        messages.append(["role": "user", "content": userContent])

        let body: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": messages
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorBody["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AnthropicError.apiError("API error (\(httpResponse.statusCode)): \(message)")
            }
            throw AnthropicError.apiError("API error: HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AnthropicError.parseError
        }

        return text
    }
}
