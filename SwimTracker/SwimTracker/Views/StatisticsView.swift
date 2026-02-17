import SwiftUI
import SwiftData
import Charts

// MARK: - Monthly Progress Time Range

enum MonthlyTimeRange: String, CaseIterable {
    case last6Months = "Last 6 Mo"
    case thisYear = "This Year"
    case allTime = "All Time"
}

// MARK: - StatisticsView

struct StatisticsView: View {
    @Binding var isDarkMode: Bool
    @Query(sort: \SwimSession.date) private var allSessions: [SwimSession]
    @State private var selectedWeekIndex: Int = 7 // 0-7, default to current week (index 7)
    @State private var selectedMonthIndex: Int = 0 // 0 = latest month (reversed order)
    @AppStorage("monthlyProgressTimeRange") private var monthlyTimeRange: String = MonthlyTimeRange.thisYear.rawValue

    private var sessionsWithDetailedData: [SwimSession] {
        allSessions.filter { $0.detailedData != nil }
    }

    private var hasDetailedData: Bool {
        !sessionsWithDetailedData.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if allSessions.isEmpty {
                    ContentUnavailableView(
                        "No Swims Yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Start logging swims to see your progress!")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            if allSessions.isEmpty {
                                Text("No swims logged yet.")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 40)
                            } else {
                                weeklyComparisonSection
                                monthlyComparisonSection
                                if hasDetailedData { efficiencyMetricsSection }
                                paceAnalysisSection
                                if hasDetailedData { heartRateAnalysisSection }
                                trainingVolumeSection
                                quickStatsSection

                                // View All Sessions button
                                NavigationLink {
                                    SessionHistoryView()
                                } label: {
                                    HStack {
                                        Image(systemName: "list.bullet.clipboard")
                                            .foregroundStyle(.blue)
                                        Text("View All Sessions")
                                            .font(.subheadline.bold())
                                        Spacer()
                                        Text("\(allSessions.count) swims")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Statistics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isDarkMode.toggle()
                    } label: {
                        Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                    }
                }
            }
        }
    }

    // MARK: - Weekly Progress

    private var weeklyComparisonSection: some View {
        let weeklyTotals = buildWeeklyTotals()
        let safeIndex = min(selectedWeekIndex, weeklyTotals.count - 1)
        let selected = weeklyTotals.indices.contains(safeIndex) ? weeklyTotals[safeIndex] : nil
        let previous: WeekTotalData? = safeIndex > 0 ? weeklyTotals[safeIndex - 1] : nil
        let hasEnduranceData = weeklyTotals.contains { $0.longestSet != nil }

        // Distance change
        let distChange: Double? = {
            guard let sel = selected, let prev = previous, prev.distance > 0 else { return nil }
            return sel.distance - prev.distance
        }()
        let distChangePct: Double? = {
            guard let change = distChange, let prev = previous, prev.distance > 0 else { return nil }
            return change / prev.distance * 100
        }()

        // Endurance change
        let endurChange: Double? = {
            guard let sel = selected?.longestSet, let prev = previous?.longestSet, prev > 0 else { return nil }
            return sel - prev
        }()
        let endurChangePct: Double? = {
            guard let change = endurChange, let prev = previous?.longestSet, prev > 0 else { return nil }
            return change / prev * 100
        }()

        return SectionCard(title: "Weekly Progress", icon: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: 16) {
                if weeklyTotals.filter({ $0.distance > 0 }).count < 2 {
                    Text("Complete more weeks to see trends.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    // Legend with axis unit labels
                    HStack {
                        Text("km")
                            .font(.caption2.bold())
                            .foregroundStyle(.teal)
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle().fill(.teal).frame(width: 8, height: 8)
                                Text("Distance")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if hasEnduranceData {
                                HStack(spacing: 4) {
                                    Circle().fill(.purple).frame(width: 8, height: 8)
                                    Text("Longest Set")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            HStack(spacing: 4) {
                                Rectangle()
                                    .fill(.secondary.opacity(0.4))
                                    .frame(width: 14, height: 1.5)
                                    .overlay {
                                        Rectangle()
                                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                                            .foregroundStyle(.secondary.opacity(0.6))
                                    }
                                Text("Avg")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        if hasEnduranceData {
                            Text("m")
                                .font(.caption2.bold())
                                .foregroundStyle(.purple)
                        }
                    }

                    // Compute distance axis range (km)
                    let distances = weeklyTotals.map { $0.distance / 1000 }
                    let distMin = distances.filter { $0 > 0 }.min() ?? 0
                    let distMax = distances.max() ?? 1
                    let distRange = distMax - distMin
                    let distStep: Double = distRange < 1 ? 0.25 : distRange < 2 ? 0.5 : distRange < 5 ? 1.0 : 2.0
                    let distYMin = max(0, floor((distMin - distStep * 0.5) / distStep) * distStep)
                    let distYMax = ceil((distMax + distStep * 0.5) / distStep) * distStep

                    // Fixed endurance axis: 0–3,000m (Alcatraz goal)
                    let endurCeil: Double = 3000
                    let distYRange = distYMax - distYMin

                    // Map endurance (meters) → chart Y (km scale)
                    // 0m maps to distYMin, 3000m maps to distYMax
                    let endurToChart: (Double) -> Double = { meters in
                        guard distYRange > 0 else { return distYMin }
                        return distYMin + (meters / endurCeil) * distYRange
                    }

                    // Precompute endurance grid values mapped to chart Y scale
                    // Every 600m: 0, 600, 1200, 1800, 2400, 3000
                    let endurGridChartValues = stride(from: 0.0, through: 3000.0, by: 600.0).map { endurToChart($0) }

                    // 4-week averages (exclude current incomplete week)
                    let completedWeeks = weeklyTotals.filter { !$0.isCurrent }
                    let avgDistanceKm: Double? = {
                        let withData = completedWeeks.filter { $0.distance > 0 }
                        guard !withData.isEmpty else { return nil }
                        return withData.map { $0.distance / 1000 }.reduce(0, +) / Double(withData.count)
                    }()
                    let avgEnduranceM: Double? = {
                        let withData = completedWeeks.compactMap { $0.longestSet }.filter { $0 > 0 }
                        guard !withData.isEmpty else { return nil }
                        return withData.reduce(0, +) / Double(withData.count)
                    }()

                    Chart {
                        // Average reference lines (behind main lines)
                        if let avgDist = avgDistanceKm {
                            RuleMark(y: .value("Value", avgDist))
                                .foregroundStyle(.teal.opacity(0.4))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        }
                        if hasEnduranceData, let avgEndur = avgEnduranceM {
                            RuleMark(y: .value("Value", endurToChart(avgEndur)))
                                .foregroundStyle(.purple.opacity(0.4))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        }

                        // Distance line (teal, solid)
                        ForEach(weeklyTotals.indices, id: \.self) { i in
                            let week = weeklyTotals[i]
                            let isSelected = i == safeIndex
                            LineMark(
                                x: .value("Week", week.label),
                                y: .value("Value", week.distance / 1000),
                                series: .value("Series", "Distance")
                            )
                            .foregroundStyle(.teal)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3))

                            PointMark(
                                x: .value("Week", week.label),
                                y: .value("Value", week.distance / 1000)
                            )
                            .foregroundStyle(isSelected ? .teal : .teal.opacity(0.5))
                            .symbolSize(isSelected ? 80 : 30)
                        }

                        // Endurance line (orange, dashed) — normalized to distance Y-axis
                        if hasEnduranceData {
                            ForEach(weeklyTotals.indices, id: \.self) { i in
                                let week = weeklyTotals[i]
                                let isSelected = i == safeIndex
                                let endurValue = week.longestSet ?? 0
                                let chartY = endurToChart(endurValue)
                                LineMark(
                                    x: .value("Week", week.label),
                                    y: .value("Value", chartY),
                                    series: .value("Series", "Endurance")
                                )
                                .foregroundStyle(.purple)
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 3, dash: [6, 3]))

                                PointMark(
                                    x: .value("Week", week.label),
                                    y: .value("Value", chartY)
                                )
                                .foregroundStyle(endurValue > 0 ? (isSelected ? .purple : .purple.opacity(0.5)) : .clear)
                                .symbolSize(endurValue > 0 ? (isSelected ? 80 : 30) : 0)
                            }
                        }
                    }
                    .chartYScale(domain: distYMin...distYMax)
                    .chartYAxis {
                        // Left axis: Distance (km) — teal
                        AxisMarks(position: .leading, values: .stride(by: distStep)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                                .foregroundStyle(Color(.systemGray4))
                            AxisValueLabel {
                                if let km = value.as(Double.self) {
                                    Text(km.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(km))" : String(format: "%.1f", km))
                                        .font(.caption2)
                                        .foregroundStyle(.teal)
                                }
                            }
                        }
                        // Right axis: Endurance (m) — purple, fixed 0–3,000m, every 600m
                        if hasEnduranceData {
                            AxisMarks(position: .trailing, values: endurGridChartValues) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                                    .foregroundStyle(.purple.opacity(0.18))
                                AxisValueLabel {
                                    if let chartKm = value.as(Double.self), distYRange > 0 {
                                        let meters = Int(((chartKm - distYMin) / distYRange) * 3000)
                                        Text("\(meters)")
                                            .font(.caption2)
                                            .foregroundStyle(.purple)
                                    }
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.caption2)
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    let plotArea = geo[proxy.plotFrame!]
                                    let relativeX = location.x - plotArea.origin.x
                                    let count = weeklyTotals.count
                                    guard count > 0 else { return }
                                    let segmentWidth = plotArea.width / CGFloat(count)
                                    let tappedIndex = Int(relativeX / segmentWidth)
                                    let clampedIndex = max(0, min(count - 1, tappedIndex))
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedWeekIndex = clampedIndex
                                    }
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
                        }
                    }
                    .frame(height: 140)

                    // Row 1: Distance cards
                    sectionHeader("Distance (km)")
                    HStack(spacing: 8) {
                        metricCard(
                            icon: "figure.pool.swim",
                            value: formatKmNum(selected?.distance ?? 0),
                            title: selected?.isCurrent == true ? "This Week" : (selected?.label ?? "—"),
                            subtitle: selected?.dateRange ?? "",
                            accent: .teal
                        )
                        metricCard(
                            icon: "calendar",
                            value: previous != nil ? formatKmNum(previous!.distance) : "—",
                            title: "Previous",
                            subtitle: previous?.dateRange ?? "",
                            accent: .secondary
                        )
                        if let change = distChange, let pct = distChangePct {
                            metricCard(
                                icon: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                                value: String(format: "%+.1f", change / 1000),
                                title: "Change",
                                subtitle: String(format: "%+.0f%%", pct),
                                accent: change >= 0 ? .green : .red
                            )
                        } else {
                            metricCard(icon: "arrow.left.arrow.right", value: "—", title: "Change", accent: .secondary)
                        }
                    }

                    // Row 2: Endurance cards
                    if hasEnduranceData {
                        sectionHeader("Longest Set (m)")
                        HStack(spacing: 8) {
                            metricCard(
                                icon: "target",
                                value: selected?.longestSet != nil ? "\(Int(selected!.longestSet!))" : "—",
                                title: selected?.isCurrent == true ? "This Week" : (selected?.label ?? "—"),
                                accent: .purple
                            )
                            metricCard(
                                icon: "calendar",
                                value: previous?.longestSet != nil ? "\(Int(previous!.longestSet!))" : "—",
                                title: "Previous",
                                accent: .secondary
                            )
                            if let change = endurChange, let pct = endurChangePct {
                                metricCard(
                                    icon: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                                    value: "\(change >= 0 ? "+" : "")\(Int(change))",
                                    title: "Change",
                                    subtitle: String(format: "%+.0f%%", pct),
                                    accent: change >= 0 ? .green : .red
                                )
                            } else {
                                metricCard(icon: "arrow.left.arrow.right", value: "—", title: "Change", accent: .secondary)
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "applewatch")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Import Apple Watch workouts to track endurance")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedWeekIndex)
        }
    }

    private func metricCard(icon: String, value: String, title: String, subtitle: String = "", accent: Color) -> some View {
        let isHighlighted = accent != .secondary
        return VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(accent)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(isHighlighted ? accent : .primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Format meters as km with unit suffix (e.g. "4.6km", "800m")
    private func formatKm(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        }
        return "\(Int(meters))m"
    }

    /// Format meters as km number only, no unit (e.g. "4.6", "0.8")
    private func formatKmNum(_ meters: Double) -> String {
        return String(format: "%.1f", meters / 1000)
    }

    private func swimHeatColor(_ distanceM: Double) -> Color {
        if distanceM <= 0 {
            return Color(.systemGray4).opacity(0.25)
        } else if distanceM < 1000 {
            return Color.teal.opacity(0.45)
        } else if distanceM < 1500 {
            return Color.blue.opacity(0.65)
        } else {
            return Color.blue
        }
    }

    private struct WeekTotalData {
        let label: String
        let distance: Double
        let longestSet: Double? // best longest single set that week (meters), nil if no detailed data
        let isCurrent: Bool
        let dateRange: String // e.g. "Feb 3–9"
    }

    private func buildWeeklyTotals() -> [WeekTotalData] {
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now

        let monthDayFmt: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f
        }()
        let dayFmt: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "d"
            return f
        }()

        var results: [WeekTotalData] = []
        for weekOffset in -7...0 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart) else { continue }
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let weekEndExclusive = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            let weekSessions = allSessions.filter { $0.date >= weekStart && $0.date < weekEndExclusive }
            let total = weekSessions.reduce(0) { $0 + $1.distance }
            let bestLongestSet = weekSessions.compactMap { $0.longestSingleSet?.distance }.max()
            let isCurrent = weekOffset == 0
            let label = isCurrent ? "Now" : "W\(-weekOffset)"
            let dateRange = "\(monthDayFmt.string(from: weekStart))–\(dayFmt.string(from: weekEnd))"
            results.append(WeekTotalData(label: label, distance: total, longestSet: bestLongestSet, isCurrent: isCurrent, dateRange: dateRange))
        }
        return results
    }

    private struct DailyPoint: Identifiable {
        var id: Int { day }
        let day: Int
        let cumulativeKm: Double
        let bestSetM: Double   // running max of longest set (meters)
        let dayDistanceM: Double // distance swum this specific day (meters)
    }

    private struct MonthTotalData {
        let label: String              // "Jan", "Feb 2025", etc.
        let shortLabel: String         // Always "MMM" format for heat map
        let samePeriodDistance: Double  // Distance for days 1-X (same-period comparison)
        let samePeriodLongestSet: Double? // Best set for days 1-X
        let fullDistance: Double        // Full month total distance
        let fullLongestSet: Double?     // Full month best set
        let isCurrent: Bool
        let dateRange: String          // "Jan 2026"
        let daysInMonth: Int           // Total days in this month
        let daysElapsed: Int           // dayOfMonth for current, daysInMonth for completed
        let color: Color               // Distinct color per month
        let dailyData: [DailyPoint]    // Day-by-day cumulative data
    }

    private static let monthColors: [Color] = [
        Color(red: 0.231, green: 0.510, blue: 0.965), // Jan - Blue
        Color(red: 0.659, green: 0.333, blue: 0.969), // Feb - Purple
        Color(red: 0.063, green: 0.725, blue: 0.506), // Mar - Green
        Color(red: 0.976, green: 0.451, blue: 0.086), // Apr - Orange
        Color(red: 0.984, green: 0.749, blue: 0.141), // May - Yellow
        Color(red: 0.925, green: 0.286, blue: 0.600), // Jun - Pink
        Color(red: 0.024, green: 0.714, blue: 0.831), // Jul - Cyan
        Color(red: 0.937, green: 0.267, blue: 0.267), // Aug - Red
        Color(red: 0.518, green: 0.388, blue: 0.867), // Sep - Indigo
        Color(red: 0.384, green: 0.647, blue: 0.196), // Oct - Lime
        Color(red: 0.827, green: 0.420, blue: 0.125), // Nov - Amber
        Color(red: 0.455, green: 0.565, blue: 0.604), // Dec - Slate
    ]

    private func buildMonthlyTotals() -> [MonthTotalData] {
        let calendar = Calendar.current
        let now = Date.now
        let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let dayOfMonth = calendar.component(.day, from: now)

        let range = MonthlyTimeRange(rawValue: monthlyTimeRange) ?? .thisYear

        // Compute start month based on selected range
        let rangeStart: Date = {
            switch range {
            case .last6Months:
                return calendar.dateInterval(of: .month,
                    for: calendar.date(byAdding: .month, value: -5, to: currentMonthStart) ?? currentMonthStart
                )?.start ?? currentMonthStart
            case .thisYear:
                return calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: 1, day: 1)) ?? currentMonthStart
            case .allTime:
                // Start from first swim or Aug 2025
                let firstSwim = allSessions.first?.date
                let aug2025 = calendar.date(from: DateComponents(year: 2025, month: 8, day: 1)) ?? currentMonthStart
                let earliest = firstSwim != nil ? min(firstSwim!, aug2025) : aug2025
                return calendar.dateInterval(of: .month, for: earliest)?.start ?? aug2025
            }
        }()

        let monthLabelFmt: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM"
            return f
        }()
        let monthYearFmt: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM yyyy"
            return f
        }()

        let lastMonth = currentMonthStart

        var results: [MonthTotalData] = []
        var monthStart = rangeStart
        while monthStart <= lastMonth {
            guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else { break }
            let monthEnd = monthInterval.end
            let totalDays = calendar.dateComponents([.day], from: monthStart, to: monthEnd).day ?? 30

            // Full month data
            let allMonthSessions = allSessions.filter { $0.date >= monthStart && $0.date < monthEnd }
            let fullDist = allMonthSessions.reduce(0) { $0 + $1.distance }
            let fullBestSet = allMonthSessions.compactMap { $0.longestSingleSet?.distance }.max()

            // Same-period data: days 1 through dayOfMonth (clamped to month length)
            let clampedDay = min(dayOfMonth, totalDays)
            let samePeriodEnd = calendar.date(byAdding: .day, value: clampedDay, to: monthStart) ?? monthEnd
            let spSessions = allSessions.filter { $0.date >= monthStart && $0.date < samePeriodEnd }
            let spDist = spSessions.reduce(0) { $0 + $1.distance }
            let spBestSet = spSessions.compactMap { $0.longestSingleSet?.distance }.max()

            let isCurrent = calendar.isDate(monthStart, equalTo: currentMonthStart, toGranularity: .month)
            let spansYears = calendar.component(.year, from: rangeStart) != calendar.component(.year, from: now)
            let label = spansYears ? monthYearFmt.string(from: monthStart) : monthLabelFmt.string(from: monthStart)
            let dateRange = monthYearFmt.string(from: monthStart)
            let elapsed = isCurrent ? dayOfMonth : totalDays

            // Compute daily cumulative data
            var dailyData: [DailyPoint] = []
            var cumDist: Double = 0
            var bestSet: Double = 0
            let lastDay = isCurrent ? dayOfMonth : totalDays
            for d in 1...lastDay {
                guard let dayStart = calendar.date(byAdding: .day, value: d - 1, to: monthStart),
                      let dayEnd = calendar.date(byAdding: .day, value: d, to: monthStart) else { continue }
                let daySessions = allMonthSessions.filter { $0.date >= dayStart && $0.date < dayEnd }
                let dayDist = daySessions.reduce(0) { $0 + $1.distance }
                cumDist += dayDist
                let dayBest = daySessions.compactMap { $0.longestSingleSet?.distance }.max() ?? 0
                bestSet = max(bestSet, dayBest)
                dailyData.append(DailyPoint(day: d, cumulativeKm: cumDist / 1000, bestSetM: bestSet, dayDistanceM: dayDist))
            }

            let monthNum = calendar.component(.month, from: monthStart) // 1-based
            let color = Self.monthColors[(monthNum - 1) % Self.monthColors.count]

            results.append(MonthTotalData(
                label: label,
                shortLabel: monthLabelFmt.string(from: monthStart),
                samePeriodDistance: spDist,
                samePeriodLongestSet: spBestSet,
                fullDistance: fullDist,
                fullLongestSet: fullBestSet,
                isCurrent: isCurrent,
                dateRange: dateRange,
                daysInMonth: totalDays,
                daysElapsed: elapsed,
                color: color,
                dailyData: dailyData
            ))

            guard let next = calendar.date(byAdding: .month, value: 1, to: monthStart) else { break }
            monthStart = next
        }
        return results
    }

    // MARK: - Monthly Progress

    private var monthlyComparisonSection: some View {
        let monthlyTotals = buildMonthlyTotals().reversed() as [MonthTotalData]
        let calendar = Calendar.current
        let dayOfMonth = calendar.component(.day, from: .now)
        // Default to first item (latest month) after reversal
        let safeIndex = min(max(selectedMonthIndex, 0), max(monthlyTotals.count - 1, 0))
        let selected = monthlyTotals.indices.contains(safeIndex) ? monthlyTotals[safeIndex] : nil
        // Previous = chronologically earlier = next index in reversed array
        let previous: MonthTotalData? = safeIndex + 1 < monthlyTotals.count ? monthlyTotals[safeIndex + 1] : nil
        let hasEnduranceData = monthlyTotals.contains { $0.fullLongestSet != nil }
        let daysRemaining = max(0, (selected?.daysInMonth ?? 30) - dayOfMonth)

        // Distance change (same-period vs previous month's same-period)
        let distChange: Double? = {
            guard let sel = selected, let prev = previous, prev.samePeriodDistance > 0 else { return nil }
            return sel.samePeriodDistance - prev.samePeriodDistance
        }()
        let distChangePct: Double? = {
            guard let change = distChange, let prev = previous, prev.samePeriodDistance > 0 else { return nil }
            return change / prev.samePeriodDistance * 100
        }()

        // Endurance change (same-period)
        let endurChange: Double? = {
            guard let sel = selected?.samePeriodLongestSet, let prev = previous?.samePeriodLongestSet, prev > 0 else { return nil }
            return sel - prev
        }()
        let endurChangePct: Double? = {
            guard let change = endurChange, let prev = previous?.samePeriodLongestSet, prev > 0 else { return nil }
            return change / prev * 100
        }()

        // "To beat previous month" targets (previous month's FULL total vs selected same-period)
        let distToBeat: Double? = {
            guard let sel = selected, let prev = previous, prev.fullDistance > 0 else { return nil }
            return prev.fullDistance - sel.samePeriodDistance
        }()
        let endurToBeat: Double? = {
            guard let sel = selected?.samePeriodLongestSet, let prev = previous?.fullLongestSet, prev > 0 else { return nil }
            return prev - sel
        }()

        return SectionCard(title: "Monthly Progress", icon: "calendar.badge.clock") {
            VStack(alignment: .leading, spacing: 16) {
                // Time range filter
                Picker("Range", selection: Binding(
                    get: { MonthlyTimeRange(rawValue: monthlyTimeRange) ?? .thisYear },
                    set: { newValue in
                        monthlyTimeRange = newValue.rawValue
                        // Reset to latest month (index 0 in reversed order)
                        selectedMonthIndex = 0
                    }
                )) {
                    ForEach(MonthlyTimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                if monthlyTotals.filter({ $0.fullDistance > 0 }).count < 2 {
                    Text("Need more months to show trends.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    // Month legend (tappable, scrollable)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(monthlyTotals.indices, id: \.self) { i in
                                let month = monthlyTotals[i]
                                let isSelected = i == safeIndex
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedMonthIndex = i
                                    }
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                } label: {
                                    HStack(spacing: 3) {
                                        Circle().fill(month.color).frame(width: 7, height: 7)
                                        Text(month.label)
                                            .font(.caption2)
                                            .fontWeight(isSelected ? .bold : .regular)
                                            .foregroundStyle(isSelected ? .primary : .secondary)
                                    }
                                    .fixedSize()
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 3)
                                    .background(isSelected ? month.color.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Distance cumulative chart
                    Text("Daily cumulative distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Chart {
                        ForEach(monthlyTotals.indices, id: \.self) { i in
                            let month = monthlyTotals[i]
                            let isSelected = i == safeIndex
                            ForEach(month.dailyData) { point in
                                LineMark(
                                    x: .value("Day", point.day),
                                    y: .value("km", point.cumulativeKm),
                                    series: .value("Month", month.label)
                                )
                                .foregroundStyle(month.color.opacity(isSelected ? 1.0 : 0.3))
                                .lineStyle(StrokeStyle(lineWidth: isSelected ? 3.5 : 2))
                                .interpolationMethod(.catmullRom)
                            }
                        }
                    }
                    .chartXScale(domain: 1...31)
                    .chartYScale(domain: .automatic(includesZero: true))
                    .chartXAxis {
                        AxisMarks(values: [1, 7, 14, 21, 28, 31]) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                                .foregroundStyle(Color(.systemGray4))
                            AxisValueLabel()
                                .font(.caption2)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                                .foregroundStyle(Color(.systemGray4))
                            AxisValueLabel {
                                if let km = value.as(Double.self) {
                                    Text(km.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(km))" : String(format: "%.1f", km))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 160)

                    // Swim frequency heat map
                    Text("Swim Frequency")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        // Day markers
                        HStack(spacing: 0) {
                            Text("")
                                .font(.system(size: 9))
                                .frame(width: 32, alignment: .leading)
                            ForEach(1...31, id: \.self) { day in
                                if [1, 7, 14, 21, 28].contains(day) {
                                    Text("\(day)")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.tertiary)
                                        .fixedSize()
                                        .frame(width: 10, alignment: .center)
                                } else {
                                    Color.clear.frame(width: 10)
                                }
                            }
                        }

                        // Month rows
                        ForEach(monthlyTotals.indices, id: \.self) { i in
                            let month = monthlyTotals[i]
                            let isSelected = i == safeIndex
                            HStack(spacing: 0) {
                                Text(month.shortLabel)
                                    .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                                    .foregroundStyle(isSelected ? .primary : .secondary)
                                    .frame(width: 32, alignment: .leading)
                                ForEach(1...31, id: \.self) { day in
                                    if day <= month.daysElapsed {
                                        let point = month.dailyData.first { $0.day == day }
                                        let dist = point?.dayDistanceM ?? 0
                                        Circle()
                                            .fill(swimHeatColor(dist))
                                            .frame(width: 9, height: 9)
                                            .padding(.horizontal, 0.5)
                                    } else if day <= month.daysInMonth {
                                        Circle()
                                            .strokeBorder(Color(.systemGray4), lineWidth: 0.75)
                                            .frame(width: 9, height: 9)
                                            .padding(.horizontal, 0.5)
                                    } else {
                                        Color.clear.frame(width: 10, height: 9)
                                    }
                                }
                            }
                        }

                        // Legend
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle()
                                    .strokeBorder(Color(.systemGray4), lineWidth: 1)
                                    .frame(width: 9, height: 9)
                                Text("Rest")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color.teal.opacity(0.45)).frame(width: 9, height: 9)
                                Text("<1km")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color.blue.opacity(0.65)).frame(width: 9, height: 9)
                                Text("1–1.5km")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color.blue).frame(width: 9, height: 9)
                                Text(">1.5km")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Row 1: Distance cards
                    sectionHeader("Distance (km)")
                    HStack(spacing: 8) {
                        metricCard(
                            icon: "figure.pool.swim",
                            value: formatKmNum(selected?.samePeriodDistance ?? 0),
                            title: selected?.label ?? "—",
                            subtitle: "1–\(dayOfMonth)d",
                            accent: .teal
                        )
                        metricCard(
                            icon: "calendar",
                            value: previous != nil ? formatKmNum(previous!.samePeriodDistance) : "—",
                            title: previous?.label ?? "Prev",
                            subtitle: "1–\(dayOfMonth)d",
                            accent: .secondary
                        )
                        if let change = distChange, let pct = distChangePct {
                            metricCard(
                                icon: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                                value: String(format: "%+.1f", change / 1000),
                                title: "Change",
                                subtitle: String(format: "%+.0f%%", pct),
                                accent: change >= 0 ? .green : .red
                            )
                        } else {
                            metricCard(icon: "arrow.left.arrow.right", value: "—", title: "Change", accent: .secondary)
                        }
                        if let toBeat = distToBeat, let prev = previous {
                            if toBeat > 0 {
                                metricCard(
                                    icon: "flag.checkered",
                                    value: "+\(formatKmNum(toBeat))",
                                    title: "To Beat",
                                    subtitle: "\(daysRemaining)d left",
                                    accent: .yellow
                                )
                            } else {
                                metricCard(
                                    icon: "checkmark.circle",
                                    value: "+\(formatKmNum(abs(toBeat)))",
                                    title: "Beat \(prev.label)!",
                                    accent: .green
                                )
                            }
                        }
                    }

                    // Row 2: Endurance cards
                    if hasEnduranceData {
                        sectionHeader("Longest Set (m)")
                        HStack(spacing: 8) {
                            metricCard(
                                icon: "target",
                                value: selected?.samePeriodLongestSet != nil ? "\(Int(selected!.samePeriodLongestSet!))" : "—",
                                title: selected?.label ?? "—",
                                subtitle: "1–\(dayOfMonth)d",
                                accent: .purple
                            )
                            metricCard(
                                icon: "calendar",
                                value: previous?.samePeriodLongestSet != nil ? "\(Int(previous!.samePeriodLongestSet!))" : "—",
                                title: previous?.label ?? "Prev",
                                subtitle: "1–\(dayOfMonth)d",
                                accent: .secondary
                            )
                            if let change = endurChange, let pct = endurChangePct {
                                metricCard(
                                    icon: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                                    value: "\(change >= 0 ? "+" : "")\(Int(change))",
                                    title: "Change",
                                    subtitle: String(format: "%+.0f%%", pct),
                                    accent: change >= 0 ? .green : .red
                                )
                            } else {
                                metricCard(icon: "arrow.left.arrow.right", value: "—", title: "Change", accent: .secondary)
                            }
                            if let toBeat = endurToBeat, let prev = previous, prev.fullLongestSet != nil {
                                if toBeat > 0 {
                                    metricCard(
                                        icon: "flag.checkered",
                                        value: "+\(Int(toBeat))",
                                        title: "To Beat",
                                        subtitle: "\(daysRemaining)d left",
                                        accent: .yellow
                                    )
                                } else {
                                    metricCard(
                                        icon: "checkmark.circle",
                                        value: "+\(Int(abs(toBeat)))",
                                        title: "Beat \(prev.label)!",
                                        accent: .green
                                    )
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "applewatch")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Import Apple Watch workouts to track endurance")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedMonthIndex)
        }
    }

    // MARK: - Section 3: Efficiency Metrics (SWOLF)

    private var efficiencyMetricsSection: some View {
        let swolfData = sessionsWithDetailedData.compactMap { session -> (date: Date, swolf: Double)? in
            guard let swolf = session.detailedData?.averageSWOLF else { return nil }
            return (date: session.date, swolf: swolf)
        }.sorted { $0.date < $1.date }

        let bestSwolf = swolfData.map(\.swolf).min()

        return SectionCard(title: "Efficiency (SWOLF)", icon: "gauge.with.dots.needle.33percent") {
            VStack(alignment: .leading, spacing: 12) {
                if swolfData.isEmpty {
                    Text("Import workouts from Apple Watch to see SWOLF trends.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    Chart(swolfData, id: \.date) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("SWOLF", item.swolf)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", item.date),
                            y: .value("SWOLF", item.swolf)
                        )
                        .foregroundStyle(swolfColor(Int(item.swolf)))
                        .symbolSize(30)
                    }
                    .chartYAxisLabel("SWOLF")
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 180)

                    HStack(spacing: 16) {
                        if let best = bestSwolf {
                            VStack(spacing: 4) {
                                Text("Best")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(Int(best))")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(swolfColor(Int(best)))
                                Text(swolfLabel(Int(best)))
                                    .font(.caption2)
                                    .foregroundStyle(swolfColor(Int(best)))
                            }
                        }
                        if swolfData.count >= 2 {
                            let trend = swolfData.last!.swolf - swolfData.first!.swolf
                            VStack(spacing: 4) {
                                Text("Trend")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 2) {
                                    Image(systemName: trend <= 0 ? "arrow.down.right" : "arrow.up.right")
                                    Text(String(format: "%+.0f", trend))
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(trend <= 0 ? .green : .red)
                                Text(trend <= 0 ? "Improving" : "Declining")
                                    .font(.caption2)
                                    .foregroundStyle(trend <= 0 ? .green : .red)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Legend
                    HStack(spacing: 12) {
                        legendDot(color: .blue, label: "<35 Excellent")
                        legendDot(color: .green, label: "35-45 Good")
                        legendDot(color: .orange, label: ">45 Needs Work")
                    }
                    .font(.caption2)
                }
            }
        }
    }

    // MARK: - Section 4: Pace Analysis

    private var paceAnalysisSection: some View {
        let paceData: [(date: Date, pace: Double)] = allSessions.compactMap { session in
            guard session.distance > 0 else { return nil }
            let pace = (session.duration * 60) / (session.distance / 100) / 60 // min per 100m
            return (date: session.date, pace: pace)
        }.sorted { $0.date < $1.date }

        let bestPace = paceData.map(\.pace).min()
        let avgPace = paceData.isEmpty ? nil : paceData.map(\.pace).reduce(0, +) / Double(paceData.count)

        return SectionCard(title: "Pace Analysis", icon: "speedometer") {
            VStack(alignment: .leading, spacing: 12) {
                if paceData.isEmpty {
                    Text("Log more swims to see pace trends.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    Chart(paceData, id: \.date) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Pace", item.pace)
                        )
                        .foregroundStyle(.teal)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", item.date),
                            y: .value("Pace", item.pace)
                        )
                        .foregroundStyle(.teal)
                        .symbolSize(20)
                    }
                    .chartYAxisLabel("min/100m")
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 180)

                    HStack(spacing: 24) {
                        if let best = bestPace {
                            VStack(spacing: 4) {
                                Text("Best Pace")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(formatPace(best)) /100m")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(.green)
                            }
                        }
                        if let avg = avgPace {
                            VStack(spacing: 4) {
                                Text("Avg Pace")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(formatPace(avg)) /100m")
                                    .font(.subheadline.bold().monospacedDigit())
                            }
                        }
                        if paceData.count >= 2 {
                            let trend = paceData.last!.pace - paceData.first!.pace
                            VStack(spacing: 4) {
                                Text("Trend")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 2) {
                                    Image(systemName: trend <= 0 ? "arrow.down.right" : "arrow.up.right")
                                    Text(trend <= 0 ? "Faster" : "Slower")
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(trend <= 0 ? .green : .red)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Section 5: Heart Rate Analysis

    private var heartRateAnalysisSection: some View {
        let hrData = sessionsWithDetailedData.compactMap { session -> (date: Date, avgHR: Int)? in
            guard let hr = session.detailedData?.averageHeartRate else { return nil }
            return (date: session.date, avgHR: hr)
        }.sorted { $0.date < $1.date }

        // Zone distribution across all laps
        let allLaps = sessionsWithDetailedData.flatMap { $0.detailedData?.sets.flatMap(\.laps) ?? [] }
        let lapsWithHR = allLaps.compactMap(\.heartRate)
        let zoneRecovery = lapsWithHR.filter { $0 < 120 }.count
        let zoneAerobic = lapsWithHR.filter { $0 >= 120 && $0 < 150 }.count
        let zoneThreshold = lapsWithHR.filter { $0 >= 150 && $0 < 170 }.count
        let zoneMax = lapsWithHR.filter { $0 >= 170 }.count
        let totalLapsHR = max(lapsWithHR.count, 1)

        let zoneData: [(zone: String, pct: Double, color: Color)] = [
            ("Recovery", Double(zoneRecovery) / Double(totalLapsHR) * 100, .blue),
            ("Aerobic", Double(zoneAerobic) / Double(totalLapsHR) * 100, .green),
            ("Threshold", Double(zoneThreshold) / Double(totalLapsHR) * 100, .orange),
            ("Max Effort", Double(zoneMax) / Double(totalLapsHR) * 100, .red)
        ]

        return SectionCard(title: "Heart Rate Analysis", icon: "heart.fill") {
            VStack(alignment: .leading, spacing: 12) {
                if hrData.isEmpty {
                    Text("Import workouts from Apple Watch to see heart rate trends.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    // Avg HR over time
                    Text("Average HR Per Swim")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Chart(hrData, id: \.date) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("HR", item.avgHR)
                        )
                        .foregroundStyle(.red)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", item.date),
                            y: .value("HR", item.avgHR)
                        )
                        .foregroundStyle(hrZoneColor(item.avgHR))
                        .symbolSize(30)
                    }
                    .chartYAxisLabel("bpm")
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 150)

                    Divider()

                    // Zone distribution
                    if !lapsWithHR.isEmpty {
                        Text("HR Zone Distribution")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        // Stacked bar
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                ForEach(zoneData, id: \.zone) { zone in
                                    if zone.pct > 0 {
                                        Rectangle()
                                            .fill(zone.color.gradient)
                                            .frame(width: geo.size.width * zone.pct / 100)
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .frame(height: 24)

                        // Zone legend
                        HStack(spacing: 12) {
                            ForEach(zoneData, id: \.zone) { zone in
                                if zone.pct > 0 {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(zone.color)
                                            .frame(width: 8, height: 8)
                                        Text("\(zone.zone) \(Int(zone.pct))%")
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section 6: Training Volume

    private var trainingVolumeSection: some View {
        let monthlyData = monthlyDistances()
        let weeklyFrequency = weeklySwimFrequency()
        let streak = consistencyStreak()

        return SectionCard(title: "Training Volume", icon: "flame.fill") {
            VStack(alignment: .leading, spacing: 16) {
                // Monthly distance bar chart
                if !monthlyData.isEmpty {
                    Text("Monthly Distance")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Chart(monthlyData, id: \.monthStart) { item in
                        BarMark(
                            x: .value("Month", item.monthStart, unit: .month),
                            y: .value("Distance", item.distance)
                        )
                        .foregroundStyle(.blue.gradient)
                        .cornerRadius(4)
                    }
                    .chartYAxisLabel("meters")
                    .frame(height: 150)
                }

                Divider()

                // Weekly frequency
                if !weeklyFrequency.isEmpty {
                    Text("Weekly Swim Frequency")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Chart(weeklyFrequency, id: \.weekStart) { item in
                        BarMark(
                            x: .value("Week", item.weekStart, unit: .weekOfYear),
                            y: .value("Swims", item.count)
                        )
                        .foregroundStyle(.teal.gradient)
                        .cornerRadius(4)
                    }
                    .chartYAxisLabel("swims")
                    .chartYScale(domain: .automatic(includesZero: true))
                    .frame(height: 120)
                }

                Divider()

                // Stats row
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("Consistency")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(streak) days")
                                .font(.subheadline.bold())
                        }
                    }
                    if let longest = allSessions.map(\.longestContinuousDistance).max() {
                        VStack(spacing: 4) {
                            Text("Longest Continuous")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(longest))m")
                                .font(.subheadline.bold())
                        }
                    }
                    VStack(spacing: 4) {
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(allSessions.count) swims")
                            .font(.subheadline.bold())
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Section 7: Quick Stats Cards

    private var quickStatsSection: some View {
        let totalSwims = allSessions.count
        let totalDistance = allSessions.reduce(0.0) { $0 + $1.distance }
        let totalTime = allSessions.reduce(0.0) { $0 + $1.duration }
        let avgDistance = totalSwims > 0 ? totalDistance / Double(totalSwims) : 0

        let bestPace: Double? = {
            let paces = allSessions.compactMap { s -> Double? in
                guard s.distance > 0 else { return nil }
                return (s.duration * 60) / (s.distance / 100) / 60
            }
            return paces.min()
        }()

        let bestSwolf: Double? = allSessions.compactMap { $0.detailedData?.averageSWOLF }.min()
        let bestDistance = allSessions.map(\.distance).max() ?? 0

        return SectionCard(title: "All-Time Stats", icon: "trophy.fill") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                QuickStat(title: "Total Swims", value: "\(totalSwims)", icon: "figure.pool.swim", color: .blue)
                QuickStat(title: "Total Distance", value: totalDistance >= 1000 ? String(format: "%.1fkm", totalDistance / 1000) : "\(Int(totalDistance))m", icon: "ruler", color: .teal)
                QuickStat(title: "Total Time", value: totalTime >= 60 ? String(format: "%.0fh", totalTime / 60) : "\(Int(totalTime))m", icon: "clock", color: .purple)
                QuickStat(title: "Avg Distance", value: "\(Int(avgDistance))m", icon: "chart.bar", color: .blue)
                QuickStat(title: "Best Pace", value: bestPace != nil ? "\(formatPace(bestPace!))" : "N/A", icon: "speedometer", color: .green)
                QuickStat(title: "Best Distance", value: "\(Int(bestDistance))m", icon: "arrow.up", color: .teal)
                if let swolf = bestSwolf {
                    QuickStat(title: "Best SWOLF", value: "\(Int(swolf))", icon: "gauge.with.dots.needle.33percent", color: swolfColor(Int(swolf)))
                }
            }
        }
    }

    // MARK: - Data Helpers

    private func monthlyDistances() -> [(monthStart: Date, distance: Double)] {
        let calendar = Calendar.current
        var monthly: [Date: Double] = [:]
        for session in allSessions {
            let monthStart = calendar.dateInterval(of: .month, for: session.date)?.start ?? session.date
            monthly[monthStart, default: 0] += session.distance
        }
        return monthly.map { (monthStart: $0.key, distance: $0.value) }.sorted { $0.monthStart < $1.monthStart }
    }

    private func weeklySwimFrequency() -> [(weekStart: Date, count: Int)] {
        let calendar = Calendar.current
        var weekly: [Date: Int] = [:]
        for session in allSessions {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.date)?.start ?? session.date
            weekly[weekStart, default: 0] += 1
        }
        return weekly.map { (weekStart: $0.key, count: $0.value) }.sorted { $0.weekStart < $1.weekStart }
    }

    private func consistencyStreak() -> Int {
        guard !allSessions.isEmpty else { return 0 }
        let calendar = Calendar.current
        let swimDays = Set(allSessions.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        guard let mostRecent = swimDays.first else { return 0 }

        // Only count streak if most recent swim was today or yesterday
        let daysSinceLast = calendar.dateComponents([.day], from: mostRecent, to: calendar.startOfDay(for: .now)).day ?? 0
        guard daysSinceLast <= 1 else { return 0 }

        var streak = 1
        for i in 1..<swimDays.count {
            let gap = calendar.dateComponents([.day], from: swimDays[i], to: swimDays[i - 1]).day ?? 0
            if gap <= 1 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - View Helpers

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Section Card

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.headline)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Quick Stat

struct QuickStat: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    StatisticsView(isDarkMode: .constant(false))
        .modelContainer(for: SwimSession.self, inMemory: true)
}
