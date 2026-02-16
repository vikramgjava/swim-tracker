import SwiftUI
import SwiftData

struct AnalysesHistoryView: View {
    @Query(sort: \SwimSession.date, order: .reverse) private var allSessions: [SwimSession]
    @State private var selectedSession: SwimSession?

    private var analyzedSessions: [SwimSession] {
        allSessions.filter { $0.analysis != nil }
    }

    private var groupedByMonth: [(String, [SwimSession])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: analyzedSessions) { session in
            formatter.string(from: session.date)
        }

        return grouped
            .sorted { lhs, rhs in
                guard let lDate = lhs.value.first?.date, let rDate = rhs.value.first?.date else { return false }
                return lDate > rDate
            }
    }

    var body: some View {
        Group {
            if analyzedSessions.isEmpty {
                emptyState
            } else {
                sessionsList
            }
        }
        .navigationTitle("Workout Analyses")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSession) { session in
            if let analysis = session.analysis {
                WorkoutAnalysisView(analysis: analysis, session: session)
            }
        }
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        List {
            Section {
                Text("\(analyzedSessions.count) analys\(analyzedSessions.count == 1 ? "is" : "es")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }

            ForEach(groupedByMonth, id: \.0) { month, sessions in
                Section(month) {
                    ForEach(sessions) { session in
                        Button {
                            selectedSession = session
                        } label: {
                            analysisRow(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Analysis Row

    private func analysisRow(session: SwimSession) -> some View {
        HStack(spacing: 12) {
            // Performance score badge
            if let analysis = session.analysis {
                Text("\(analysis.performanceScore)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(scoreColor(analysis.performanceScore), in: Circle())
            }

            // Session details
            VStack(alignment: .leading, spacing: 4) {
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.bold())
                Text("\(Int(session.distance))m \u{00B7} \(Int(session.duration)) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // SWOLF trend icon
            if let analysis = session.analysis {
                Image(systemName: swolfTrendIcon(analysis.swolfTrend))
                    .font(.caption)
                    .foregroundStyle(swolfTrendColor(analysis.swolfTrend))
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Analyzed Workouts", systemImage: "chart.bar.doc.horizontal.fill")
        } description: {
            Text("Analyses will appear here after importing workouts from Apple Health.")
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 1...4: return .red
        case 5...7: return .orange
        default: return .green
        }
    }

    private func swolfTrendIcon(_ trend: String) -> String {
        switch trend {
        case "improving": return "arrow.down.right"
        case "declining": return "arrow.up.right"
        default: return "arrow.right"
        }
    }

    private func swolfTrendColor(_ trend: String) -> Color {
        switch trend {
        case "improving": return .green
        case "declining": return .red
        default: return .blue
        }
    }
}
