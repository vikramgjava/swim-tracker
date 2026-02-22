import Foundation

struct WeeklyEnduranceProgress {
    let weekStart: Date
    let weekEnd: Date
    let targetDistance: Double
    let bestAchieved: Double
    let daysLeft: Int
    let isCoachTarget: Bool
}

struct WeeklyEnduranceService {
    private let trainingStart: Date
    private let goalDate: Date
    private let goalDistance = 3000.0
    private let coachTargetLookup: [Int: Double]

    /// Calendar with Sunday as first day of week
    private static var sundayCalendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 1 // Sunday
        return cal
    }()

    var hasCoachTargets: Bool {
        !coachTargetLookup.isEmpty
    }

    init(enduranceTargets: [EnduranceTarget] = []) {
        // Week 0 starts Sunday Dec 28, 2025
        trainingStart = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 28)) ?? .now
        goalDate = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 30)) ?? .now
        var lookup: [Int: Double] = [:]
        for target in enduranceTargets {
            lookup[target.weekNumber] = target.targetDistance
        }
        coachTargetLookup = lookup
    }

    func currentWeekProgress(sessions: [SwimSession]) -> WeeklyEnduranceProgress {
        let calendar = Self.sundayCalendar
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: .now)!
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekInterval.start)!

        let weekNum = weekNumber(for: weekInterval.start)
        let baseline = computeBaseline(sessions: sessions)
        let (target, isCoach) = weekTarget(weekNumber: weekNum, baselineDistance: baseline)

        let thisWeekSessions = sessions.filter {
            $0.date >= weekInterval.start && $0.date < weekInterval.end
        }
        let bestContinuous = thisWeekSessions.map(\.longestContinuousDistance).max() ?? 0

        let daysLeft = max(calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: weekEnd).day ?? 0, 0)

        return WeeklyEnduranceProgress(
            weekStart: weekInterval.start,
            weekEnd: weekEnd,
            targetDistance: target,
            bestAchieved: bestContinuous,
            daysLeft: daysLeft,
            isCoachTarget: isCoach
        )
    }

    func lastWeekProgress(sessions: [SwimSession]) -> WeeklyEnduranceProgress {
        let calendar = Self.sundayCalendar
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)!.start
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!
        let lastWeekInterval = calendar.dateInterval(of: .weekOfYear, for: lastWeekStart)!
        let lastWeekEnd = calendar.date(byAdding: .day, value: 6, to: lastWeekStart)!

        let weekNum = weekNumber(for: lastWeekStart)
        let baseline = computeBaseline(sessions: sessions)
        let (target, isCoach) = weekTarget(weekNumber: weekNum, baselineDistance: baseline)

        let lastWeekSessions = sessions.filter {
            $0.date >= lastWeekInterval.start && $0.date < lastWeekInterval.end
        }
        let bestContinuous = lastWeekSessions.map(\.longestContinuousDistance).max() ?? 0

        return WeeklyEnduranceProgress(
            weekStart: lastWeekStart,
            weekEnd: lastWeekEnd,
            targetDistance: target,
            bestAchieved: bestContinuous,
            daysLeft: 0,
            isCoachTarget: isCoach
        )
    }

    /// Get the coach target for a given week number, with interpolation for gaps
    func coachTarget(forWeek week: Int) -> Double? {
        // Direct hit
        if let direct = coachTargetLookup[week] {
            return direct
        }

        // Interpolate between neighbors
        let sortedWeeks = coachTargetLookup.keys.sorted()
        guard !sortedWeeks.isEmpty else { return nil }

        // Before first or after last → no interpolation
        guard let firstWeek = sortedWeeks.first, let lastWeek = sortedWeeks.last else { return nil }
        if week < firstWeek || week > lastWeek { return nil }

        // Find surrounding weeks
        var lowerWeek = firstWeek
        var upperWeek = lastWeek
        for w in sortedWeeks {
            if w <= week { lowerWeek = w }
            if w >= week { upperWeek = w; break }
        }

        guard lowerWeek != upperWeek,
              let lowerVal = coachTargetLookup[lowerWeek],
              let upperVal = coachTargetLookup[upperWeek] else {
            return coachTargetLookup[lowerWeek]
        }

        let fraction = Double(week - lowerWeek) / Double(upperWeek - lowerWeek)
        return round(lowerVal + (upperVal - lowerVal) * fraction)
    }

    // MARK: - Internal

    func weekNumber(for weekStart: Date) -> Int {
        let calendar = Self.sundayCalendar
        return max(
            calendar.dateComponents([.weekOfYear], from: trainingStart, to: weekStart).weekOfYear ?? 0,
            0
        )
    }

    // MARK: - Private

    private func weekTarget(weekNumber: Int, baselineDistance: Double) -> (target: Double, isCoach: Bool) {
        // Try coach target first (with interpolation)
        if let coachVal = coachTarget(forWeek: weekNumber) {
            return (coachVal, true)
        }

        // Fall back to linear formula
        let calendar = Self.sundayCalendar
        let totalWeeks = max(
            calendar.dateComponents([.weekOfYear], from: trainingStart, to: goalDate).weekOfYear ?? 1,
            1
        )
        let weeklyIncrement = (goalDistance - baselineDistance) / Double(totalWeeks)
        return (round(baselineDistance + weeklyIncrement * Double(weekNumber)), false)
    }

    private func computeBaseline(sessions: [SwimSession]) -> Double {
        let earliest = sessions.min { $0.date < $1.date }
        return earliest?.longestContinuousDistance ?? 625.0
    }
}
