import SwiftUI

struct WeeklyEnduranceCard: View {
    let sessions: [SwimSession]
    var enduranceTargets: [EnduranceTarget] = []

    private var service: WeeklyEnduranceService {
        WeeklyEnduranceService(enduranceTargets: enduranceTargets)
    }

    private var thisWeek: WeeklyEnduranceProgress {
        service.currentWeekProgress(sessions: sessions)
    }

    private var lastWeek: WeeklyEnduranceProgress {
        service.lastWeekProgress(sessions: sessions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.purple)
                Text("Weekly Endurance Target")
                    .font(.headline)
                Spacer()
                if service.hasCoachTargets {
                    Text("Coach")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.purple, in: Capsule())
                }
            }

            thisWeekSection

            Divider()

            lastWeekSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - This Week

    private var thisWeekSection: some View {
        let week = thisWeek
        let percentage = week.targetDistance > 0
            ? (week.bestAchieved / week.targetDistance) * 100
            : 0

        return VStack(alignment: .leading, spacing: 8) {
            Text("THIS WEEK (\(formatWeekRange(week.weekStart, week.weekEnd)))")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Target: \(Int(week.targetDistance))m continuous")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Best So Far: \(Int(week.bestAchieved))m")
                    .font(.title3.bold())
            }

            // Progress bar + percentage
            HStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor(percentage).gradient)
                            .frame(width: geo.size.width * min(CGFloat(week.bestAchieved / max(week.targetDistance, 1)), 1.0), height: 8)
                    }
                }
                .frame(height: 8)

                Text("\(Int(min(percentage, 999)))%")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(statusColor(percentage))
            }

            // Status + days left
            HStack {
                let remaining = week.targetDistance - week.bestAchieved
                if remaining > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 8, height: 8)
                        Text("Need \(Int(remaining))m more")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Target achieved!")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                Text("Days left: \(week.daysLeft)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Last Week

    private var lastWeekSection: some View {
        let week = lastWeek
        let diff = week.bestAchieved - week.targetDistance

        return VStack(alignment: .leading, spacing: 8) {
            Text("LAST WEEK (\(formatWeekRange(week.weekStart, week.weekEnd)))")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Target: \(Int(week.targetDistance))m continuous")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Best Achieved: \(Int(week.bestAchieved))m")
                        .font(.title3.bold())
                }

                Spacer()

                if week.bestAchieved > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        if diff >= 0 {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.green)
                            Text("+\(Int(diff))m over target")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                            Text("\(Int(diff))m under target")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                } else {
                    Text("No swims")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(_ percentage: Double) -> Color {
        if percentage >= 100 { return .green }
        if percentage >= 80 { return .yellow }
        return .orange
    }

    private func formatWeekRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)

        if startMonth == endMonth {
            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: start)
            let endDay = calendar.component(.day, from: end)
            return "\(startStr)-\(endDay)"
        } else {
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: start))-\(formatter.string(from: end))"
        }
    }
}
