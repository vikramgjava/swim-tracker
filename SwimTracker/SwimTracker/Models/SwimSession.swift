import Foundation
import SwiftData

@Model
final class SwimSession {
    var date: Date
    var distance: Double // meters
    var duration: Double // minutes
    var notes: String
    var difficulty: Int  // 1-10
    var workoutId: String? // UUID string linking to source Workout

    init(date: Date = .now, distance: Double = 0, duration: Double = 0, notes: String = "", difficulty: Int = 5, workoutId: String? = nil) {
        self.date = date
        self.distance = distance
        self.duration = duration
        self.notes = notes
        self.difficulty = difficulty
        self.workoutId = workoutId
    }
}
