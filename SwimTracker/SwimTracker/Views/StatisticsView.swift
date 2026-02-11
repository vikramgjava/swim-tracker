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

                            if sessions.isEmpty {
                                Text("No swims in this time period.")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 40)
                            } else {
                                goalProgressSection
                                distanceTrendsSection
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

    // MARK: - Section 1: Goal Progress

    private var goalProgressSection: some View {
        let goalDistance = 3000.0
        let longestContinuousSwim = sessions.map(\.longestContinuousDistance).max() ?? 0
        let progress = min(longestContinuousSwim / goalDistance, 1.0)

        // Estimate completion: linear extrapolation from progression of longest continuous swims
        let sortedByDate = sessions.sorted { $0.date < $1.date }
        // Build running max of longest continuous distance over time
        let progressionPoints: [(date: Date, best: Double)] = {
            var runningMax = 0.0
            return sortedByDate.compactMap { session in
                let continuous = session.longestContinuousDistance
                if continuous > runningMax {
                    runningMax = continuous
                    return (date: session.date, best: runningMax)
                }
                return nil
            }
        }()

        let estimatedCompletion: String = {
            guard progressionPoints.count >= 2 else { return "Need more data" }
            let first = progressionPoints.first!
            let last = progressionPoints.last!
            let daysBetween = max(last.date.timeIntervalSince(first.date) / 86400, 1)
            let distanceGain = last.best - first.best
            guard distanceGain > 0 else { return "Need more data" }
            let remaining = goalDistance - longestContinuousSwim
            let daysNeeded = remaining / (distanceGain / daysBetween)
            let estimatedDate = Calendar.current.date(byAdding: .day, value: Int(daysNeeded), to: .now)
            return estimatedDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A"
        }()

        let isOnTrack: Bool = {
            let deadline = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 30)) ?? .now
            guard progressionPoints.count >= 2 else { return false }
            let first = progressionPoints.first!
            let last = progressionPoints.last!
            let daysBetween = max(last.date.timeIntervalSince(first.date) / 86400, 1)
            let distanceGain = last.best - first.best
            guard distanceGain > 0 else { return false }
            let remaining = goalDistance - longestContinuousSwim
            let daysNeeded = remaining / (distanceGain / daysBetween)
            let estimatedDate = Calendar.current.date(byAdding: .day, value: Int(daysNeeded), to: .now) ?? .distantFuture
            return estimatedDate <= deadline
        }()

        return SectionCard(title: "Goal Progress", icon: "target") {
            VStack(spacing: 16) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(progress >= 1.0 ? Color.green : Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progress)
                    VStack(spacing: 4) {
                        Text("\(Int(progress * 100))%")
                            .font(.title.bold())
                        Text("\(Int(longestContinuousSwim))m / \(Int(goalDistance))m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 140, height: 140)

                Divider()

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("Longest Continuous")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(longestContinuousSwim))m")
                            .font(.subheadline.bold())
                    }
                    VStack(spacing: 4) {
                        Text("Target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(goalDistance))m")
                            .font(.subheadline.bold())
                    }
                    VStack(spacing: 4) {
                        Text("Est. Completion")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(estimatedCompletion)
                            .font(.subheadline.bold())
                    }
                }

                // On track indicator
                HStack(spacing: 6) {
                    Image(systemName: isOnTrack ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(isOnTrack ? .green : .orange)
                    Text(isOnTrack ? "On track for Aug 30, 2026" : "Need to accelerate training")
                        .font(.caption.bold())
                        .foregroundStyle(isOnTrack ? .green : .orange)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background((isOnTrack ? Color.green : Color.orange).opacity(0.1), in: Capsule())
            }
        }
    }

    // MARK: - Section 2: Distance Trends

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
