import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var session: SwimSession

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var linkedWorkout: Workout?

    // Edit state
    @State private var editDate: Date = .now
    @State private var editDistance: Double = 0
    @State private var editDuration: Double = 0
    @State private var editDifficulty: Int = 5
    @State private var editNotes: String = ""

    private var pacePerHundred: String {
        guard session.distance > 0 else { return "--" }
        let totalSeconds = (session.duration * 60) / (session.distance / 100)
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var shareSummary: String {
        var text = """
        Swim Session — \(session.date.formatted(date: .abbreviated, time: .omitted))
        Distance: \(Int(session.distance))m
        Duration: \(Int(session.duration)) min
        Pace: \(pacePerHundred) / 100m
        Difficulty: \(session.difficulty)/10
        """
        if !session.notes.isEmpty {
            text += "\nNotes: \(session.notes)"
        }
        if let workout = linkedWorkout {
            text += "\n\nWorkout: \(workout.title) (\(workout.focus))"
            for set in workout.sets {
                text += "\n  \(set.type): \(set.reps)\u{00D7}\(set.distance)m (rest: \(set.rest)s)"
            }
        }
        return text
    }

    var body: some View {
        Form {
            if isEditing {
                editContent
            } else {
                readContent
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Session", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Session" : "Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("Save") {
                        saveChanges()
                    }
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                }
            }
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isEditing = false
                    }
                }
            }
        }
        .alert("Delete Session?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSession()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This session will be permanently removed.")
        }
        .onAppear {
            loadLinkedWorkout()
        }
    }

    // MARK: - Read Mode

    @ViewBuilder
    private var readContent: some View {
        Section("Session Details") {
            LabeledContent("Date") {
                Text(session.date, style: .date)
            }
            LabeledContent("Distance") {
                Text("\(Int(session.distance)) meters")
            }
            LabeledContent("Duration") {
                Text("\(Int(session.duration)) minutes")
            }
            LabeledContent("Pace per 100m") {
                Text(pacePerHundred)
                    .monospacedDigit()
            }
            LabeledContent("Difficulty") {
                DifficultyIndicator(level: session.difficulty)
            }
        }

        if !session.notes.isEmpty {
            Section("Notes") {
                Text(session.notes)
            }
        }

        if let workout = linkedWorkout {
            Section("Workout: \(workout.title)") {
                LabeledContent("Focus") {
                    Text(workout.focus)
                }
                LabeledContent("Effort") {
                    Text(workout.effortLevel)
                }
                ForEach(workout.sets) { set in
                    SetRow(set: set)
                }
            }
        }

        Section {
            ShareLink(item: shareSummary) {
                Label("Share Swim Summary", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Edit Mode

    @ViewBuilder
    private var editContent: some View {
        Section("Session Details") {
            DatePicker("Date", selection: $editDate, displayedComponents: .date)

            VStack(alignment: .leading) {
                Text("Distance: \(Int(editDistance)) meters")
                Slider(value: $editDistance, in: 100...3000, step: 50)
            }

            VStack(alignment: .leading) {
                Text("Duration: \(Int(editDuration)) minutes")
                Slider(value: $editDuration, in: 5...180, step: 5)
            }
        }

        Section("Difficulty (1-10)") {
            Picker("Difficulty", selection: $editDifficulty) {
                ForEach(1...10, id: \.self) { level in
                    Text("\(level)").tag(level)
                }
            }
            .pickerStyle(.segmented)
        }

        Section("Notes") {
            TextField("How did the swim feel?", text: $editNotes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Actions

    private func startEditing() {
        editDate = session.date
        editDistance = session.distance
        editDuration = session.duration
        editDifficulty = session.difficulty
        editNotes = session.notes
        isEditing = true
    }

    private func saveChanges() {
        session.date = editDate
        session.distance = editDistance
        session.duration = editDuration
        session.difficulty = editDifficulty
        session.notes = editNotes
        isEditing = false
    }

    private func deleteSession() {
        modelContext.delete(session)
        dismiss()
    }

    private func loadLinkedWorkout() {
        guard let workoutIdString = session.workoutId,
              let uuid = UUID(uuidString: workoutIdString) else { return }
        let predicate = #Predicate<Workout> { $0.id == uuid }
        let descriptor = FetchDescriptor<Workout>(predicate: predicate)
        linkedWorkout = try? modelContext.fetch(descriptor).first
    }
}

// MARK: - Difficulty Indicator

struct DifficultyIndicator: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...10, id: \.self) { i in
                Circle()
                    .fill(i <= level ? colorForLevel(i) : Color(.systemGray4))
                    .frame(width: 10, height: 10)
            }
        }
    }

    private func colorForLevel(_ i: Int) -> Color {
        switch i {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        default: return .red
        }
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: SwimSession(
            date: .now,
            distance: 1200,
            duration: 45,
            notes: "Felt great today!",
            difficulty: 7
        ))
    }
    .modelContainer(for: [SwimSession.self, Workout.self], inMemory: true)
}
