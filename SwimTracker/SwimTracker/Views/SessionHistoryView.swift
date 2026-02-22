import SwiftUI
import SwiftData

// MARK: - Filter & Sort Options

enum SessionFilter: String, CaseIterable {
    case all = "All"
    case healthKit = "Apple Watch"
    case manual = "Manual"
}

enum SessionSort: String, CaseIterable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case longestDistance = "Longest Distance"
    case bestSwolf = "Best SWOLF"
}

// MARK: - SessionHistoryView

struct SessionHistoryView: View {
    @Query(sort: \SwimSession.date, order: .reverse) private var allSessions: [SwimSession]
    @State private var searchText = ""
    @State private var filter: SessionFilter = .all
    @State private var sortOption: SessionSort = .newestFirst
    @State private var selectedSession: SwimSession?

    private var filteredSessions: [SwimSession] {
        var result = allSessions

        // Filter
        switch filter {
        case .all: break
        case .healthKit: result = result.filter { $0.healthKitId != nil }
        case .manual: result = result.filter { $0.healthKitId == nil }
        }

        // Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { session in
                session.notes.lowercased().contains(query) ||
                session.date.formatted(date: .abbreviated, time: .omitted).lowercased().contains(query) ||
                "\(Int(session.distance))m".contains(query)
            }
        }

        // Sort
        switch sortOption {
        case .newestFirst: result.sort { $0.date > $1.date }
        case .oldestFirst: result.sort { $0.date < $1.date }
        case .longestDistance: result.sort { $0.distance > $1.distance }
        case .bestSwolf:
            result.sort { a, b in
                let aSwolf = a.detailedData?.averageSWOLF ?? Double.infinity
                let bSwolf = b.detailedData?.averageSWOLF ?? Double.infinity
                return aSwolf < bSwolf
            }
        }

        return result
    }

    private var sessionsByMonth: [(month: String, sessions: [SwimSession])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var grouped: [Date: [SwimSession]] = [:]
        for session in filteredSessions {
            let monthStart = calendar.dateInterval(of: .month, for: session.date)?.start ?? session.date
            grouped[monthStart, default: []].append(session)
        }

        return grouped
            .sorted { $0.key > $1.key }
            .map { (month: formatter.string(from: $0.key), sessions: $0.value) }
    }

    var body: some View {
        Group {
            if allSessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions Yet",
                    systemImage: "figure.pool.swim",
                    description: Text("Log or import your first swim to see it here.")
                )
            } else {
                List {
                    // Summary
                    Section {
                        HStack {
                            Image(systemName: "figure.pool.swim")
                                .foregroundStyle(.blue)
                            Text("\(filteredSessions.count) swim\(filteredSessions.count == 1 ? "" : "s") logged")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if filteredSessions.count != allSessions.count {
                                Text("of \(allSessions.count) total")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    // Filter & Sort
                    Section {
                        Picker("Filter", selection: $filter) {
                            ForEach(SessionFilter.allCases, id: \.self) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("Sort by", selection: $sortOption) {
                            ForEach(SessionSort.allCases, id: \.self) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                    }

                    // Sessions grouped by month
                    if filteredSessions.isEmpty {
                        Section {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                    Text("No matching sessions")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 16)
                        }
                    } else {
                        ForEach(sessionsByMonth, id: \.month) { group in
                            Section(group.month) {
                                ForEach(group.sessions) { session in
                                    Button {
                                        selectedSession = session
                                    } label: {
                                        SessionHistoryRow(session: session)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search by notes, date, or distance")
            }
        }
        .navigationTitle("Session History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSession) { session in
            NavigationStack {
                SessionDetailView(session: session)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { selectedSession = nil }
                        }
                    }
            }
        }
    }
}

// MARK: - Session History Row

struct SessionHistoryRow: View {
    let session: SwimSession

    var body: some View {
        HStack(spacing: 12) {
            // Date column
            VStack(spacing: 2) {
                Text(session.date, format: .dateTime.day())
                    .font(.title3.bold())
                Text(session.date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 36)

            // Main info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(Int(session.distance))m")
                        .font(.subheadline.bold())
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\(Int(session.duration)) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if session.healthKitId != nil {
                        Image(systemName: "applewatch")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }

                HStack(spacing: 8) {
                    // Difficulty
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(difficultyColor(session.difficulty))
                        Text("\(session.difficulty)/10")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // SWOLF if available
                    if let swolf = session.detailedData?.averageSWOLF {
                        HStack(spacing: 2) {
                            Text("SWOLF")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(Int(swolf))")
                                .font(.caption2.bold())
                                .foregroundStyle(swolfColor(Int(swolf)))
                        }
                    }

                    // Pace
                    if session.distance > 0 {
                        let pace = session.duration / (session.distance / 100)
                        Text("\(formatPace(pace))/100m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func difficultyColor(_ level: Int) -> Color {
        switch level {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        default: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionHistoryView()
    }
    .modelContainer(for: SwimSession.self, inMemory: true)
}
