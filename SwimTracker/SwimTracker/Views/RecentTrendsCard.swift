import SwiftUI

struct RecentTrendsCard: View {
    let sessions: [SwimSession]

    private var analyzedSessions: [SwimSession] {
        sessions
            .filter { $0.analysis != nil }
            .prefix(3)
            .map { $0 }
    }

    private var analyses: [WorkoutAnalysis] {
        analyzedSessions.compactMap(\.analysis)
    }

    var body: some View {
        if analyzedSessions.isEmpty {
            emptyState
        } else {
            trendsContent
        }
    }

    // MARK: - Trends Content

    private var trendsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent Performance Trends")
                        .font(.headline)
                    Text("Last \(analyzedSessions.count) workout\(analyzedSessions.count == 1 ? "" : "s") analyzed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Performance Score Trend
            if analyses.count > 1 {
                performanceScoreTrend
            } else if let score = analyses.first?.performanceScore {
                HStack(spacing: 8) {
                    Text("Performance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(score)/10")
                        .font(.subheadline.bold())
                        .foregroundStyle(scoreColor(score))
                }
            }

            Divider()

            // Quick Metrics from most recent analysis
            if let latest = analyses.first {
                quickMetrics(for: latest)
            }

            Divider()

            // Coach Recommendation
            if let recommendation = analyses.first?.recommendation, !recommendation.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coach Says:")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Text(recommendation)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            // View All
            NavigationLink {
                AnalysesHistoryView()
            } label: {
                HStack {
                    Text("View All Analyses")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundStyle(.purple)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Performance Score Trend

    private var performanceScoreTrend: some View {
        let scores = analyses.reversed().map(\.performanceScore)
        let trend: String = {
            guard let first = scores.first, let last = scores.last else { return "stable" }
            if last > first { return "improving" }
            if last < first { return "declining" }
            return "stable"
        }()

        return HStack(spacing: 8) {
            Text("Performance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 4) {
                ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                    Text("\(score)")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(scoreColor(score))
                    if index < scores.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Image(systemName: trendIcon(trend))
                .font(.caption)
                .foregroundStyle(trendColor(trend))
        }
    }

    // MARK: - Quick Metrics

    private func quickMetrics(for analysis: WorkoutAnalysis) -> some View {
        VStack(spacing: 10) {
            metricRow(
                icon: "figure.pool.swim",
                label: "SWOLF Trend",
                value: trendDisplayLabel(analysis.swolfTrend, labels: ("Improving", "Declining", "Stable")),
                color: trendColor(analysis.swolfTrend == "improving" ? "improving" : analysis.swolfTrend == "declining" ? "declining" : "stable")
            )
            metricRow(
                icon: "speedometer",
                label: "Pace Trend",
                value: trendDisplayLabel(analysis.paceTrend, labels: ("Faster", "Slower", "Consistent")),
                color: trendColor(analysis.paceTrend == "faster" ? "improving" : analysis.paceTrend == "slower" ? "declining" : "stable")
            )
            metricRow(
                icon: "bolt.heart.fill",
                label: "Effort Efficiency",
                value: effortDisplayLabel(analysis.effortVsPerformance),
                color: effortDisplayColor(analysis.effortVsPerformance)
            )
        }
    }

    private func metricRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal.fill")
                .font(.title2)
                .foregroundStyle(.secondary.opacity(0.5))
            Text("No analyzed workouts yet")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Text("Import workouts from Apple Health to get AI insights")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 1...4: return .red
        case 5...7: return .orange
        default: return .green
        }
    }

    private func trendIcon(_ trend: String) -> String {
        switch trend {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "improving": return .green
        case "declining": return .red
        default: return .blue
        }
    }

    private func trendDisplayLabel(_ value: String, labels: (String, String, String)) -> String {
        switch value {
        case "improving", "faster": return labels.0
        case "declining", "slower": return labels.1
        default: return labels.2
        }
    }

    private func effortDisplayLabel(_ value: String) -> String {
        switch value {
        case "efficient": return "Efficient"
        case "hard_but_slow": return "Working Hard"
        default: return "Easy Cruise"
        }
    }

    private func effortDisplayColor(_ value: String) -> Color {
        switch value {
        case "efficient": return .green
        case "hard_but_slow": return .orange
        default: return .blue
        }
    }
}
