import SwiftUI
import SwiftData

struct Workout: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let targetDistance: Int // meters
    let targetDuration: Int // minutes
    let scheduledDate: Date
    let icon: String
}

struct UpcomingView: View {
    @Binding var isDarkMode: Bool
    @Query(sort: \SwimSession.date, order: .reverse) private var sessions: [SwimSession]

    private var workouts: [Workout] {
        let calendar = Calendar.current
        let today = Date.now

        // Determine next workout distances based on training progress
        let lastDistance = sessions.first?.distance ?? 400
        let bump = min(lastDistance + 200, 2400)

        return [
            Workout(
                title: "Endurance Build",
                description: "Steady pace, focus on breathing rhythm and sighting.",
                targetDistance: Int(bump),
                targetDuration: Int(bump / 20),
                scheduledDate: calendar.date(byAdding: .day, value: 1, to: today)!,
                icon: "figure.pool.swim"
            ),
            Workout(
                title: "Interval Training",
                description: "4×200m at race pace with 60s rest between sets.",
                targetDistance: 800,
                targetDuration: 40,
                scheduledDate: calendar.date(byAdding: .day, value: 3, to: today)!,
                icon: "bolt.fill"
            ),
            Workout(
                title: "Open Water Simulation",
                description: "Continuous swim with minimal wall pushoffs. Practice sighting every 10 strokes.",
                targetDistance: Int(min(bump + 200, 2400)),
                targetDuration: Int(min(bump + 200, 2400) / 18),
                scheduledDate: calendar.date(byAdding: .day, value: 6, to: today)!,
                icon: "water.waves"
            ),
        ]
    }

    var body: some View {
        NavigationStack {
            List(workouts) { workout in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: workout.icon)
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 36)
                        VStack(alignment: .leading) {
                            Text(workout.title)
                                .font(.headline)
                            Text(workout.scheduledDate, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(workout.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Label("\(workout.targetDistance)m", systemImage: "arrow.left.and.right")
                        Label("\(workout.targetDuration) min", systemImage: "clock")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Upcoming")
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

#Preview {
    UpcomingView(isDarkMode: .constant(false))
        .modelContainer(for: SwimSession.self, inMemory: true)
}
