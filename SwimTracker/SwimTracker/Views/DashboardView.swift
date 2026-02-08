import SwiftUI
import SwiftData

struct DashboardView: View {
    @Binding var isDarkMode: Bool
    @Query(sort: \SwimSession.date, order: .reverse) private var sessions: [SwimSession]

    private var weeklyDistance: Double {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return sessions.filter { $0.date >= startOfWeek }.reduce(0) { $0 + $1.distance }
    }

    private var monthlyDistance: Double {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        return sessions.filter { $0.date >= startOfMonth }.reduce(0) { $0 + $1.distance }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Distance stats
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(title: "This Week", value: String(format: "%.0fm", weeklyDistance), icon: "calendar", color: .blue)
                        StatCard(title: "This Month", value: String(format: "%.0fm", monthlyDistance), icon: "calendar.badge.clock", color: .teal)
                    }

                    // Recent swims
                    if !sessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Sessions")
                                .font(.headline)

                            ForEach(sessions.prefix(5)) { session in
                                NavigationLink(value: session) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(session.date, style: .date)
                                                .font(.subheadline.bold())
                                            Text("\(Int(session.distance))m  ·  \(Int(session.duration)) min")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("\(session.difficulty)/10")
                                            .font(.caption.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.blue.opacity(0.15), in: Capsule())
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        ContentUnavailableView(
                            "No Swims Yet",
                            systemImage: "drop.triangle",
                            description: Text("Log your first swim to start tracking progress.")
                        )
                    }
                }
                .padding()
            }
            .navigationDestination(for: SwimSession.self) { session in
                SessionDetailView(session: session)
            }
            .navigationTitle("Dashboard")
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
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DashboardView(isDarkMode: .constant(false))
        .modelContainer(for: SwimSession.self, inMemory: true)
}
