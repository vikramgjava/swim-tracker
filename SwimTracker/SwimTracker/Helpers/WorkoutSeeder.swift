import Foundation
import SwiftData

enum WorkoutSeeder {
    static func seedTestWorkouts(modelContext: ModelContext) {
        let calendar = Calendar.current
        let today = Date.now

        // Workout 1: Kick Focus
        let workout1 = Workout(
            scheduledDate: calendar.date(byAdding: .day, value: 2, to: today)!,
            title: "Week 3 - Evening Session",
            totalDistance: 1225,
            focus: "Kick Focus",
            effortLevel: "6-7/10",
            sets: [
                WorkoutSet(
                    type: "Warm-up",
                    reps: 6,
                    distance: 50,
                    rest: 0,
                    instructions: "Easy freestyle, focus on breathing"
                ),
                WorkoutSet(
                    type: "KICK",
                    reps: 7,
                    distance: 50,
                    rest: 60,
                    instructions: "Kickboard, steady flutter kick"
                ),
                WorkoutSet(
                    type: "Main",
                    reps: 7,
                    distance: 100,
                    rest: 30,
                    instructions: "Mixed strokes, 4 lengths each"
                ),
            ]
        )

        // Workout 2: Pull Focus
        let workout2 = Workout(
            scheduledDate: calendar.date(byAdding: .day, value: 4, to: today)!,
            title: "Week 3 - Pull Session",
            totalDistance: 1200,
            focus: "Pull Focus",
            effortLevel: "6-7/10",
            sets: [
                WorkoutSet(
                    type: "Warm-up",
                    reps: 6,
                    distance: 50,
                    rest: 0,
                    instructions: "Easy freestyle, loosen up"
                ),
                WorkoutSet(
                    type: "PULL",
                    reps: 9,
                    distance: 50,
                    rest: 35,
                    instructions: "Pull buoy, focus on catch and pull-through"
                ),
                WorkoutSet(
                    type: "Main",
                    reps: 9,
                    distance: 50,
                    rest: 30,
                    instructions: "Mixed strokes, build pace each length"
                ),
            ]
        )

        // Workout 3: Peak with Sprints
        let workout3 = Workout(
            scheduledDate: calendar.date(byAdding: .day, value: 6, to: today)!,
            title: "Week 3 - Peak Session",
            totalDistance: 1800,
            focus: "Endurance + Sprints",
            effortLevel: "7-8/10",
            sets: [
                WorkoutSet(
                    type: "Warm-up",
                    reps: 6,
                    distance: 50,
                    rest: 0,
                    instructions: "Easy freestyle, gradually increase pace"
                ),
                WorkoutSet(
                    type: "Main",
                    reps: 25,
                    distance: 50,
                    rest: 30,
                    instructions: "Steady freestyle, sight every 10 strokes"
                ),
                WorkoutSet(
                    type: "Anaerobic",
                    reps: 5,
                    distance: 50,
                    rest: 45,
                    instructions: "Sprint at 85-90% effort"
                ),
            ]
        )

        modelContext.insert(workout1)
        modelContext.insert(workout2)
        modelContext.insert(workout3)
    }
}
