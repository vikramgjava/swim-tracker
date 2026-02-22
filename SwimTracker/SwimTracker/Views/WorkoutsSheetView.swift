import SwiftUI
import SwiftData

struct WorkoutsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Workout> { !$0.isCompleted },
        sort: \Workout.scheduledDate
    ) private var upcomingWorkouts: [Workout]

    var onRegenerate: () -> Void
    var onGenerate: () -> Void
    @State private var selectedWorkout: Workout?

    var body: some View {
        NavigationStack {
            Group {
                if upcomingWorkouts.isEmpty {
                    emptyState
                } else {
                    workoutContent
                }
            }
            .navigationTitle("Upcoming Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedWorkout) { workout in
                WorkoutOverviewSheet(workout: workout)
            }
        }
    }

    // MARK: - Main Content

    private var workoutContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(upcomingWorkouts.prefix(4))) { workout in
                        WorkoutRowCard(
                            workout: workout,
                            onTap: { selectedWorkout = workout }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }

            Divider()

            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onRegenerate()
                }
            } label: {
                Label("Regenerate All Workouts", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Workouts Scheduled")
                .font(.title3.bold())
            Text("Ask your coach to generate a training plan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onGenerate()
                }
            } label: {
                Label("Generate Workouts", systemImage: "calendar.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - Workout Row Card

struct WorkoutRowCard: View {
    let workout: Workout
    var onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 0) {
                // Color-coded left edge
                effortColor
                    .frame(width: 4)

                VStack(spacing: 0) {
                    // Top row: date, badge, distance
                    HStack {
                        Text(dateLabel)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        Text(effortLabel.uppercased())
                            .font(.caption2.bold())
                            .foregroundStyle(effortColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(effortColor.opacity(0.12), in: Capsule())

                        Spacer()

                        Text("\(workout.totalDistance)m")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    Spacer(minLength: 6)

                    // Bottom row: set summary + chevron
                    HStack {
                        Text(setSummaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date

    private var dateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(workout.scheduledDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(workout.scheduledDate) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: workout.scheduledDate)
        }
    }

    // MARK: - Effort

    private var effortLabel: String {
        let effort = parseEffort(workout.effortLevel)
        if effort >= 8 { return "Peak" }
        if effort >= 5 { return "Moderate" }
        return "Recovery"
    }

    private var effortColor: Color {
        let effort = parseEffort(workout.effortLevel)
        if effort >= 8 { return .blue }
        if effort >= 5 { return .green }
        return .orange
    }

    private func parseEffort(_ effortLevel: String) -> Int {
        let cleaned = effortLevel.replacingOccurrences(of: "/10", with: "")
        let parts = cleaned.split(separator: "-")
        if let last = parts.last, let value = Int(last.trimmingCharacters(in: .whitespaces)) {
            return value
        }
        return 5
    }

    // MARK: - Set Summary (single-line)

    private var setSummaryText: String {
        let sets = workout.sets
        var parts: [String] = []

        let warmup = sets.filter { $0.type == "Warm-up" }
        if !warmup.isEmpty {
            let dist = warmup.reduce(0) { $0 + $1.reps * $1.distance }
            parts.append("Warm: \(dist)m")
        }

        let focus = sets.filter { ["KICK", "PULL"].contains($0.type) }
        for s in focus {
            parts.append("\(s.type): \(setDesc(s))")
        }

        let main = sets.filter { ["Main", "Anaerobic", "Open Water"].contains($0.type) }
        if let first = main.first {
            var desc = "Main: \(setDesc(first))"
            if main.count > 1 { desc += " +\(main.count - 1)" }
            parts.append(desc)
        }

        if parts.isEmpty && !sets.isEmpty {
            for s in sets.prefix(2) {
                parts.append("\(s.type): \(setDesc(s))")
            }
        }

        return parts.joined(separator: " \u{2022} ")
    }

    private func setDesc(_ set: WorkoutSet) -> String {
        set.reps == 1 ? "\(set.distance)m" : "\(set.reps)\u{00d7}\(set.distance)m"
    }
}

// MARK: - Workout Detail Sheet

struct WorkoutOverviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workout: Workout

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text(workout.title)
                            .font(.title2.bold())
                        HStack(spacing: 16) {
                            Label(workout.scheduledDate.formatted(date: .long, time: .omitted), systemImage: "calendar")
                            Label("Effort: \(workout.effortLevel)", systemImage: "flame")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            Label("\(workout.totalDistance)m total", systemImage: "ruler")
                            Label(workout.focus, systemImage: "target")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Distance validation
                    let actual = workout.actualTotalDistance
                    if abs(actual - workout.totalDistance) > 50 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Calculated total: \(actual)m vs. stated \(workout.totalDistance)m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    Divider()

                    // Sets
                    ForEach(Array(workout.sets.enumerated()), id: \.element.id) { index, set in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(set.type)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(setTypeColor(set.type))
                                Spacer()
                                Text("\(set.reps * set.distance)m")
                                    .font(.subheadline.bold())
                            }

                            HStack(spacing: 12) {
                                if set.reps > 1 {
                                    Label("\(set.reps)\u{00d7}\(set.distance)m", systemImage: "repeat")
                                } else {
                                    Label("\(set.distance)m", systemImage: "arrow.right")
                                }
                                if set.rest > 0 {
                                    Label("\(set.rest)s rest", systemImage: "clock")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if !set.instructions.isEmpty {
                                Text(set.instructions)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                        .padding(.horizontal)

                        if index < workout.sets.count - 1 {
                            Divider()
                                .padding(.horizontal)
                        }
                    }

                    // Notes
                    if let notes = workout.notes, !notes.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Coach Notes")
                                .font(.subheadline.bold())
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func setTypeColor(_ type: String) -> Color {
        switch type {
        case "Warm-up": return .orange
        case "KICK": return .purple
        case "PULL": return .cyan
        case "Main": return .blue
        case "Anaerobic": return .red
        case "Open Water": return .teal
        default: return .primary
        }
    }
}
