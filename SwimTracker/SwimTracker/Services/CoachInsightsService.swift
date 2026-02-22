import Foundation
import SwiftData

// MARK: - Data Model

enum InsightType {
    case celebration  // PRs, streaks, achievements
    case warning      // gaps, overtraining, declining metrics
    case suggestion   // ready for progression, try new focus
    case milestone    // goal proximity, percentages
}

struct InsightAction {
    let label: String
    let action: () -> Void
}

struct CoachInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let icon: String
    let title: String
    let description: String
    let action: InsightAction?
    let priority: Int // 1 = highest

    static func celebration(icon: String = "party.popper.fill", title: String, description: String, action: InsightAction? = nil) -> CoachInsight {
        CoachInsight(type: .celebration, icon: icon, title: title, description: description, action: action, priority: 2)
    }

    static func warning(icon: String = "exclamationmark.triangle.fill", title: String, description: String, action: InsightAction? = nil) -> CoachInsight {
        CoachInsight(type: .warning, icon: icon, title: title, description: description, action: action, priority: 1)
    }

    static func suggestion(icon: String = "lightbulb.fill", title: String, description: String, action: InsightAction? = nil) -> CoachInsight {
        CoachInsight(type: .suggestion, icon: icon, title: title, description: description, action: action, priority: 3)
    }

    static func milestone(icon: String = "target", title: String, description: String, action: InsightAction? = nil) -> CoachInsight {
        CoachInsight(type: .milestone, icon: icon, title: title, description: description, action: action, priority: 4)
    }
}

// MARK: - Service

@MainActor @Observable
final class CoachInsightsService {

    private(set) var insights: [CoachInsight] = []

    func generateInsights(sessions: [SwimSession], onAction: @escaping (String) -> Void) {
        var results: [CoachInsight] = []

        let sorted = sessions.sorted { $0.date > $1.date }
        let recent = Array(sorted.prefix(14)) // last ~14 sessions
        let lastWeek = recent.filter { $0.date > Calendar.current.date(byAdding: .day, value: -7, to: .now)! }
        let prevWeek = recent.filter {
            let sevenAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
            let fourteenAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now)!
            return $0.date > fourteenAgo && $0.date <= sevenAgo
        }

        // 1. New PR Detection
        if let prInsight = checkForNewPR(sessions: sorted, onAction: onAction) {
            results.append(prInsight)
        }

        // 2. Streak Detection
        if let streakInsight = checkForStreak(sessions: sorted, onAction: onAction) {
            results.append(streakInsight)
        }

        // 3. Gap Detection
        if let gapInsight = checkForGap(sessions: sorted, onAction: onAction) {
            results.append(gapInsight)
        }

        // 4. SWOLF Trends
        if let swolfInsight = checkSWOLFTrend(lastWeek: lastWeek, prevWeek: prevWeek, onAction: onAction) {
            results.append(swolfInsight)
        }

        // 5. Goal Proximity (3,000m continuous)
        if let goalInsight = checkGoalProximity(sessions: sorted, onAction: onAction) {
            results.append(goalInsight)
        }

        // 6. Volume Changes
        if let volumeInsight = checkVolumeChanges(lastWeek: lastWeek, prevWeek: prevWeek, onAction: onAction) {
            results.append(volumeInsight)
        }

        // 7. Recovery Needs
        if let recoveryInsight = checkRecoveryNeeds(sessions: sorted, onAction: onAction) {
            results.append(recoveryInsight)
        }

