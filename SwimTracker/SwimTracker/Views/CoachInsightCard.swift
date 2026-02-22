import SwiftUI

struct CoachInsightCard: View {
    let insight: CoachInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: insight.icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)

                Text(insight.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }

            Text(insight.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if let action = insight.action {
                Button {
                    action.action()
                } label: {
                    HStack(spacing: 4) {
                        Text(action.label)
                            .font(.caption.bold())
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(actionColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var iconColor: Color {
        switch insight.type {
        case .celebration: return .orange
        case .warning: return .red
        case .suggestion: return .blue
        case .milestone: return .purple
        }
    }

    private var actionColor: Color {
        switch insight.type {
        case .celebration: return .orange
        case .warning: return .red
        case .suggestion: return .blue
        case .milestone: return .purple
        }
    }

    private var backgroundColor: Color {
        switch insight.type {
        case .celebration: return .orange.opacity(0.08)
        case .warning: return .red.opacity(0.08)
        case .suggestion: return .blue.opacity(0.08)
        case .milestone: return .purple.opacity(0.08)
        }
    }

    private var borderColor: Color {
        switch insight.type {
        case .celebration: return .orange.opacity(0.2)
        case .warning: return .red.opacity(0.2)
        case .suggestion: return .blue.opacity(0.2)
        case .milestone: return .purple.opacity(0.2)
        }
    }
}

// MARK: - Insights Section

struct CoachInsightsSection: View {
    let insights: [CoachInsight]

    var body: some View {
        if !insights.isEmpty {
            VStack(spacing: 8) {
                ForEach(insights.prefix(3)) { insight in
                    CoachInsightCard(insight: insight)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
    }
}
