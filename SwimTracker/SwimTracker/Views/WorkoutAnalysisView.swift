import SwiftUI

struct WorkoutAnalysisView: View {
    let analysis: WorkoutAnalysis
    let session: SwimSession
    @Environment(\.dismiss) private var dismiss

    private var scoreColor: Color {
        switch analysis.performanceScore {
        case 1...4: return .red
        case 5...7: return .orange
        default: return .green
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 4) {
                        Text(session.date.formatted(date: .long, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(Int(session.distance))m in \(Int(session.duration)) min")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Performance Score Gauge
                    performanceScoreSection

                    // Quick Trends
                    trendsSection

                    // Key Insights
                    insightsSection

                    // Coach Recommendation
                    recommendationSection
                }
                .padding()
            }
            .navigationTitle("Workout Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Performance Score

    private var performanceScoreSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(analysis.performanceScore) / 10.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                Text("\(analysis.performanceScore)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
            }

            Text("Performance Score")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    // MARK: - Trends

    private var trendsSection: some View {
        HStack(spacing: 12) {
            trendCard(
                title: "SWOLF",
                value: swolfTrendLabel,
                icon: swolfTrendIcon,
                color: swolfTrendColor
            )
            trendCard(
                title: "Pace",
                value: paceTrendLabel,
                icon: paceTrendIcon,
                color: paceTrendColor
            )
            trendCard(
                title: "Effort",
                value: effortLabel,
                icon: effortIcon,
                color: effortColor
            )
        }
    }

    private func trendCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.caption.bold())
                .multilineTextAlignment(.center)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Insights")
                .font(.headline)

            ForEach(Array(analysis.insights.enumerated()), id: \.offset) { _, insight in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: insightIcon(for: insight))
                        .foregroundStyle(insightColor(for: insight))
                        .font(.subheadline)
                        .frame(width: 20)

                    Text(insight)
                        .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    // MARK: - Recommendation

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Coach Recommendation", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(analysis.recommendation)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    // MARK: - Trend Helpers

    private var swolfTrendLabel: String {
        switch analysis.swolfTrend {
        case "improving": "Improving"
        case "declining": "Declining"
        default: "Stable"
        }
    }

    private var swolfTrendIcon: String {
        switch analysis.swolfTrend {
        case "improving": "arrow.down.right"
        case "declining": "arrow.up.right"
        default: "arrow.right"
        }
    }

    private var swolfTrendColor: Color {
        switch analysis.swolfTrend {
        case "improving": .green
        case "declining": .red
        default: .blue
        }
    }

    private var paceTrendLabel: String {
        switch analysis.paceTrend {
        case "faster": "Faster"
        case "slower": "Slower"
        default: "Consistent"
        }
    }

    private var paceTrendIcon: String {
        switch analysis.paceTrend {
        case "faster": "hare.fill"
        case "slower": "tortoise.fill"
        default: "equal.circle.fill"
        }
    }

    private var paceTrendColor: Color {
        switch analysis.paceTrend {
        case "faster": .green
        case "slower": .red
        default: .blue
        }
    }

    private var effortLabel: String {
        switch analysis.effortVsPerformance {
        case "efficient": "Efficient"
        case "hard_but_slow": "Working Hard"
        default: "Easy Cruise"
        }
    }

    private var effortIcon: String {
        switch analysis.effortVsPerformance {
        case "efficient": "bolt.fill"
        case "hard_but_slow": "flame.fill"
        default: "wind"
        }
    }

    private var effortColor: Color {
        switch analysis.effortVsPerformance {
        case "efficient": .green
        case "hard_but_slow": .orange
        default: .blue
        }
    }

    // MARK: - Insight Helpers

    private func insightIcon(for insight: String) -> String {
        let lowered = insight.lowercased()
        if lowered.contains("great") || lowered.contains("strong") || lowered.contains("improv") || lowered.contains("excellent") || lowered.contains("good") {
            return "checkmark.circle.fill"
        }
        return "info.circle.fill"
    }

    private func insightColor(for insight: String) -> Color {
        let lowered = insight.lowercased()
        if lowered.contains("great") || lowered.contains("strong") || lowered.contains("improv") || lowered.contains("excellent") || lowered.contains("good") {
            return .green
        }
        return .blue
    }
}
