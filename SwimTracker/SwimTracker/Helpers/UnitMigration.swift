import Foundation
import SwiftData

enum UnitMigration {
    private static let didMigrateKey = "didMigrateToYards"
    private static let metersToYards = 1.09361

    static func migrateIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: didMigrateKey) else { return }

        migrateSwimSessions(modelContext: modelContext)
        migrateWorkouts(modelContext: modelContext)
        migrateEnduranceTargets(modelContext: modelContext)

        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: didMigrateKey)
            print("[UnitMigration] Completed meters → yards migration")
        } catch {
            print("[UnitMigration] Save failed: \(error.localizedDescription)")
        }
    }

    private static func migrateSwimSessions(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<SwimSession>()
        guard let sessions = try? modelContext.fetch(descriptor) else { return }

        for session in sessions {
            session.distance *= metersToYards
            if var data = session.detailedData {
                data.totalDistance *= metersToYards
                if let longest = data.longestContinuousDistance {
                    data.longestContinuousDistance = longest * metersToYards
                }
                // Pace is min per 100 units of distance; min/100m → min/100yd divides by 1.09361
                if let pace = data.averagePace {
                    data.averagePace = pace / metersToYards
                }
                data.sets = data.sets.map { set in
                    var updated = set
                    updated.totalDistance *= metersToYards
                    if let pace = set.averagePace {
                        updated.averagePace = pace / metersToYards
                    }
                    updated.laps = set.laps.map { lap in
                        var l = lap
                        l.distance *= metersToYards
                        if let pace = lap.pace {
                            l.pace = pace / metersToYards
                        }
                        return l
                    }
                    return updated
                }
                session.detailedData = data
            }
        }
        print("[UnitMigration] Converted \(sessions.count) swim sessions")
    }

    private static func migrateWorkouts(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Workout>()
        guard let workouts = try? modelContext.fetch(descriptor) else { return }

        for workout in workouts {
            workout.totalDistance = Int((Double(workout.totalDistance) * metersToYards).rounded())
            workout.sets = workout.sets.map { set in
                WorkoutSet(
                    id: set.id,
                    type: set.type,
                    reps: set.reps,
                    distance: Int((Double(set.distance) * metersToYards).rounded()),
                    rest: set.rest,
                    instructions: set.instructions
                )
            }
        }
        print("[UnitMigration] Converted \(workouts.count) workouts")
    }

    private static func migrateEnduranceTargets(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<EnduranceTarget>()
        guard let targets = try? modelContext.fetch(descriptor) else { return }

        for target in targets {
            target.targetDistance *= metersToYards
        }
        print("[UnitMigration] Converted \(targets.count) endurance targets")
    }
}
