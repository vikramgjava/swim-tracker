import Foundation
import SwiftData

struct WorkoutSet: Codable, Identifiable {
    var id: UUID
    var type: String // "Warm-up", "KICK", "PULL", "Main", "Anaerobic", "Open Water"
    var reps: Int
    var distance: Int // meters per rep
    var rest: Int // seconds between reps
    var instructions: String

    init(id: UUID = UUID(), type: String, reps: Int, distance: Int, rest: Int, instructions: String) {
        self.id = id
        self.type = type
        self.reps = reps
        self.distance = distance
        self.rest = rest
        self.instructions = instructions
    }
}

@Model
final class Workout {
    var id: UUID
    var scheduledDate: Date
    var title: String
    var totalDistance: Int
    var focus: String
    var effortLevel: String
    var isCompleted: Bool
    var completedDate: Date?
    var notes: String?
    var setsJSON: String

    var actualTotalDistance: Int {
        let setsTotal = sets.reduce(0) { $0 + ($1.reps * $1.distance) }
        return setsTotal > 0 ? setsTotal : totalDistance
    }

    var sets: [WorkoutSet] {
        get {
            guard let data = setsJSON.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([WorkoutSet].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                setsJSON = "[]"
                return
            }
            setsJSON = String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    init(
        scheduledDate: Date,
        title: String,
        totalDistance: Int,
        focus: String,
        effortLevel: String,
        sets: [WorkoutSet] = [],
        notes: String? = nil
    ) {
        self.id = UUID()
        self.scheduledDate = scheduledDate
        self.title = title
        self.totalDistance = totalDistance
        self.focus = focus
        self.effortLevel = effortLevel
        self.isCompleted = false
        self.completedDate = nil
        self.notes = notes
        // Encode sets to JSON
        if let data = try? JSONEncoder().encode(sets) {
            self.setsJSON = String(data: data, encoding: .utf8) ?? "[]"
        } else {
            self.setsJSON = "[]"
        }
    }
}
