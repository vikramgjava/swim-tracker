import Foundation
import SwiftData

struct LapData: Codable, Identifiable {
    var id = UUID()
    var distance: Double        // meters
    var duration: TimeInterval  // seconds
    var strokeCount: Int?
    var swolf: Int?             // strokeCount + seconds (nil if no stroke data)
    var pace: Double?           // minutes per 100m
    var strokeType: String?     // "Freestyle", "Backstroke", etc.
    var heartRate: Int?         // average bpm for this lap
}

struct SwimSet: Codable, Identifiable {
    var id = UUID()
    var laps: [LapData]
    var restAfter: TimeInterval     // seconds of rest after this set
    var totalDistance: Double
    var totalDuration: TimeInterval
    var averageSWOLF: Double?
    var averagePace: Double?        // minutes per 100m
    var strokeType: String          // majority stroke type in set
    var averageHeartRate: Int?
    var maxHeartRate: Int?
}

struct WorkoutDetailedData: Codable {
    var sets: [SwimSet]
    var totalDistance: Double
    var totalDuration: TimeInterval
    var longestContinuousDistance: Double? // longest single set distance (no rest); nil for legacy data
    var averageSWOLF: Double?
    var averagePace: Double?        // minutes per 100m
    var averageHeartRate: Int?
    var maxHeartRate: Int?

    /// Computed longest continuous distance: uses stored value, or derives from sets, or falls back to totalDistance
    var effectiveLongestContinuousDistance: Double {
        if let stored = longestContinuousDistance { return stored }
        let fromSets = sets.map(\.totalDistance).max()
        return fromSets ?? totalDistance
    }
}

@Model
final class SwimSession {
    var date: Date
    var distance: Double // meters
    var duration: Double // minutes
    var notes: String
    var difficulty: Int  // 1-10
    var workoutId: String? // UUID string linking to source Workout
    var healthKitId: String? // HKWorkout UUID to prevent duplicate imports
    var detailedDataJSON: String? // JSON-encoded WorkoutDetailedData

    /// Longest continuous swim distance (no rest). Uses detailed set data if available, falls back to total session distance.
    var longestContinuousDistance: Double {
        detailedData?.effectiveLongestContinuousDistance ?? distance
    }

    var detailedData: WorkoutDetailedData? {
        get {
            guard let json = detailedDataJSON, let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(WorkoutDetailedData.self, from: data)
        }
        set {
            guard let value = newValue, let data = try? JSONEncoder().encode(value) else {
                detailedDataJSON = nil
                return
            }
            detailedDataJSON = String(data: data, encoding: .utf8)
        }
    }

    init(date: Date = .now, distance: Double = 0, duration: Double = 0, notes: String = "", difficulty: Int = 5, workoutId: String? = nil, healthKitId: String? = nil, detailedData: WorkoutDetailedData? = nil) {
        self.date = date
        self.distance = distance
        self.duration = duration
        self.notes = notes
        self.difficulty = difficulty
        self.workoutId = workoutId
        self.healthKitId = healthKitId
        if let detailedData, let data = try? JSONEncoder().encode(detailedData) {
            self.detailedDataJSON = String(data: data, encoding: .utf8)
        } else {
            self.detailedDataJSON = nil
        }
    }
}