        // Sort by priority (lower number = higher priority)
        insights = results.sorted { $0.priority < $1.priority }
    }

    // MARK: - Pattern Detectors

    private func checkForNewPR(sessions: [SwimSession], onAction: @escaping (String) -> Void) -> CoachInsight? {
        guard sessions.count >= 2 else { return nil }

        // Find PR for longest single set
        var bestDistance: Double = 0
        var bestSession: SwimSession?

        for session in sessions {
            let distance = session.longestContinuousDistance
            if distance > bestDistance {
                bestDistance = distance
                bestSession = session
            }
        }

        guard let prSession = bestSession else { return nil }

        // Was the PR set in the last 7 days?
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        guard prSession.date > sevenDaysAgo else { return nil }

        // Find previous best (excluding the PR session)
        let previousBest = sessions
            .filter { $0.id != prSession.id }
            .map(\.longestContinuousDistance)
            .max() ?? 0

        let improvement = Int(bestDistance - previousBest)
        guard improvement > 0 else { return nil }

        return .celebration(
            title: "New Personal Record!",
            description: "You hit \(Int(bestDistance))m continuous \u{2014} up \(improvement)m from your previous best. Keep pushing!",
            action: InsightAction(label: "View Analysis") {
                onAction("Analyze my recent personal record swim in detail")
            }
        )
    }

    private func checkForStreak(sessions: [SwimSession], onAction: @escaping (String) -> Void) -> CoachInsight? {
        guard sessions.count >= 3 else { return nil }

        // Count consecutive swim days (within 3 days of each other = active training)
        var streakCount = 1
        for i in 0..<(sessions.count - 1) {
            let daysBetween = Calendar.current.dateComponents([.day], from: sessions[i + 1].date, to: sessions[i].date).day ?? 0
            if daysBetween <= 3 {
                streakCount += 1
            } else {
                break
            }
        }

        guard streakCount >= 3 else { return nil }

        // Check if most recent session was within the last 4 days (streak still active)
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: .now)!
        guard sessions[0].date > fourDaysAgo else { return nil }

        return .celebration(
            icon: "flame.fill",
            title: "\(streakCount)-Swim Streak!",
            description: "You've been incredibly consistent with \(streakCount) swims in a row. That consistency is what builds endurance!",
            action: InsightAction(label: "Analyze Progress") {
                onAction("Analyze my recent swimming progress and provide insights")
            }
        )
    }

    private func checkForGap(sessions: [SwimSession], onAction: @escaping (String) -> Void) -> CoachInsight? {
        guard let lastSwim = sessions.first else {
            return .warning(
                title: "Time to Get Started!",
                description: "No swim sessions recorded yet. Log your first swim or import from Apple Watch to begin training.",
                action: nil
            )
        }

        let daysSinceLastSwim = Calendar.current.dateComponents([.day], from: lastSwim.date, to: .now).day ?? 0

        if daysSinceLastSwim >= 5 {
            return .warning(
                title: "\(daysSinceLastSwim) Days Since Last Swim",
                description: "Getting back in the pool soon will help maintain the fitness you've built. Even a short easy swim helps!",
                action: InsightAction(label: "Generate Workouts") {
                    onAction("Generate my next 3 workouts based on my recent progress. Note: I haven't swum in \(daysSinceLastSwim) days, so ease me back in.")
                }
            )
        } else if daysSinceLastSwim >= 3 {
            return .warning(
                icon: "clock.badge.exclamationmark.fill",
                title: "Haven't Swum in \(daysSinceLastSwim) Days",
                description: "A training gap is forming. Try to get a swim in soon to keep your momentum going.",
                action: InsightAction(label: "Adjust Schedule") {
                    onAction("I'd like to adjust my training plan \u{2014} I haven't been able to swim in \(daysSinceLastSwim) days.")
                }
            )
        }

        return nil
    }

    private func checkSWOLFTrend(lastWeek: [SwimSession], prevWeek: [SwimSession], onAction: @escaping (String) -> Void) -> CoachInsight? {
        let lastWeekSWOLF = averageSWOLF(for: lastWeek)
        let prevWeekSWOLF = averageSWOLF(for: prevWeek)

        guard let current = lastWeekSWOLF, let previous = prevWeekSWOLF else { return nil }

        let change = current - previous
        let percentChange = abs(change / previous * 100)

        guard percentChange >= 3 else { return nil } // Only show if >= 3% change

        if change < 0 {
            // SWOLF decreased = improving (lower is better)
            return .suggestion(
                icon: "chart.line.downtrend.xyaxis",
                title: "SWOLF Improving!",
                description: "Your efficiency is up \u{2014} SWOLF dropped from \(Int(previous)) to \(Int(current)). You're getting more distance per stroke.",
                action: InsightAction(label: "View Analysis") {
                    onAction("Analyze my recent SWOLF improvement and what's driving it")
                }
            )
        } else {
            // SWOLF increased = declining
            return .warning(
                icon: "chart.line.uptrend.xyaxis",
                title: "SWOLF Trending Up",
                description: "Your efficiency dipped from \(Int(previous)) to \(Int(current)). This could mean fatigue or technique drift.",
                action: InsightAction(label: "Get Tips") {
                    onAction("My SWOLF has increased recently. Can you give me technique tips to improve my efficiency?")
                }
            )
        }
    }

    private func checkGoalProximity(sessions: [SwimSession], onAction: @escaping (String) -> Void) -> CoachInsight? {
        let goalDistance = 3000.0 // meters continuous for Alcatraz
        let currentBest = sessions.map(\.longestContinuousDistance).max() ?? 0

        guard currentBest > 0 else { return nil }

        let progress = currentBest / goalDistance
        let percent = Int(progress * 100)

        // Show milestones at key thresholds
        if percent >= 90 {
            return .milestone(
                icon: "star.fill",
                title: "Almost There \u{2014} \(percent)% to Goal!",
                description: "Your best continuous swim is \(Int(currentBest))m. You're so close to the 3,000m Alcatraz goal!",
                action: InsightAction(label: "View Progress") {
                    onAction("I'm at \(percent)% of my Alcatraz goal. Analyze how close I am and what I need to do to get there.")
                }
            )
        } else if percent >= 50 {
            return .milestone(
                title: "Halfway to Alcatraz! \(percent)%",
                description: "Your best continuous distance is \(Int(currentBest))m out of 3,000m. Strong progress!",
                action: InsightAction(label: "View Progress") {
                    onAction("I'm at \(percent)% of my Alcatraz goal with \(Int(currentBest))m best continuous. What should I focus on next?")
                }
            )
        } else if percent >= 25 {
            return .milestone(
                title: "\(percent)% to Alcatraz Goal",
                description: "Best continuous: \(Int(currentBest))m of 3,000m. You're building a strong foundation!",
                action: InsightAction(label: "View Progress") {
                    onAction("Analyze my progress toward the 3,000m Alcatraz goal \u{2014} currently at \(Int(currentBest))m best continuous.")
                }
            )
        }

        return nil
    }

    private func checkVolumeChanges(lastWeek: [SwimSession], prevWeek: [SwimSession], onAction: @escaping (String) -> Void) -> CoachInsight? {
        guard !prevWeek.isEmpty else { return nil }

        let lastWeekVolume = lastWeek.reduce(0.0) { $0 + $1.distance }
        let prevWeekVolume = prevWeek.reduce(0.0) { $0 + $1.distance }

        guard prevWeekVolume > 0 else { return nil }

        let change = (lastWeekVolume - prevWeekVolume) / prevWeekVolume * 100

        if change >= 25 {
            return .suggestion(
                icon: "arrow.up.right.circle.fill",
                title: "Volume Up \(Int(change))%!",
                description: "You swam \(Int(lastWeekVolume))m this week vs \(Int(prevWeekVolume))m last week. Great effort \u{2014} watch for fatigue.",
                action: InsightAction(label: "Generate Workouts") {
                    onAction("Generate my next 3 workouts. I've increased volume significantly this week, so balance progression with recovery.")
                }
            )
        } else if change <= -30 {
            return .suggestion(
                icon: "arrow.down.right.circle.fill",
                title: "Volume Down \(Int(abs(change)))%",
                description: "You swam \(Int(lastWeekVolume))m this week vs \(Int(prevWeekVolume))m last week. Let's get back on track!",
                action: InsightAction(label: "Adjust Plan") {
                    onAction("My swim volume dropped this week. Can you help me adjust my plan to get back on track?")
                }
            )
        }

        return nil
    }

    private func checkRecoveryNeeds(sessions: [SwimSession], onAction: @escaping (String) -> Void) -> CoachInsight? {
        let recentHard = sessions.prefix(4)
        guard recentHard.count >= 3 else { return nil }

        // Check if last 3 sessions were all high difficulty (7+)
        let lastThree = Array(recentHard.prefix(3))
        let allHard = lastThree.allSatisfy { $0.difficulty >= 7 }

        guard allHard else { return nil }

        // Make sure these are recent (within last 10 days)
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        guard lastThree.last!.date > tenDaysAgo else { return nil }

        let avgDifficulty = lastThree.reduce(0) { $0 + $1.difficulty } / lastThree.count
        return .warning(
            icon: "bed.double.fill",
            title: "Recovery Check",
            description: "Your last 3 swims averaged \(avgDifficulty)/10 difficulty. Consider an easy recovery swim or rest day to avoid overtraining.",
            action: InsightAction(label: "Generate Easy Workout") {
                onAction("Generate my next 3 workouts. My last 3 swims were very hard (avg \(avgDifficulty)/10), so I need a recovery-focused plan.")
            }
        )
    }

    // MARK: - Helpers

    private func averageSWOLF(for sessions: [SwimSession]) -> Double? {
        let swolfs = sessions.compactMap { $0.detailedData?.averageSWOLF }
        guard !swolfs.isEmpty else { return nil }
        return swolfs.reduce(0, +) / Double(swolfs.count)
    }
}
