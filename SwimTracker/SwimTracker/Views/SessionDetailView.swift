import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var session: SwimSession

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var linkedWorkout: Workout?
    @State private var showingAnalysis = false

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
        .sheet(isPresented: $showingAnalysis) {
            if let analysis = session.analysis {
                WorkoutAnalysisView(analysis: analysis, session: session)
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
            // Debug: verify detailedData is loading
            print("[SessionDetail] Opening session: \(session.date.formatted(date: .abbreviated, time: .omitted)), distance=\(Int(session.distance))m")
            print("[SessionDetail] healthKitId=\(session.healthKitId ?? "nil")")
            print("[SessionDetail] detailedDataJSON exists=\(session.detailedDataJSON != nil)")
            if let data = session.detailedData {
                print("[SessionDetail] detailedData decoded OK: \(data.sets.count) sets, longestContinuous=\(data.effectiveLongestContinuousDistance)m")
                for (i, set) in data.sets.enumerated() {
                    print("[SessionDetail]   Set \(i+1): \(Int(set.totalDistance))m, \(set.laps.count) laps, SWOLF=\(set.averageSWOLF.map { String(Int($0)) } ?? "N/A"), pace=\(set.averagePace.map { formatPace($0) } ?? "N/A"), HR=\(set.averageHeartRate.map { "\($0)" } ?? "N/A")")
                }
            } else {
                print("[SessionDetail] detailedData is nil! JSON present=\(session.detailedDataJSON != nil)")
                if let json = session.detailedDataJSON {
                    print("[SessionDetail] JSON preview: \(String(json.prefix(200)))")
                }
            }
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
            if session.healthKitId != nil {
                LabeledContent("Source") {
                    HStack(spacing: 4) {
                        Image(systemName: "applewatch")
                        Text("Apple Watch")
                    }
                    .foregroundStyle(.blue)
                    .font(.caption)
                }
            }
        }

        // Workout Summary (from HealthKit detailed data)
        if let data = session.detailedData {
            Section("Workout Summary") {
                if let swolf = data.averageSWOLF {
                    LabeledContent("Avg SWOLF") {
                        HStack(spacing: 4) {
                            Text("\(Int(swolf))")
                                .bold()
                            Text("(\(swolfLabel(Int(swolf))))")
                                .font(.caption)
                        }
                        .foregroundStyle(swolfColor(Int(swolf)))
                    }
                } else {
                    LabeledContent("Avg SWOLF") { Text("N/A").foregroundStyle(.secondary) }
                }

                if let pace = data.averagePace {
                    LabeledContent("Avg Pace") {
                        Text("\(formatPace(pace)) /100m")
                            .monospacedDigit()
                    }
                } else {
                    LabeledContent("Avg Pace") { Text("N/A").foregroundStyle(.secondary) }
                }

                if let hr = data.averageHeartRate {
                    LabeledContent("Avg HR") {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(hrZoneColor(hr))
                                .frame(width: 8, height: 8)
                            Text("\(hr) bpm")
                            Text("(\(hrZoneLabel(hr)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    LabeledContent("Avg HR") { Text("N/A").foregroundStyle(.secondary) }
                }

                if let maxHR = data.maxHeartRate {
                    LabeledContent("Max HR") {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(hrZoneColor(maxHR))
                                .frame(width: 8, height: 8)
                            Text("\(maxHR) bpm")
                            Text("(\(hrZoneLabel(maxHR)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    LabeledContent("Max HR") { Text("N/A").foregroundStyle(.secondary) }
                }
            }

            // AI Analysis button
            if session.analysis != nil {
                Section {
                    Button {
                        showingAnalysis = true
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Coach Analysis")
                                    .font(.subheadline.bold())
                                Text("View AI insights for this workout")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Sets breakdown
            Section("Sets") {
                ForEach(Array(data.sets.enumerated()), id: \.offset) { index, set in
                    DisclosureGroup {
                        // Lap-by-lap breakdown
                        ForEach(Array(set.laps.enumerated()), id: \.offset) { lapIndex, lap in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("Lap \(lapIndex + 1)")
                                        .font(.caption.bold())
                                        .frame(width: 48, alignment: .leading)
                                    Text("\(Int(lap.distance))m")
                                        .font(.caption)
                                    Text(formatLapDuration(lap.duration))
                                        .font(.caption.monospacedDigit())

                                    if let swolf = lap.swolf {
                                        Text("SWOLF \(swolf)")
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(swolfColor(swolf).opacity(0.2), in: Capsule())
                                            .foregroundStyle(swolfColor(swolf))
                                    }

                                    Spacer()

                                    if let hr = lap.heartRate {
                                        HStack(spacing: 2) {
                                            Circle()
                                                .fill(hrZoneColor(hr))
                                                .frame(width: 6, height: 6)
                                            Text("\(hr)")
                                                .font(.caption2)
                                        }
                                    }
                                }

                                HStack(spacing: 8) {
                                    if let pace = lap.pace {
                                        Text("\(formatPace(pace))/100m")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let stroke = lap.strokeType {
                                        Text(stroke)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let count = lap.strokeCount {
                                        Text("\(count) strokes")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Set \(index + 1): \(Int(set.totalDistance))m")
                                    .font(.subheadline.bold())
                                Text("· \(set.laps.count) laps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if set.restAfter > 0 {
                                    Text("· rest \(Int(set.restAfter))s")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            HStack(spacing: 12) {
                                Text(set.strokeType)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue.opacity(0.1), in: Capsule())
                                if let swolf = set.averageSWOLF {
                                    Text("SWOLF \(Int(swolf))")
                                        .font(.caption2)
                                        .foregroundStyle(swolfColor(Int(swolf)))
                                }
                                if let pace = set.averagePace {
                                    Text("\(formatPace(pace))/100m")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if let hr = set.averageHeartRate {
                                    HStack(spacing: 2) {
                                        Circle()
                                            .fill(hrZoneColor(hr))
                                            .frame(width: 6, height: 6)
                                        Text("\(hr) bpm")
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                    }
                }
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

    // MARK: - Helpers

    private func formatLapDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
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
