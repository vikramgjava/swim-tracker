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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(upcomingWorkouts) { workout in
                        WorkoutCalendarCard(
                            workout: workout,
                            onView: { selectedWorkout = workout }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .scrollTargetBehavior(.viewAligned)

            Spacer()

            Button {
                dismiss()
                // Small delay to let sheet dismiss before sending message
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onRegenerate()
                }
            } label: {
                Label("Regenerate All Workouts", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
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

// MARK: - Workout Calendar Card

struct WorkoutCalendarCard: View {
    let workout: Workout
    var onView: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date header
            dateHeader
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(effortColor.opacity(0.15))

            Divider()

            // Body
            VStack(alignment: .leading, spacing: 10) {
                // Effort badge
                Text(effortLabel.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(effortColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(effortColor.opacity(0.12), in: Capsule())

                // Distance
                Text(formattedDistance)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                // Focus
                Text(workout.focus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Divider()

                // Set summary
                setSummary
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                // View button
                Button {
                    onView()
                } label: {
                    HStack {
                        Text("View Details")
                            .font(.caption.bold())
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(effortColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(effortColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .frame(width: 200, height: 320)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .scrollTransition { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.8)
                .scaleEffect(phase.isIdentity ? 1 : 0.95)
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(dayLabel)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(monthLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dayLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(workout.scheduledDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(workout.scheduledDate) {
            return "Tomorrow"
        } else {
            // Show "Sat 22" style
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE d"
            return formatter.string(from: workout.scheduledDate)
        }
    }

    private var monthLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(workout.scheduledDate) || calendar.isDateInTomorrow(workout.scheduledDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE d MMM"
            return formatter.string(from: workout.scheduledDate)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM"
            return formatter.string(from: workout.scheduledDate)
        }
    }

    // MARK: - Effort Parsing

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
        // Parse strings like "6-7/10", "8/10", "5-6/10"
        let cleaned = effortLevel.replacingOccurrences(of: "/10", with: "")
        let parts = cleaned.split(separator: "-")
        if let last = parts.last, let value = Int(last.trimmingCharacters(in: .whitespaces)) {
            return value
        }
        return 5
    }

    // MARK: - Distance

    private var formattedDistance: String {
        let dist = workout.totalDistance
        if dist >= 1000 {
            let km = Double(dist) / 1000.0
            if km.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(km)),000m"
            }
            return String(format: "%.1fkm", km)
        }
        return "\(dist)m"
    }

    // MARK: - Set Summary

    private var setSummary: some View {
        let sets = workout.sets
        let warmup = sets.filter { $0.type == "Warm-up" }
        let main = sets.filter { ["Main", "Anaerobic", "Open Water"].contains($0.type) }
        let focus = sets.filter { ["KICK", "PULL"].contains($0.type) }
        let allNonWarmup = main + focus

        return VStack(alignment: .leading, spacing: 4) {
            if !warmup.isEmpty {
                Text("Warm: \(warmup.reduce(0) { $0 + $1.reps * $1.distance })m")
            }

            ForEach(focus) { s in
                Text("\(s.type): \(setSummaryLine(s))")
                    .lineLimit(1)
            }

            ForEach(Array(main.prefix(2))) { s in
                Text("Main: \(setSummaryLine(s))")
                    .lineLimit(1)
            }

            if main.count > 2 {
                Text("+ \(main.count - 2) more sets")
                    .italic()
            }

            if warmup.isEmpty && allNonWarmup.isEmpty && !sets.isEmpty {
                ForEach(Array(sets.prefix(3))) { s in
                    Text("\(s.type): \(setSummaryLine(s))")
                        .lineLimit(1)
                }
            }
        }
    }

    private func setSummaryLine(_ set: WorkoutSet) -> String {
        if set.reps == 1 {
            return "\(set.distance)m"
        }
        return "\(set.reps)\u{00d7}\(set.distance)m"
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
