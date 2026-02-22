import SwiftUI
import SwiftData

struct UpcomingView: View {
    @Binding var isDarkMode: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Workout> { !$0.isCompleted },
        sort: \Workout.scheduledDate
    ) private var upcomingWorkouts: [Workout]

    @State private var selectedWorkout: Workout? = nil
    @State private var completionDate: Date = .now
    @State private var completionDuration: Double = 30

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
                            openWorkout(workout)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openWorkout(workout)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Upcoming")
            .navigationBarTitleDisplayMode(.inline)
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
            .sheet(item: $selectedWorkout) { workout in
                WorkoutDetailSheet(
                    workout: workout,
                    completionDate: $completionDate,
                    completionDuration: $completionDuration,
                    onCancel: { selectedWorkout = nil },
                    onComplete: {
                        markCompleted(workout, date: completionDate, duration: completionDuration)
                        selectedWorkout = nil
                    }
                )
            }
        }
    }

    private func openWorkout(_ workout: Workout) {
        completionDate = .now
        completionDuration = Double(workout.actualTotalDistance) / 50.0
        selectedWorkout = workout
    }

    private func markCompleted(_ workout: Workout, date: Date, duration: Double) {
        workout.isCompleted = true
        workout.completedDate = date

        let difficulty = parseDifficulty(from: workout.effortLevel)
        let session = SwimSession(
            date: date,
            distance: Double(workout.actualTotalDistance),
            duration: duration,
            notes: "\(workout.title) — \(workout.focus)",
            difficulty: difficulty,
            workoutId: workout.id.uuidString
        )
        modelContext.insert(session)
    }

    private func parseDifficulty(from effortLevel: String) -> Int {
        let digits = effortLevel.compactMap { $0.wholeNumberValue }
        return digits.max() ?? 5
    }
}

// MARK: - Workout Detail Sheet

struct WorkoutDetailSheet: View {
    let workout: Workout
    @Binding var completionDate: Date
    @Binding var completionDuration: Double
    let onCancel: () -> Void
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workout.title)
                            .font(.title3.bold())
                        Text(workout.scheduledDate, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 20) {
                        Label("\(workout.actualTotalDistance)m", systemImage: "arrow.left.and.right")
                        Label(workout.effortLevel, systemImage: "flame.fill")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
                }

                if !workout.sets.isEmpty {
                    Section("Sets") {
                        ForEach(workout.sets) { set in
                            SetRow(set: set)
                        }
                    }
                }

                if let notes = workout.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }

                Section("Mark Complete") {
                    DatePicker("Date", selection: $completionDate, displayedComponents: .date)

                    VStack(alignment: .leading) {
                        Text("Duration: \(Int(completionDuration)) minutes")
                        Slider(value: $completionDuration, in: 5...180, step: 5)
                    }

                    Button {
                        onComplete()
                    } label: {
                        Label("Mark Complete", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onCancel)
                }
            }
        }
    }
}

// MARK: - Workout Card

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
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(.green)
            }

            // Stats row
            HStack(spacing: 16) {
                Label("\(workout.actualTotalDistance)m", systemImage: "arrow.left.and.right")
                Label(workout.focus, systemImage: "target")
                Label(workout.effortLevel, systemImage: "flame.fill")
            }
            .font(.caption.bold())
            .foregroundStyle(.blue)

            // Chevron hint
            HStack {
                Spacer()
                Text("Tap for details")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Set Row

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
