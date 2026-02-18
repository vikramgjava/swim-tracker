import SwiftUI

struct WorkoutPreviewModal: View {
    let workouts: [Workout]
    let onAccept: () -> Void
    let onReject: () -> Void

    @State private var selectedIndex = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Workout \(selectedIndex + 1) of \(workouts.count)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                TabView(selection: $selectedIndex) {
                    ForEach(workouts.indices, id: \.self) { i in
                        WorkoutPreviewPage(workout: workouts[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 12) {
                    // Page navigation
                    HStack {
                        Button {
                            withAnimation { selectedIndex -= 1 }
                        } label: {
                            Label("Previous", systemImage: "chevron.left")
                                .font(.subheadline)
                        }
                        .disabled(selectedIndex == 0)

                        Spacer()

                        // Page dots
                        HStack(spacing: 6) {
                            ForEach(workouts.indices, id: \.self) { i in
                                Circle()
                                    .fill(i == selectedIndex ? Color.blue : Color(.systemGray4))
                                    .frame(width: 7, height: 7)
                            }
                        }

                        Spacer()

                        Button {
                            withAnimation { selectedIndex += 1 }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline)
                        }
                        .disabled(selectedIndex >= workouts.count - 1)
                    }
                    .padding(.horizontal)

                    // Accept / Reject
                    HStack(spacing: 12) {
                        Button {
                            onReject()
                            dismiss()
                        } label: {
                            Label("Reject All", systemImage: "xmark")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)

                        Button {
                            onAccept()
                            dismiss()
                        } label: {
                            Label("Accept All", systemImage: "checkmark")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("New Workout Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onReject()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Single Workout Page

private struct WorkoutPreviewPage: View {
    let workout: Workout

    private var isDistanceCorrect: Bool {
        abs(workout.actualTotalDistance - workout.totalDistance) <= 50
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header card
                VStack(alignment: .leading, spacing: 8) {
                    Text(workout.title)
                        .font(.title3.bold())

                    HStack(spacing: 12) {
                        Label(workout.scheduledDate.formatted(date: .abbreviated, time: .omitted),
                              systemImage: "calendar")
                        Label(workout.focus, systemImage: "target")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.and.right")
                            Text("\(workout.actualTotalDistance)m")
                                .font(.title2.bold())
                            if isDistanceCorrect {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }

                        Label(workout.effortLevel, systemImage: "flame.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                // Sets breakdown
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(workout.sets) { set in
                        SetPreviewRow(set: set)
                        if set.id != workout.sets.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                // Math validation
                mathValidationView
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
    }

    private var mathValidationView: some View {
        let parts = workout.sets.map { set -> String in
            if set.reps == 1 {
                return "\(set.distance)"
            } else {
                return "(\(set.reps)\u{00D7}\(set.distance))"
            }
        }
        let formula = parts.joined(separator: " + ")
        let calculated = workout.actualTotalDistance

        return VStack(alignment: .leading, spacing: 4) {
            if isDistanceCorrect {
                Label("\(formula) = \(formatDistance(calculated))", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Label("\(formula) = \(formatDistance(calculated))", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Coach reported: \(formatDistance(workout.totalDistance))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isDistanceCorrect ? Color.green : Color.orange).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    private func formatDistance(_ meters: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: meters)) ?? "\(meters)") + "m"
    }
}

// MARK: - Set Preview Row

private struct SetPreviewRow: View {
    let set: WorkoutSet

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(set.type)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(colorForType(set.type), in: Capsule())
                .frame(width: 80, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("\(set.reps)\u{00D7}\(set.distance)m")
                        .font(.subheadline.bold().monospaced())

                    if set.rest > 0 {
                        Text("rest: \(set.rest)s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(set.reps * set.distance)m")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                if !set.instructions.isEmpty {
                    Text(set.instructions)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
    WorkoutPreviewModal(
        workouts: [
            Workout(
                scheduledDate: .now.addingTimeInterval(86400 * 2),
                title: "Week 5 - Saturday Peak",
                totalDistance: 1800,
                focus: "Endurance",
                effortLevel: "7-8/10",
                sets: [
                    WorkoutSet(type: "Warm-up", reps: 1, distance: 200, rest: 0, instructions: "Easy freestyle"),
                    WorkoutSet(type: "KICK", reps: 6, distance: 50, rest: 60, instructions: "Strong kicks from hips"),
                    WorkoutSet(type: "Main", reps: 10, distance: 100, rest: 30, instructions: "Steady pace, build endurance"),
                    WorkoutSet(type: "Warm-up", reps: 1, distance: 100, rest: 0, instructions: "Cool down easy"),
                ]
            )
        ],
        onAccept: {},
        onReject: {}
    )
}
