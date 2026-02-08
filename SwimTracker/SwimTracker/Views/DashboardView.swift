import SwiftUI
import SwiftData

struct DashboardView: View {
    @Binding var isDarkMode: Bool
    @Query(sort: \SwimSession.date, order: .reverse) private var sessions: [SwimSession]

    private var totalDistance: Double {
        sessions.reduce(0) { $0 + $1.distance }
    }

    private var totalDuration: Double {
        sessions.reduce(0) { $0 + $1.duration }
    }

    private var averageDifficulty: Double {
        guard !sessions.isEmpty else { return 0 }
        return Double(sessions.reduce(0) { $0 + $1.difficulty }) / Double(sessions.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Alcatraz goal banner
                    VStack(spacing: 8) {
                        Image(systemName: "figure.open.water.swim")
                            .font(.system(size: 44))
                            .foregroundStyle(.blue)
                        Text("Alcatraz Swim Training")
                            .font(.title2.bold())
                        Text("Goal: 2,400 meters (1.5 miles)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(title: "Total Swims", value: "\(sessions.count)", icon: "number", color: .blue)
                        StatCard(title: "Total Distance", value: String(format: "%.0fm", totalDistance), icon: "arrow.left.and.right", color: .teal)
                        StatCard(title: "Total Time", value: String(format: "%.0f min", totalDuration), icon: "clock.fill", color: .orange)
                        StatCard(title: "Avg Difficulty", value: String(format: "%.1f", averageDifficulty), icon: "flame.fill", color: .red)
                    }

                    // Recent swims
                    if !sessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Sessions")
                                .font(.headline)

                            ForEach(sessions.prefix(5)) { session in
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
                                }
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
