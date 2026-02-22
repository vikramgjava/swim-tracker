import SwiftUI
import SwiftData

struct InsightsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SwimSession.date, order: .reverse) private var sessions: [SwimSession]

    var onAction: (String) -> Void

    @State private var insightsService = CoachInsightsService()
    @State private var insights: [CoachInsight] = []

    var body: some View {
        NavigationStack {
            Group {
                if insights.isEmpty {
                    emptyState
                } else {
                    insightsList
                }
            }
            .navigationTitle("Coach Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadInsights()
            }
        }
    }

    // MARK: - Insights List

    private var insightsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Summary header
                HStack {
                    let warnings = insights.filter { $0.type == .warning }.count
                    let celebrations = insights.filter { $0.type == .celebration }.count

                    if warnings > 0 {
                        summaryBadge(
                            count: warnings,
                            label: warnings == 1 ? "Alert" : "Alerts",
                            color: .red
                        )
                    }
                    if celebrations > 0 {
                        summaryBadge(
                            count: celebrations,
                            label: celebrations == 1 ? "Win" : "Wins",
                            color: .orange
                        )
                    }

                    Spacer()

                    Text("\(insights.count) insights")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 4)

                // Insight cards
                ForEach(insights) { insight in
                    InsightsSheetCard(insight: insight) {
                        guard let action = insight.action else { return }
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onAction(action.label)
                        }
                    }
                }
                .padding(.horizontal)

                // Refresh note
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                    Text("Insights refresh each time you open this sheet")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.purple.opacity(0.5))
            Text("Keep Training!")
                .font(.title3.bold())
            Text("I'll notice patterns and share coaching insights here as you log more swims.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func summaryBadge(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.caption.bold())
            Text(label)
                .font(.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: Capsule())
    }

    private func loadInsights() {
        insightsService.generateInsights(sessions: Array(sessions)) { actionMessage in
            onAction(actionMessage)
        }
        insights = insightsService.insights
    }
}

// MARK: - Sheet-specific Insight Card

struct InsightsSheetCard: View {
    let insight: CoachInsight
    var onActionTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Icon + Title row
            HStack(spacing: 10) {
                Image(systemName: insight.icon)
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .frame(width: 36, height: 36)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(typeLabel)
                        .font(.caption2.bold())
                        .foregroundStyle(accentColor)
                        .textCase(.uppercase)
                    Text(insight.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }

                Spacer()
            }

            // Description
            Text(insight.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Action button
            if let action = insight.action {
                Button {
                    onActionTap()
                } label: {
                    HStack(spacing: 6) {
                        Text(action.label)
                            .font(.subheadline.bold())
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private var typeLabel: String {
        switch insight.type {
        case .celebration: return "Achievement"
        case .warning: return "Heads Up"
        case .suggestion: return "Suggestion"
        case .milestone: return "Milestone"
        }
    }

    private var accentColor: Color {
        switch insight.type {
        case .celebration: return .orange
        case .warning: return .red
        case .suggestion: return .blue
        case .milestone: return .purple
        }
    }
}
