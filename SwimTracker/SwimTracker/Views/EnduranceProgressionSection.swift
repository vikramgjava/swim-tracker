import SwiftUI
import Charts

// MARK: - Data Model

struct EnduranceChartPoint: Identifiable {
    let id: Int // week number 0...N
    let weekStart: Date
    let weekEnd: Date
    let fixedPlan: Double
    let adaptivePlan: Double
    let actual: Double?
}

// MARK: - Endurance Progression Section

struct EnduranceProgressionSection: View {
    let sessions: [SwimSession]
    var enduranceTargets: [EnduranceTarget] = []

    @State private var showAllWeeks = false

    private var coachService: WeeklyEnduranceService {
        WeeklyEnduranceService(enduranceTargets: enduranceTargets)
    }

    private var hasCoachTargets: Bool {
        !enduranceTargets.isEmpty
    }

    // Constants
    private let startingEndurance = 50.0
    private let goalDistance = 3000.0

    /// Calendar with Sunday as first day of week
    private static var sundayCalendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 1 // Sunday
        return cal
    }()

    /// Week 0 starts Sunday Dec 28, 2025 (the Sunday before Jan 1, 2026)
    private static let trainingStart: Date = {
        // Dec 28, 2025 is a Sunday
        Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 28))!
    }()

    private static let goalDate: Date = {
        Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 30))!
    }()

    private var totalWeeks: Int {
        let weeks = Self.sundayCalendar.dateComponents(
            [.weekOfYear], from: Self.trainingStart, to: Self.goalDate
        ).weekOfYear ?? 30
        return max(weeks, 1)
    }

    private var fixedWeeklyIncrease: Double {
        (goalDistance - startingEndurance) / Double(totalWeeks)
    }

    private var currentBest: Double {
        sessions
            .filter { $0.date >= Self.trainingStart }
            .map(\.longestContinuousDistance)
            .max() ?? startingEndurance
    }

    private var currentWeekNumber: Int {
        let weeks = Self.sundayCalendar.dateComponents(
            [.weekOfYear], from: Self.trainingStart, to: Date()
        ).weekOfYear ?? 0
        return min(max(weeks, 0), totalWeeks)
    }

    // MARK: - Chart Data

    /// Best achieved up to a given date (only sessions from training start onwards)
    private func bestUpToDate(_ date: Date) -> Double {
        let best = sessions
            .filter { $0.date >= Self.trainingStart && $0.date <= date }
            .map(\.longestContinuousDistance)
            .max()
        return best ?? startingEndurance
    }

    private var chartData: [EnduranceChartPoint] {
        let calendar = Self.sundayCalendar
        let best = currentBest
        let curWeek = currentWeekNumber
        let weeksLeft = totalWeeks - curWeek
        var points: [EnduranceChartPoint] = []

        for week in 0...totalWeeks {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: week, to: Self.trainingStart)!
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!

            let fixedTarget = startingEndurance + fixedWeeklyIncrease * Double(week)

            let adaptiveTarget: Double = {
                // Use coach target if available (with interpolation)
                if let coachVal = coachService.coachTarget(forWeek: week) {
                    return coachVal
                }
                // Fall back to adaptive formula
                if week <= curWeek {
                    return bestUpToDate(weekEnd)
                } else {
                    guard weeksLeft > 0 else { return goalDistance }
                    let elapsed = week - curWeek
                    return best + (goalDistance - best) / Double(weeksLeft) * Double(elapsed)
                }
            }()

            let actual: Double? = {
                guard weekStart <= Date() else { return nil }
                let nextWeek = calendar.date(byAdding: .day, value: 7, to: weekStart)!
                let weekSessions = sessions.filter { $0.date >= weekStart && $0.date < nextWeek }
                guard !weekSessions.isEmpty else { return nil }
                return weekSessions.map(\.longestContinuousDistance).max()
            }()

            points.append(EnduranceChartPoint(
                id: week, weekStart: weekStart, weekEnd: weekEnd,
                fixedPlan: fixedTarget, adaptivePlan: adaptiveTarget, actual: actual
            ))
        }
        return points
    }

    // MARK: - Body

    var body: some View {
        let data = chartData
        let curWeek = currentWeekNumber

        // Most recent actual (latest week with data)
        let mostRecentActual: Double = data
            .filter { $0.actual != nil }
            .last?.actual ?? 0

        // Last week's actual (for momentum comparison)
        let weeksWithActual = data.filter { $0.actual != nil }
        let lastWeekActual: Double? = weeksWithActual.count >= 2
            ? weeksWithActual[weeksWithActual.count - 2].actual
            : nil

        // This week's adaptive/coach target
        let thisWeekTarget: Double = data.indices.contains(curWeek) ? data[curWeek].adaptivePlan : 0

        // Next week's adaptive/coach target
        let nextWeekTarget: Double = data.indices.contains(curWeek + 1) ? data[curWeek + 1].adaptivePlan : 0

        let planLabel = hasCoachTargets ? "Coach Plan" : "Adaptive"

        SectionCard(title: "Endurance Progression", icon: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: 16) {
                // Legend
                HStack(spacing: 14) {
                    legendItem(color: .gray, label: "Fixed Plan", dashed: true)
                    legendItem(color: .purple, label: hasCoachTargets ? "Coach Plan" : "Adaptive", dashed: true)
                    legendItem(color: .purple, label: "Actual", dashed: false)
                }

                // Chart
                Chart {
                    // Fixed plan (gray dashed)
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Week", point.id),
                            y: .value("Distance", point.fixedPlan),
                            series: .value("Series", "Fixed Plan")
                        )
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }

                    // Adaptive plan (purple dashed)
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Week", point.id),
                            y: .value("Distance", point.adaptivePlan),
                            series: .value("Series", "Adaptive")
                        )
                        .foregroundStyle(.purple.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }

                    // Actual performance (purple solid + points)
                    ForEach(data.filter { $0.actual != nil }) { point in
                        LineMark(
                            x: .value("Week", point.id),
                            y: .value("Distance", point.actual!),
                            series: .value("Series", "Actual")
                        )
                        .foregroundStyle(.purple)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Week", point.id),
                            y: .value("Distance", point.actual!)
                        )
                        .foregroundStyle(.purple)
                        .symbolSize(40)
                    }

                    // Current week marker
                    RuleMark(x: .value("Week", curWeek))
                        .foregroundStyle(.blue.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .top, alignment: .center) {
                            Text("Now")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.blue)
                        }
                }
                .chartYScale(domain: 0...3200)
                .chartXScale(domain: 0...totalWeeks)
                .chartXAxis {
                    AxisMarks(values: .stride(by: 5)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color(.systemGray4))
                        AxisValueLabel {
                            if let week = value.as(Int.self) {
                                let weekDate = Self.sundayCalendar.date(
                                    byAdding: .weekOfYear, value: week, to: Self.trainingStart
                                )!
                                let fmt = DateFormatter()
                                let _ = (fmt.dateFormat = "MM/dd")
                                VStack(spacing: 1) {
                                    Text("W\(week)")
                                        .font(.caption2)
                                    Text(fmt.string(from: weekDate))
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .stride(by: 500)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color(.systemGray4))
                        AxisValueLabel {
                            if let m = value.as(Double.self) {
                                Text("\(Int(m))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 200)

                // Current status summary
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("Most Recent")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        let recentColor: Color = lastWeekActual.map({ mostRecentActual >= $0 }) ?? true ? .green : .orange
                        Text("\(Int(mostRecentActual))m")
                            .font(.subheadline.bold())
                            .foregroundStyle(recentColor)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("This Week")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(thisWeekTarget))m")
                            .font(.subheadline.bold())
                            .foregroundStyle(.purple.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("Next (Adaptive)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(nextWeekTarget))m")
                            .font(.subheadline.bold())
                            .foregroundStyle(.purple.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("Week")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(curWeek)/\(totalWeeks)")
                            .font(.subheadline.bold().monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)
                }

                Divider()

                // Week details toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showAllWeeks.toggle()
                    }
                } label: {
                    HStack {
                        Text("Week Details")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: showAllWeeks ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                if showAllWeeks {
                    weekListView(data: data)
                }
            }
        }
    }

    // MARK: - Week List

    private func weekListView(data: [EnduranceChartPoint]) -> some View {
        VStack(spacing: 8) {
            ForEach(data) { point in
                let nextTarget: Double? = point.id < totalWeeks ? data[point.id + 1].adaptivePlan : nil
                weekCard(point: point, nextTarget: nextTarget)
            }
        }
    }

    private func weekCard(point: EnduranceChartPoint, nextTarget: Double?) -> some View {
        let isCurrent = point.id == currentWeekNumber
        let isPast = point.weekEnd < Date()
        let isFuture = !isPast && !isCurrent

        return VStack(alignment: .leading, spacing: 6) {
            weekCardHeader(point: point, isCurrent: isCurrent, isPast: isPast)

            if !isFuture {
                weekCardActual(point: point, isCurrent: isCurrent)
            }

            weekDetailRow(
                label: "Week Target",
                value: "\(Int(point.adaptivePlan))m",
                valueColor: .primary
            )

            weekCardGap(point: point, isCurrent: isCurrent, isFuture: isFuture)

            if let next = nextTarget {
                weekDetailRow(
                    label: "Next Week Target",
                    value: "\(Int(next))m",
                    valueColor: .secondary
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrent ? Color.purple.opacity(0.06) : Color(.systemGray6).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrent ? Color.purple.opacity(0.3) : .clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func weekCardHeader(point: EnduranceChartPoint, isCurrent: Bool, isPast: Bool) -> some View {
        HStack {
            Text("W\(point.id)  \(formatWeekRange(point.weekStart, point.weekEnd))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isCurrent ? .purple : .primary)
            Spacer()
            weekStatusIcon(point: point, isCurrent: isCurrent, isPast: isPast)
        }
    }

    @ViewBuilder
    private func weekStatusIcon(point: EnduranceChartPoint, isCurrent: Bool, isPast: Bool) -> some View {
        if isCurrent {
            Text("\u{1F3CA}")
                .font(.system(size: 12))
        } else if isPast {
            if let actual = point.actual, actual >= point.adaptivePlan {
                Text("\u{2705}")
                    .font(.system(size: 12))
            } else if point.actual != nil {
                Text("\u{26A0}\u{FE0F}")
                    .font(.system(size: 12))
            } else {
                Text("\u{2014}")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        } else {
            Text("\u{1F4C5}")
                .font(.system(size: 12))
        }
    }

    private func weekCardActual(point: EnduranceChartPoint, isCurrent: Bool) -> some View {
        let actualText: String
        let color: Color
        if let actual = point.actual {
            actualText = "\(Int(actual))m\(isCurrent ? " (so far)" : "")"
            color = .purple
        } else {
            actualText = "No swims"
            color = .secondary
        }
        return weekDetailRow(label: "Week Actual", value: actualText, valueColor: color)
    }

    @ViewBuilder
    private func weekCardGap(point: EnduranceChartPoint, isCurrent: Bool, isFuture: Bool) -> some View {
        if !isFuture, let actual = point.actual {
            let gap = actual - point.adaptivePlan
            let sign = gap >= 0 ? "+" : ""
            let suffix = isCurrent ? daysLeftSuffix(point.weekEnd) : ""
            weekDetailRow(
                label: "Gap",
                value: "\(sign)\(Int(gap))m\(suffix)",
                valueColor: gap >= 0 ? .green : .orange
            )
        } else if isCurrent && point.actual == nil {
            weekDetailRow(
                label: "Gap",
                value: "No swims yet\(daysLeftSuffix(point.weekEnd))",
                valueColor: .orange
            )
        }
    }

    private func weekDetailRow(label: String, value: String, valueColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(valueColor)
        }
    }

    private func daysLeftSuffix(_ weekEnd: Date) -> String {
        let days = max(Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: .now), to: weekEnd
        ).day ?? 0, 0)
        return " (\(days) day\(days == 1 ? "" : "s") left)"
    }

    private func formatWeekRange(_ start: Date, _ end: Date) -> String {
        let fmt = DateFormatter()
        let cal = Calendar.current
        let sm = cal.component(.month, from: start)
        let em = cal.component(.month, from: end)
        if sm == em {
            fmt.dateFormat = "MMM d"
            let endDay = cal.component(.day, from: end)
            return "\(fmt.string(from: start))-\(endDay)"
        } else {
            fmt.dateFormat = "MMM d"
            return "\(fmt.string(from: start))-\(fmt.string(from: end))"
        }
    }

    // MARK: - Legend

    private func legendItem(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            if dashed {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color.opacity(0.6))
                            .frame(width: 4, height: 2)
                    }
                }
                .frame(width: 16)
            } else {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 16, height: 3)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
