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
    var isAnalyzing = false
    var errorMessage: String?
    var workoutsUpdated = false
    var proposedWorkouts: [Workout] = []

    private let systemPrompt = """
    You are an expert swim coach helping me train for the Alcatraz swim \
    (1.5 miles / 2.4km from Alcatraz Island to San Francisco) on August 30, 2026.

    ATHLETE BACKGROUND:
    - Started: January 1, 2026 at 50m continuous swimming
    - Current best: 550m continuous (as of February 22, 2026)
    - Current pace: 11-12 min/500m (mix of freestyle and breaststroke)
    - Pool: 25 meters (1 lap = 2 lengths = 50m)
    - Training location: California (moved from Mumbai mid-February 2026)
    - Training frequency: 3 swims per week
      * 2 shorter weekday sessions (typically Mon/Wed or Tue/Thu)
      * 1 longer weekend session (typically Saturday)
    - Current phase: Week 7-8 of training
    - Current sessions: 1,200-1,800m total volume, building toward 2,000-2,500m

    ENDURANCE PROGRESSION PLAN:
    - Fixed Plan: Linear progression from 50m (Jan 1) to 3,000m (July 30, 2026)
      * Weekly increase: ~98m/week over 30 weeks
    - Adaptive Plan: Adjusts based on current best to reach 3,000m by July 30
      * Current: 550m → 3,000m in 22 weeks = ~111m/week needed
    - Goal: 3,000m continuous by July 30, 2026 (1 month buffer before Alcatraz)
    - Current progress: Week 7, on track

    When generating workouts, consider the weekly endurance target from the adaptive plan.
    The athlete's main endurance workout is typically on Saturday.

    CROSS-TRAINING SCHEDULE:
    The athlete does leg workouts on:
    - Sunday: Barbell Back Squat, Romanian Deadlift
    - Tuesday: Machine Seated Leg Extension, Machine 45 Degree Calf Extension

    WORKOUT SCHEDULING CONSTRAINTS:
    1. NO kick workouts on Monday (legs recovering from Sunday squats/deadlifts)
    2. NO kick AND endurance on the same day (too much lower body load)
    3. Kick + Pull on same day is fine
    4. Main endurance workout: Saturday (before Sunday leg day)

    WORKOUT DISTRIBUTION:
    - Monday: Pull focus or technique (avoid kick)
    - Wednesday/Thursday: Kick focus is acceptable (2 days after Tuesday leg workout)
    - Saturday: Endurance/peak session (can include pull, avoid heavy kick volume)

    When generating the next 3 workouts, respect these constraints to prevent overtraining the legs.

    TRAINING PLAN STRUCTURE:
    Every workout should include:
    1. Warm-up: 150-200m easy swimming
    2. Focus set: One of:
       - KICK: Kickboard drills (kick from hips, toes pointed, 60s rest)
       - PULL: Pull buoy drills (upper body focus, 35-40s rest)
       - Technique/drill work
    3. Main set: Progressive distance, 25-35s rest between reps
       - Format as: "reps × distance, rest time"
       - Example: "6x100m mixed strokes, 30s rest = 600m"
    4. Optional finisher: Anaerobic/sprint sets on peak days (8-10x25m or 4-8x50m, 40-45s rest)
    5. Cool Down: 150-200m of easy swimming

    WORKOUT FORMATTING:
    - Total distance in meters
    - Sets broken down: type, reps, distance per rep, rest intervals
    - Effort level: 6-7/10 for moderate, 7-8/10 for peak, 9/10 for sprints
    - Instructions per set (technique cues, intensity notes)
    - Schedule: Space workouts 2-3 days apart

    PROGRESSION PRINCIPLES:
    - Increase volume gradually (10-15% when appropriate)
    - Weekly pattern: 2 moderate sessions + 1 peak session
    - Rotate focus: Kick emphasis → Pull emphasis → Balanced endurance
    - Include recovery weeks after 3-4 weeks of building
    - Target: 3,000m continuous by July 30, 2026
    - July-August: Shift toward open water preparation

    WORKOUT GENERATION:
    When I share swim progress, analyze:
    1. How the session went (difficulty, completion, notes)
    2. Progression trend (ready to advance or need consolidation)
    3. Recovery status
    4. Time since last swim

    Then provide the next 3 workouts using the update_workouts tool:
    - Workout 1: Next weekday (Monday or Tuesday), moderate intensity
    - Workout 2: Mid-week (Wednesday or Thursday), moderate intensity
    - Workout 3: Weekend (Saturday), peak/endurance focus

    Space workouts to allow 1-2 rest days between sessions.

    Set types must be one of: "Warm-up", "KICK", "PULL", "Main", "Anaerobic", "Open Water"

    Keep workouts realistic, progressive, and aligned with the Alcatraz goal.

    IMPORTANT: Always use the update_workouts tool when providing new workouts. Do not just \
    describe workouts in text - use the tool so they appear in the swimmer's Upcoming tab.

    CRITICAL: When generating workouts, you MUST calculate total distance accurately.
    For each workout:
    1. List all sets with reps and distances
    2. Calculate total: (reps × distance) for each set, then sum
    3. Verify the total matches the user's request
    4. If total doesn't match, adjust sets BEFORE responding

    Example:
    User wants: 1500m
    Your sets: 200m + (8×100m) + 200m = 1200m WRONG
    Fix: 200m + (10×100m) + 300m = 1500m CORRECT

    Always ensure your total_distance field matches the sum of (reps × distance) for all sets.

    OFFERING CHOICES:
    When offering the user multiple approaches or choices, format them with markers so \
    the app can render them as tappable cards:

    OPTIONS_START
    Option 1: Title - Short description of this approach
    Option 2: Title - Short description of this approach
    OPTIONS_END

    Example:
    I can create workouts with two different focuses:

    OPTIONS_START
    Option 1: Endurance Focus - Build base with longer continuous sets
    Option 2: Speed Focus - Work on faster intervals and anaerobic capacity
    OPTIONS_END

    Which would you prefer?
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
            "model": "claude-haiku-4-5-20251001",
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
            let toolResult = processWorkoutTool(input: input)

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
                "model": "claude-haiku-4-5-20251001",
                "max_tokens": 2048,
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

    private func processWorkoutTool(input: [String: Any]) -> String {
        guard let workoutsArray = input["workouts"] as? [[String: Any]] else {
            return "Error: Invalid workouts data"
        }

        let calendar = Calendar.current
        let today = Date.now
        var parsed: [Workout] = []

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
            parsed.append(workout)

            // Debug: validate Coach's total vs calculated total
            let calculatedTotal = workout.actualTotalDistance
            print("[Workout] \(title)")
            print("[Workout]   Coach's total: \(totalDistance)m")
            print("[Workout]   Calculated total: \(calculatedTotal)m")
            if abs(calculatedTotal - totalDistance) > 50 {
                print("[Workout]   ⚠️ MISMATCH: difference of \(calculatedTotal - totalDistance)m")
            }
        }

        proposedWorkouts = parsed
        return "Successfully created \(parsed.count) workouts."
    }

    func analyzeWorkout(session: SwimSession, recentSessions: [SwimSession]) async throws -> WorkoutAnalysis? {
        guard let apiKey = UserDefaults.standard.string(forKey: "anthropicAPIKey"), !apiKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        // Build workout details
        var workoutDetails = "WORKOUT TO ANALYZE:\n"
        workoutDetails += "Date: \(session.date.formatted(date: .abbreviated, time: .omitted))\n"
        workoutDetails += "Distance: \(Int(session.distance))m\n"
        workoutDetails += "Duration: \(Int(session.duration)) min\n"
        workoutDetails += "Difficulty: \(session.difficulty)/10\n"

        if let data = session.detailedData {
            workoutDetails += "Sets: \(data.sets.count)\n"
            for (i, set) in data.sets.enumerated() {
                workoutDetails += "  Set \(i + 1): \(Int(set.totalDistance))m, \(set.strokeType)"
                if let swolf = set.averageSWOLF { workoutDetails += ", SWOLF \(Int(swolf))" }
                if let pace = set.averagePace { workoutDetails += ", pace \(String(format: "%.1f", pace))min/100m" }
                if let hr = set.averageHeartRate { workoutDetails += ", HR \(hr)bpm" }
                workoutDetails += "\n"
            }
            if let swolf = data.averageSWOLF { workoutDetails += "Overall SWOLF: \(Int(swolf))\n" }
            if let pace = data.averagePace { workoutDetails += "Overall pace: \(String(format: "%.1f", pace))min/100m\n" }
            if let hr = data.averageHeartRate { workoutDetails += "Avg HR: \(hr)bpm\n" }
            if let maxHR = data.maxHeartRate { workoutDetails += "Max HR: \(maxHR)bpm\n" }
        }

        if !session.notes.isEmpty {
            workoutDetails += "Notes: \(session.notes)\n"
        }

        // Add recent session history for trend comparison
        let history = recentSessions.prefix(5)
        if !history.isEmpty {
            workoutDetails += "\nRECENT HISTORY (for trend comparison):\n"
            for s in history {
                workoutDetails += "  \(s.date.formatted(date: .abbreviated, time: .omitted)): \(Int(s.distance))m in \(Int(s.duration))min, difficulty \(s.difficulty)/10"
                if let data = s.detailedData {
                    if let swolf = data.averageSWOLF { workoutDetails += ", SWOLF \(Int(swolf))" }
                    if let pace = data.averagePace { workoutDetails += ", pace \(String(format: "%.1f", pace))min/100m" }
                }
                workoutDetails += "\n"
            }
        }

        workoutDetails += """

        Analyze this workout and respond with ONLY valid JSON (no markdown, no code blocks, no explanation).

        JSON structure:
        {"performanceScore": 7, "insights": ["Your SWOLF improved by 3 points compared to last week, showing better stroke efficiency", "Heart rate stayed in the aerobic zone throughout, good endurance base building", "Pace was consistent across all sets with less than 5s variation"], "recommendation": "Focus on bilateral breathing next session to further improve stroke symmetry and SWOLF", "swolfTrend": "improving", "paceTrend": "consistent", "effortVsPerformance": "efficient"}

        Rules:
        - performanceScore: integer 1-10
        - insights: array of exactly 3-4 specific, actionable observations
        - recommendation: one clear next-step focus area
        - swolfTrend: exactly one of "improving", "declining", "stable"
        - paceTrend: exactly one of "faster", "slower", "consistent"
        - effortVsPerformance: exactly one of "efficient", "hard_but_slow", "easy_cruise"
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1024,
            "system": "You are an expert swim coach analyzing workout data from an Apple Watch. Provide constructive, specific feedback focusing on technique efficiency (SWOLF), pacing strategy, effort management, and progress trends. Respond ONLY with valid JSON. No markdown, no code blocks, no explanations — just the raw JSON object.",
            "messages": [
                ["role": "user", "content": workoutDetails]
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("[WorkoutAnalysis] API error: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentBlocks = json["content"] as? [[String: Any]] else {
            print("[WorkoutAnalysis] Failed to parse API response")
            return nil
        }

        // Extract text from response
        var textResponse = ""
        for block in contentBlocks {
            if block["type"] as? String == "text", let text = block["text"] as? String {
                textResponse += text
            }
        }

        guard !textResponse.isEmpty else {
            print("[WorkoutAnalysis] Empty response from API")
            return nil
        }

        // Strip markdown code fences if model wrapped the JSON
        var cleanedResponse = textResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedResponse.hasPrefix("```json") {
            cleanedResponse = String(cleanedResponse.dropFirst(7))
        } else if cleanedResponse.hasPrefix("```") {
            cleanedResponse = String(cleanedResponse.dropFirst(3))
        }
        if cleanedResponse.hasSuffix("```") {
            cleanedResponse = String(cleanedResponse.dropLast(3))
        }
        cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let responseData = cleanedResponse.data(using: .utf8) else {
            print("[WorkoutAnalysis] Failed to encode cleaned response as UTF-8")
            return nil
        }

        // Decode into WorkoutAnalysis
        do {
            let analysis = try JSONDecoder().decode(WorkoutAnalysis.self, from: responseData)
            print("[WorkoutAnalysis] Success: score=\(analysis.performanceScore), insights=\(analysis.insights.count)")
            return analysis
        } catch {
            print("[WorkoutAnalysis] Failed to parse analysis response: \(cleanedResponse.prefix(500))")
            print("[WorkoutAnalysis] Decode error: \(error)")
            return nil
        }
    }

    func acceptWorkouts(modelContext: ModelContext) {
        // Delete existing upcoming (incomplete) workouts
        let fetchDescriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isCompleted }
        )
        if let existing = try? modelContext.fetch(fetchDescriptor) {
            for workout in existing {
                modelContext.delete(workout)
            }
        }

        for workout in proposedWorkouts {
            modelContext.insert(workout)
        }
        try? modelContext.save()

        proposedWorkouts = []
        workoutsUpdated = true
    }

    func declineWorkouts() {
        proposedWorkouts = []
    }
}
