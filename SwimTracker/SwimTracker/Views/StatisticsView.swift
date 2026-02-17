import SwiftUI
import SwiftData
import Charts

// MARK: - Time Range Filter

enum TimeRange: String, CaseIterable {
    case last30 = "Last 30 Days"
    case last60 = "Last 60 Days"
    case last90 = "Last 90 Days"
    case allTime = "All Time"

    var startDate: Date? {
        switch self {
        case .last30: return Calendar.current.date(byAdding: .day, value: -30, to: .now)
        case .last60: return Calendar.current.date(byAdding: .day, value: -60, to: .now)
        case .last90: return Calendar.current.date(byAdding: .day, value: -90, to: .now)
        case .allTime: return nil
        }
    }
}

// MARK: - StatisticsView

struct StatisticsView: View {
    @Binding var isDarkMode: Bool
    @Query(sort: \SwimSession.date) private var allSessions: [SwimSession]
    @State private var timeRange: TimeRange = .last60
    @State private var selectedWeekIndex: Int = 4 // 0-4, default to current week (index 4)

    private var sessions: [SwimSession] {
        guard let start = timeRange.startDate else { return allSessions }
        return allSessions.filter { $0.date >= start }
    }

    private var sessionsWithDetailedData: [SwimSession] {
        sessions.filter { $0.detailedData != nil }
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
                            // Time range picker
                            Picker("Time Range", selection: $timeRange) {
                                ForEach(TimeRange.allCases, id: \.self) { range in
                                    Text(range.rawValue).tag(range)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)

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

                            if sessions.isEmpty {
                                Text("No swims in this time period.")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 40)
                            } else {
                                distanceTrendsSection
                                weeklyComparisonSection
                                if hasDetailedData { enduranceProgressionSection }
                                if hasDetailedData { efficiencyMetricsSection }
                                paceAnalysisSection
                                if hasDetailedData { heartRateAnalysisSection }
                                trainingVolumeSection
                                quickStatsSection
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

    // MARK: - Distance Trends

    private var distanceTrendsSection: some View {
        let weeklyData = weeklyDistances()

        return SectionCard(title: "Distance Trends", icon: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: 12) {
                if weeklyData.isEmpty {
                    Text("Not enough data for trends.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    // Weekly distance bar chart
                    Chart(weeklyData, id: \.weekStart) { item in
                        BarMark(
                            x: .value("Week", item.weekStart, unit: .weekOfYear),
                            y: .value("Distance", item.distance)
                        )
                        .foregroundStyle(.blue.gradient)
                        .cornerRadius(4)
                    }
                    .chartYAxisLabel("meters")
                    .frame(height: 180)

                    // Trend summary
                    if weeklyData.count >= 2 {
                        let firstWeek = weeklyData.first!.distance
                        let lastWeek = weeklyData.last!.distance
                        let trend = lastWeek - firstWeek
                        HStack(spacing: 6) {
                            Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(trend >= 0 ? .green : .orange)
                            Text(trend >= 0 ? "+\(Int(trend))m weekly trend" : "\(Int(trend))m weekly trend")
                                .font(.caption.bold())
                                .foregroundStyle(trend >= 0 ? .green : .orange)
                        }
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
                                    Circle().fill(.orange).frame(width: 8, height: 8)
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
                                .foregroundStyle(.orange)
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

                    // Compute endurance axis range (meters)
                    let enduranceValues = weeklyTotals.compactMap { $0.longestSet }
                    let endurMax = enduranceValues.max() ?? 1000
                    // Round up to a clean ceiling for the right axis
                    let endurCeil: Double = {
                        if endurMax <= 500 { return ceil(endurMax / 100) * 100 }
                        if endurMax <= 2000 { return ceil(endurMax / 500) * 500 }
                        return ceil(endurMax / 1000) * 1000
                    }()
                    let endurStep: Double = {
                        if endurCeil <= 500 { return 100 }
                        if endurCeil <= 2000 { return 500 }
                        return 1000
                    }()

                    // Map endurance (meters) → chart Y (km scale)
                    // endurCeil meters maps to distYMax km
                    let endurToChart: (Double) -> Double = { meters in
                        guard endurCeil > 0, distYMax > 0 else { return 0 }
                        return (meters / endurCeil) * distYMax
                    }

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
                                .foregroundStyle(.orange.opacity(0.4))
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
                                .foregroundStyle(.orange)
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 3, dash: [6, 3]))

                                PointMark(
                                    x: .value("Week", week.label),
                                    y: .value("Value", chartY)
                                )
                                .foregroundStyle(endurValue > 0 ? (isSelected ? .orange : .orange.opacity(0.5)) : .clear)
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
                        // Right axis: Endurance (m) — orange
                        if hasEnduranceData {
                            AxisMarks(position: .trailing, values: .stride(by: distStep)) { value in
                                AxisValueLabel {
                                    if let chartKm = value.as(Double.self), distYMax > 0 {
                                        let meters = (chartKm / distYMax) * endurCeil
                                        Text("\(Int(meters))")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
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
                    HStack(spacing: 10) {
                        weekMetricCard(
                            icon: "figure.pool.swim",
                            label: selected?.isCurrent == true ? "This Week" : (selected?.dateRange ?? selected?.label ?? "—"),
                            value: formatKm(selected?.distance ?? 0),
                            accent: .teal
                        )
                        weekMetricCard(
                            icon: "calendar",
                            label: "Previous",
                            value: previous != nil ? formatKm(previous!.distance) : "N/A",
                            accent: .secondary
                        )
                        if let change = distChange, let pct = distChangePct {
                            weekMetricCard(
                                icon: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                                label: "Change",
                                value: "\(formatKm(abs(change))) (\(String(format: "%+.0f%%", pct)))",
                                accent: change >= 0 ? .green : .orange
                            )
                        } else {
                            weekMetricCard(
                                icon: "arrow.left.arrow.right",
                                label: "Change",
                                value: "N/A",
                                accent: .secondary
                            )
                        }
                    }

                    // Row 2: Endurance cards
                    if hasEnduranceData {
                        HStack(spacing: 10) {
                            weekMetricCard(
                                icon: "target",
                                label: "Longest Set",
                                value: selected?.longestSet != nil ? "\(Int(selected!.longestSet!))m" : "N/A",
                                accent: .orange
                            )
                            weekMetricCard(
                                icon: "calendar",
                                label: "Prev Set",
                                value: previous?.longestSet != nil ? "\(Int(previous!.longestSet!))m" : "N/A",
                                accent: .secondary
                            )
                            if let change = endurChange, let pct = endurChangePct {
                                weekMetricCard(
                                    icon: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                                    label: "Change",
                                    value: "\(change >= 0 ? "+" : "")\(Int(change))m (\(String(format: "%+.0f%%", pct)))",
                                    accent: change >= 0 ? .green : .orange
                                )
                            } else {
                                weekMetricCard(
                                    icon: "arrow.left.arrow.right",
                                    label: "Change",
                                    value: "N/A",
                                    accent: .secondary
                                )
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

    private func weekMetricCard(icon: String, label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(accent)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(accent == .teal || accent == .orange ? accent : .primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
    }

    private func formatKm(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        }
        return "\(Int(meters))m"
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
        for weekOffset in -4...0 {
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

    // MARK: - Endurance Progression

    private var enduranceProgressionSection: some View {
        let enduranceGoal = 3000.0
        let enduranceData = sessionsWithDetailedData.compactMap { session -> (date: Date, distance: Double)? in
            guard let set = session.longestSingleSet else { return nil }
            return (date: session.date, distance: set.distance)
        }.sorted { $0.date < $1.date }

        // Calculate PRs (running max)
        let prDates: Set<Date> = {
            var maxSoFar = 0.0
            var dates = Set<Date>()
            for item in enduranceData {
                if item.distance > maxSoFar {
                    maxSoFar = item.distance
                    dates.insert(item.date)
                }
            }
            return dates
        }()

        let currentPR = enduranceData.map(\.distance).max() ?? 0

        return SectionCard(title: "Endurance Progression", icon: "figure.pool.swim") {
            VStack(alignment: .leading, spacing: 12) {
                if enduranceData.isEmpty {
                    Text("Import Apple Watch workouts to track endurance.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    Chart {
                        // Goal line at 3,000m
                        RuleMark(y: .value("Goal", enduranceGoal))
                            .foregroundStyle(.green.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("3,000m goal")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }

                        // Line chart
                        ForEach(enduranceData, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("Distance", item.distance)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)

                            // PR points highlighted
                            if prDates.contains(item.date) {
                                PointMark(
                                    x: .value("Date", item.date),
                                    y: .value("Distance", item.distance)
                                )
                                .foregroundStyle(.orange)
                                .symbolSize(50)
                            } else {
                                PointMark(
                                    x: .value("Date", item.date),
                                    y: .value("Distance", item.distance)
                                )
                                .foregroundStyle(.blue)
                                .symbolSize(20)
                            }
                        }
                    }
                    .chartYAxisLabel("meters")
                    .chartYScale(domain: 0...(max(enduranceGoal, currentPR) * 1.1))
                    .frame(height: 200)

                    // Stats row
                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("PR Set")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(currentPR))m")
                                .font(.subheadline.bold())
                                .foregroundStyle(currentPR > 1600 ? .green : currentPR >= 800 ? .blue : .orange)
                        }
                        VStack(spacing: 4) {
                            Text("Goal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(enduranceGoal))m")
                                .font(.subheadline.bold())
                        }
                        if enduranceData.count >= 2 {
                            let trend = enduranceData.last!.distance - enduranceData.first!.distance
                            VStack(spacing: 4) {
                                Text("Trend")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 2) {
                                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    Text(trend >= 0 ? "+\(Int(trend))m" : "\(Int(trend))m")
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(trend >= 0 ? .green : .orange)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Legend
                    HStack(spacing: 12) {
                        legendDot(color: .orange, label: "PR")
                        legendDot(color: .blue, label: "Session")
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(.green.opacity(0.5))
                                .frame(width: 16, height: 2)
                            Text("Goal")
                        }
                    }
                    .font(.caption2)
                }
            }
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
                                .foregroundStyle(trend <= 0 ? .green : .orange)
                                Text(trend <= 0 ? "Improving" : "Declining")
                                    .font(.caption2)
                                    .foregroundStyle(trend <= 0 ? .green : .orange)
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
        let paceData: [(date: Date, pace: Double)] = sessions.compactMap { session in
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
                                .foregroundStyle(trend <= 0 ? .green : .orange)
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
                    if let longest = sessions.map(\.longestContinuousDistance).max() {
                        VStack(spacing: 4) {
                            Text("Longest Continuous")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(longest))m")
                                .font(.subheadline.bold())
                        }
                    }
                    VStack(spacing: 4) {
                        Text("This Period")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(sessions.count) swims")
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

    private func weeklyDistances() -> [(weekStart: Date, distance: Double)] {
        let calendar = Calendar.current
        var weekly: [Date: Double] = [:]
        for session in sessions {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.date)?.start ?? session.date
            weekly[weekStart, default: 0] += session.distance
        }
        return weekly.map { (weekStart: $0.key, distance: $0.value) }.sorted { $0.weekStart < $1.weekStart }
    }

    private func monthlyDistances() -> [(monthStart: Date, distance: Double)] {
        let calendar = Calendar.current
        var monthly: [Date: Double] = [:]
        for session in sessions {
            let monthStart = calendar.dateInterval(of: .month, for: session.date)?.start ?? session.date
            monthly[monthStart, default: 0] += session.distance
        }
        return monthly.map { (monthStart: $0.key, distance: $0.value) }.sorted { $0.monthStart < $1.monthStart }
    }

    private func weeklySwimFrequency() -> [(weekStart: Date, count: Int)] {
        let calendar = Calendar.current
        var weekly: [Date: Int] = [:]
        for session in sessions {
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
