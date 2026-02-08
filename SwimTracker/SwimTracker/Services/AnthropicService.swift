import Foundation
import SwiftData

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
    var workoutsUpdated = false

    private let systemPrompt = """
    You are "Coach Alcatraz," an expert open-water swim coach helping a swimmer prepare for \
    the Alcatraz Island to San Francisco crossing (~2,400 meters / 1.5 miles in San Francisco Bay).

    TRAINING CONTEXT:
    - Goal: Build from current level to 3,000m continuous swim by late August 2026
    - Schedule: 3 swims per week (Mon/Wed shorter sessions, Sat long session)
    - The swimmer trains in a pool with 44m laps

    YOUR ROLE:
    - Analyze swim session data and provide feedback on progress
    - Provide technique tips, pacing advice, and motivational coaching
    - When the user shares swim progress or asks for workouts, use the update_workouts tool \
    to create their next 3 training sessions
    - Progressively build volume week over week (~5-10% increase)
    - Include variety: kick sets (KICK), pull sets (PULL), main freestyle sets, and occasional sprints (Anaerobic)
    - Each workout should have 3-5 sets, always starting with a Warm-up
    - Schedule workouts 2, 4, and 6 days from today
    - Set types must be one of: "Warm-up", "KICK", "PULL", "Main", "Anaerobic", "Open Water"
    - Keep text responses concise and actionable

    IMPORTANT: Always use the update_workouts tool when providing new workouts. Do not just \
    describe workouts in text - use the tool so they appear in the swimmer's Upcoming tab.
    """

    private let workoutTool: [String: Any] = [
        "name": "update_workouts",
        "description": "Create or update the swimmer's next training workouts. This saves workouts to their app so they appear in the Upcoming tab. Always provide exactly 3 workouts.",
        "input_schema": [
            "type": "object",
            "properties": [
                "workouts": [
                    "type": "array",
                    "description": "Array of 3 workout objects",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": [
                                "type": "string",
                                "description": "Workout title, e.g. 'Week 4 - Monday Evening'"
                            ],
                            "days_from_now": [
                                "type": "integer",
                                "description": "Number of days from today to schedule this workout"
                            ],
                            "total_distance": [
                                "type": "integer",
                                "description": "Total workout distance in meters"
                            ],
                            "focus": [
                                "type": "string",
                                "description": "Workout focus, e.g. 'Kick Focus', 'Pull Focus', 'Endurance'"
                            ],
                            "effort_level": [
                                "type": "string",
                                "description": "Effort level, e.g. '6-7/10', '7-8/10'"
                            ],
                            "notes": [
                                "type": "string",
                                "description": "Optional coach notes for this workout"
                            ],
                            "sets": [
                                "type": "array",
                                "description": "Workout sets",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "type": [
                                            "type": "string",
                                            "enum": ["Warm-up", "KICK", "PULL", "Main", "Anaerobic", "Open Water"],
                                            "description": "Set type"
                                        ],
                                        "reps": [
                                            "type": "integer",
                                            "description": "Number of repetitions"
                                        ],
                                        "distance": [
                                            "type": "integer",
                                            "description": "Distance per rep in meters"
                                        ],
                                        "rest": [
                                            "type": "integer",
                                            "description": "Rest between reps in seconds"
                                        ],
                                        "instructions": [
                                            "type": "string",
                                            "description": "Instructions for this set"
                                        ]
                                    ] as [String: Any],
                                    "required": ["type", "reps", "distance", "rest", "instructions"]
                                ] as [String: Any]
                            ]
                        ] as [String: Any],
                        "required": ["title", "days_from_now", "total_distance", "focus", "effort_level", "sets"]
                    ] as [String: Any]
                ]
            ] as [String: Any],
            "required": ["workouts"]
        ] as [String: Any]
    ]

    func sendMessage(
        userContent: String,
        conversationHistory: [ChatMessage],
        modelContext: ModelContext,
        swimContext: String
    ) async throws -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: "anthropicAPIKey"), !apiKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }

        isLoading = true
        errorMessage = nil
        workoutsUpdated = false
        defer { isLoading = false }

        let recentHistory = conversationHistory.suffix(20)
        var messages: [[String: Any]] = []
        for msg in recentHistory {
            messages.append([
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.content
            ])
        }

        let fullUserContent = swimContext.isEmpty ? userContent : "\(userContent)\n\n---\nCURRENT DATA:\n\(swimContext)"
        messages.append(["role": "user", "content": fullUserContent])

        let body: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": 4096,
            "system": systemPrompt,
            "tools": [workoutTool],
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
              let contentBlocks = json["content"] as? [[String: Any]] else {
            throw AnthropicError.parseError
        }

        var textResponse = ""
        var toolUseId: String?
        var toolInput: [String: Any]?

        for block in contentBlocks {
            let blockType = block["type"] as? String
            if blockType == "text", let text = block["text"] as? String {
                textResponse += text
            } else if blockType == "tool_use" {
                toolUseId = block["id"] as? String
                toolInput = block["input"] as? [String: Any]
            }
        }

        // Handle tool call
        if let toolId = toolUseId, let input = toolInput {
            let toolResult = processWorkoutTool(input: input, modelContext: modelContext)

            // Send tool result back to get final text response
            var followUpMessages = messages
            followUpMessages.append([
                "role": "assistant",
                "content": contentBlocks
            ])
            followUpMessages.append([
                "role": "user",
                "content": [
                    [
                        "type": "tool_result",
                        "tool_use_id": toolId,
                        "content": toolResult
                    ] as [String: Any]
                ]
            ])

            let followUpBody: [String: Any] = [
                "model": "claude-sonnet-4-5-20250929",
                "max_tokens": 1024,
                "system": systemPrompt,
                "tools": [workoutTool],
                "messages": followUpMessages
            ]

            let followUpData = try JSONSerialization.data(withJSONObject: followUpBody)
            var followUpRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            followUpRequest.httpMethod = "POST"
            followUpRequest.setValue("application/json", forHTTPHeaderField: "content-type")
            followUpRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            followUpRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            followUpRequest.httpBody = followUpData

            let (followUpResponseData, _) = try await URLSession.shared.data(for: followUpRequest)

            if let followUpJson = try? JSONSerialization.jsonObject(with: followUpResponseData) as? [String: Any],
               let followUpContent = followUpJson["content"] as? [[String: Any]] {
                for block in followUpContent {
                    if block["type"] as? String == "text", let text = block["text"] as? String {
                        textResponse = text
                    }
                }
            }
        }

        if textResponse.isEmpty {
            throw AnthropicError.parseError
        }

        return textResponse
    }

    private func processWorkoutTool(input: [String: Any], modelContext: ModelContext) -> String {
        guard let workoutsArray = input["workouts"] as? [[String: Any]] else {
            return "Error: Invalid workouts data"
        }

        // Delete existing upcoming (incomplete) workouts
        let fetchDescriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isCompleted }
        )
        if let existing = try? modelContext.fetch(fetchDescriptor) {
            for workout in existing {
                modelContext.delete(workout)
            }
        }

        let calendar = Calendar.current
        let today = Date.now
        var createdCount = 0

        for workoutData in workoutsArray {
            guard let title = workoutData["title"] as? String,
                  let daysFromNow = workoutData["days_from_now"] as? Int,
                  let totalDistance = workoutData["total_distance"] as? Int,
                  let focus = workoutData["focus"] as? String,
                  let effortLevel = workoutData["effort_level"] as? String,
                  let setsArray = workoutData["sets"] as? [[String: Any]] else {
                continue
            }

            let scheduledDate = calendar.date(byAdding: .day, value: daysFromNow, to: today) ?? today
            let notes = workoutData["notes"] as? String

            var sets: [WorkoutSet] = []
            for setData in setsArray {
                guard let type = setData["type"] as? String,
                      let reps = setData["reps"] as? Int,
                      let distance = setData["distance"] as? Int,
                      let rest = setData["rest"] as? Int,
                      let instructions = setData["instructions"] as? String else {
                    continue
                }
                sets.append(WorkoutSet(
                    type: type,
                    reps: reps,
                    distance: distance,
                    rest: rest,
                    instructions: instructions
                ))
            }

            let workout = Workout(
                scheduledDate: scheduledDate,
                title: title,
                totalDistance: totalDistance,
                focus: focus,
                effortLevel: effortLevel,
                sets: sets,
                notes: notes
            )
            modelContext.insert(workout)
            createdCount += 1
        }

        try? modelContext.save()
        workoutsUpdated = true
        return "Successfully created \(createdCount) workouts."
    }
}
