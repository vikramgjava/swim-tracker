import SwiftUI
import SwiftData

struct UpcomingView: View {
    @Binding var isDarkMode: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Workout> { !$0.isCompleted },
        sort: \Workout.scheduledDate
    ) private var upcomingWorkouts: [Workout]

    private var nextWorkouts: [Workout] {
        Array(upcomingWorkouts.prefix(3))
    }

    var body: some View {
        NavigationStack {
            Group {
                if nextWorkouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Scheduled",
                        systemImage: "calendar.badge.plus",
                        description: Text("Check back after chatting with Coach!")
                    )
                } else {
                    List(nextWorkouts) { workout in
                        WorkoutCard(workout: workout) {
                            markCompleted(workout)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Upcoming")
            .toolbar {
                if upcomingWorkouts.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            WorkoutSeeder.seedTestWorkouts(modelContext: modelContext)
                        } label: {
                            Label("Seed Test Data", systemImage: "testtube.2")
                        }
                    }
                }
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

    private func markCompleted(_ workout: Workout) {
        workout.isCompleted = true
        workout.completedDate = .now
    }
}

struct WorkoutCard: View {
    let workout: Workout
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.headline)
                    Text(workout.scheduledDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    onComplete()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }

            // Stats row
            HStack(spacing: 16) {
                Label("\(workout.totalDistance)m", systemImage: "arrow.left.and.right")
                Label(workout.focus, systemImage: "target")
                Label(workout.effortLevel, systemImage: "flame.fill")
            }
            .font(.caption.bold())
            .foregroundStyle(.blue)

            // Sets
            if !workout.sets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(workout.sets) { set in
                        SetRow(set: set)
                    }
                }
            }

            // Notes
            if let notes = workout.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 8)
    }
}

struct SetRow: View {
    let set: WorkoutSet

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(set.type)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(colorForType(set.type), in: Capsule())

            Text("\(set.reps)\u{00D7}\(set.distance)m")
                .font(.caption.monospaced())

            if set.rest > 0 {
                Text("(rest: \(set.rest)s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("- \(set.instructions)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private func colorForType(_ type: String) -> Color {
        switch type {
        case "Warm-up": return .orange
        case "KICK": return .green
        case "PULL": return .purple
        case "Main": return .blue
        case "Anaerobic": return .red
        case "Open Water": return .teal
        default: return .gray
        }
    }
}

#Preview {
    UpcomingView(isDarkMode: .constant(false))
        .modelContainer(for: [SwimSession.self, Workout.self], inMemory: true)
}
