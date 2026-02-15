import Foundation
import HealthKit

@MainActor @Observable
class HealthKitManager {
    var isAuthorized = false
    var recentSwimWorkouts: [HKWorkout] = []
    var isLoading = false
    var errorMessage: String?

    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isAvailable else {
            errorMessage = "HealthKit is not available on this device."
            return
        }

        var typesToRead: Set<HKObjectType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.swimmingStrokeCount)
        ]
        if #available(iOS 18.0, *) {
            typesToRead.insert(HKQuantityType(.workoutEffortScore))
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            isAuthorized = true
        } catch {
            errorMessage = "Health authorization failed: \(error.localizedDescription)"
        }
    }

    /// Convenience: fetch swim workouts from a start date to now
    func fetchRecentSwimWorkouts(since startDate: Date) async {
        await fetchSwimWorkouts(from: startDate, to: .now)
    }

    /// Fetch swim workouts within a date range and store in recentSwimWorkouts
    func fetchSwimWorkouts(from startDate: Date, to endDate: Date) async {
        guard isAvailable else { return }

        isLoading = true
        defer { isLoading = false }

        let workoutType = HKWorkoutType.workoutType()
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let activityPredicate = HKQuery.predicateForWorkouts(with: .swimming)
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, activityPredicate])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        do {
            let results: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: workoutType,
                    predicate: compound,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples as? [HKWorkout] ?? [])
                    }
                }
                healthStore.execute(query)
            }
            recentSwimWorkouts = results
        } catch {
            errorMessage = "Failed to fetch workouts: \(error.localizedDescription)"
        }
    }

    func extractWorkoutData(workout: HKWorkout) -> (distance: Double, duration: Double, date: Date) {
        let distanceMeters = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        let durationMinutes = workout.duration / 60.0
        return (distance: distanceMeters, duration: durationMinutes, date: workout.startDate)
    }

    // MARK: - Effort Score

    /// Fetch the user's effort rating (1-10) for a workout, if available
    func fetchEffortScore(for workout: HKWorkout) async -> Int? {
        guard isAvailable else { return nil }
        if #available(iOS 18.0, *) {
            // Query effort score samples overlapping the workout window
            // Use a 30-minute buffer after workout end for post-workout ratings
            let samples = await querySamples(
                type: HKQuantityType(.workoutEffortScore),
                start: workout.startDate,
                end: workout.endDate.addingTimeInterval(1800)
            )
            guard let sample = samples.first else {
                print("[HealthKit] No effort score found for workout on \(workout.startDate.formatted())")
                return nil
            }
            let effort = Int(sample.quantity.doubleValue(for: .appleEffortScore()))
            let mapped = max(1, min(10, effort))
            print("[HealthKit] Effort score found: \(effort) → difficulty \(mapped)")
            return mapped
        } else {
            print("[HealthKit] Effort score not available (requires iOS 18+)")
            return nil
        }
    }

    // MARK: - Detailed Workout Data

    func fetchWorkoutDetails(for workout: HKWorkout) async -> WorkoutDetailedData? {
        guard isAvailable else { return nil }

        let startDate = workout.startDate
        let endDate = workout.endDate

        // Fetch all sample types in parallel
        async let distanceSamples = querySamples(
            type: HKQuantityType(.distanceSwimming),
            start: startDate,
            end: endDate
        )
        async let strokeCountSamples = querySamples(
            type: HKQuantityType(.swimmingStrokeCount),
            start: startDate,
            end: endDate
        )
        async let heartRateSamples = querySamples(
            type: HKQuantityType(.heartRate),
            start: startDate,
            end: endDate
        )
        let distances = await distanceSamples
        let strokes = await strokeCountSamples
        let hrSamples = await heartRateSamples

        // Build laps from distance samples (each sample = one lap)
        guard !distances.isEmpty else {
            // Fallback: single lap for the whole workout
            let totalDist = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
            let duration = workout.duration
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            let allHR = hrSamples.map { Int($0.quantity.doubleValue(for: bpmUnit)) }
            let avgHR = allHR.isEmpty ? nil : allHR.reduce(0, +) / allHR.count
            let maxHR = allHR.max()
            let pace = totalDist > 0 ? (duration / 60.0) / (totalDist / 100.0) : nil

            let lap = LapData(
                distance: totalDist,
                duration: duration,
                pace: pace,
                heartRate: avgHR
            )
            let set = SwimSet(
                laps: [lap],
                restAfter: 0,
                totalDistance: totalDist,
                totalDuration: duration,
                averagePace: pace,
                strokeType: "Unknown",
                averageHeartRate: avgHR,
                maxHeartRate: maxHR
            )
            print("[HealthKit] Fallback: no distance samples, single set. totalDistance=\(Int(totalDist))m, longestContinuousDistance=\(Int(totalDist))m")
            return WorkoutDetailedData(
                sets: [set],
                totalDistance: totalDist,
                totalDuration: duration,
                longestContinuousDistance: totalDist,
                averagePace: pace,
                averageHeartRate: avgHR,
                maxHeartRate: maxHR
            )
        }

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        var laps: [LapData] = []
        var lapEndTimes: [Date] = []

        for sample in distances {
            let lapDistance = sample.quantity.doubleValue(for: .meter())
            let lapDuration = sample.endDate.timeIntervalSince(sample.startDate)
            let lapStart = sample.startDate
            let lapEnd = sample.endDate

            // Match stroke count by overlapping time range
            let matchingStrokes = strokes.filter { $0.startDate >= lapStart && $0.endDate <= lapEnd }
            let strokeCount = matchingStrokes.isEmpty ? nil : Int(matchingStrokes.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .count()) })

            // Compute SWOLF = strokeCount + duration in seconds
            let swolf: Int? = strokeCount.map { $0 + Int(lapDuration) }

            // Compute pace = (duration / 60) / (distance / 100) minutes per 100m
            let pace: Double? = lapDistance > 0 ? (lapDuration / 60.0) / (lapDistance / 100.0) : nil

            // Get stroke style from metadata on stroke count samples
            let strokeType: String? = matchingStrokes.first.flatMap { sample in
                guard let styleValue = sample.metadata?[HKMetadataKeySwimmingStrokeStyle] as? NSNumber else { return nil }
                return strokeStyleName(styleValue.intValue)
            }

            // Match HR samples by time range, compute average
            let matchingHR = hrSamples.filter { $0.startDate >= lapStart && $0.startDate < lapEnd }
            let avgHR: Int? = matchingHR.isEmpty ? nil : Int(matchingHR.reduce(0.0) { $0 + $1.quantity.doubleValue(for: bpmUnit) } / Double(matchingHR.count))

            let lap = LapData(
                distance: lapDistance,
                duration: lapDuration,
                strokeCount: strokeCount,
                swolf: swolf,
                pace: pace,
                strokeType: strokeType,
                heartRate: avgHR
            )
            laps.append(lap)
            lapEndTimes.append(lapEnd)
        }

        // Detect rest periods and group laps into sets
        // Rest = gap > 30s between one lap's end and next lap's start
        var sets: [SwimSet] = []
        var currentSetLaps: [LapData] = []

        for (index, lap) in laps.enumerated() {
            currentSetLaps.append(lap)

            let isLastLap = index == laps.count - 1
            var restDuration: TimeInterval = 0

            if !isLastLap {
                let currentEnd = distances[index].endDate
                let nextStart = distances[index + 1].startDate
                let gap = nextStart.timeIntervalSince(currentEnd)
                if gap > 30 {
                    restDuration = gap
                }
            }

            if restDuration > 30 || isLastLap {
                // Close the current set
                let set = buildSwimSet(laps: currentSetLaps, restAfter: isLastLap ? 0 : restDuration, bpmUnit: bpmUnit, hrSamples: hrSamples, distances: distances, startIndex: index - currentSetLaps.count + 1)
                sets.append(set)
                currentSetLaps = []
            }
        }

        // Compute workout-level aggregates
        let totalDistance = laps.reduce(0.0) { $0 + $1.distance }
        let totalDuration = laps.reduce(0.0) { $0 + $1.duration }
        let swolfValues = laps.compactMap(\.swolf)
        let avgSWOLF = swolfValues.isEmpty ? nil : Double(swolfValues.reduce(0, +)) / Double(swolfValues.count)
        let avgPace = totalDistance > 0 ? (totalDuration / 60.0) / (totalDistance / 100.0) : nil
        let allHRValues = hrSamples.map { Int($0.quantity.doubleValue(for: bpmUnit)) }
        let avgHR = allHRValues.isEmpty ? nil : allHRValues.reduce(0, +) / allHRValues.count
        let maxHR = allHRValues.max()

        let longestContinuousDistance = sets.map(\.totalDistance).max() ?? totalDistance
        print("[HealthKit] Workout details: \(sets.count) sets, totalDistance=\(Int(totalDistance))m, longestContinuousDistance=\(Int(longestContinuousDistance))m")
        for (i, set) in sets.enumerated() {
            print("[HealthKit]   Set \(i+1): \(Int(set.totalDistance))m, \(set.laps.count) laps, SWOLF=\(set.averageSWOLF.map { String(Int($0)) } ?? "N/A"), stroke=\(set.strokeType)")
        }

        return WorkoutDetailedData(
            sets: sets,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            longestContinuousDistance: longestContinuousDistance,
            averageSWOLF: avgSWOLF,
            averagePace: avgPace,
            averageHeartRate: avgHR,
            maxHeartRate: maxHR
        )
    }

    // MARK: - Private Helpers

    private func buildSwimSet(laps: [LapData], restAfter: TimeInterval, bpmUnit: HKUnit, hrSamples: [HKQuantitySample], distances: [HKQuantitySample], startIndex: Int) -> SwimSet {
        let totalDistance = laps.reduce(0.0) { $0 + $1.distance }
        let totalDuration = laps.reduce(0.0) { $0 + $1.duration }
        let swolfValues = laps.compactMap(\.swolf)
        let avgSWOLF = swolfValues.isEmpty ? nil : Double(swolfValues.reduce(0, +)) / Double(swolfValues.count)
        let avgPace = totalDistance > 0 ? (totalDuration / 60.0) / (totalDistance / 100.0) : nil

        // Majority stroke type
        let strokeTypes = laps.compactMap(\.strokeType)
        let strokeType = mostCommon(strokeTypes) ?? "Unknown"

        // HR stats for the set
        let hrValues = laps.compactMap(\.heartRate)
        let avgHR = hrValues.isEmpty ? nil : hrValues.reduce(0, +) / hrValues.count
        let maxHR = hrValues.max()

        return SwimSet(
            laps: laps,
            restAfter: restAfter,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            averageSWOLF: avgSWOLF,
            averagePace: avgPace,
            strokeType: strokeType,
            averageHeartRate: avgHR,
            maxHeartRate: maxHR
        )
    }

    private func mostCommon(_ items: [String]) -> String? {
        guard !items.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for item in items { counts[item, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func strokeStyleName(_ value: Int) -> String {
        switch value {
        case 0: return "Unknown"
        case 1: return "Mixed"
        case 2: return "Freestyle"
        case 3: return "Backstroke"
        case 4: return "Breaststroke"
        case 5: return "Butterfly"
        case 6: return "Kickboard"
        default: return "Unknown"
        }
    }

    private nonisolated func querySamples(type: HKQuantityType, start: Date, end: Date) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            self.healthStore.execute(query)
        }
    }

}
