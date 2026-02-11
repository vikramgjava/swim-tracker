import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var session: SwimSession

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false

    // Edit state
    @State private var editDate: Date = .now
    @State private var editDistance: Double = 0
    @State private var editDuration: Double = 0
    @State private var editDifficulty: Int = 5
    @State private var editNotes: String = ""

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
            LabeledContent("Difficulty") {
                Text("\(session.difficulty) / 10")
            }
        }

        if !session.notes.isEmpty {
            Section("Notes") {
                Text(session.notes)
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
    .modelContainer(for: SwimSession.self, inMemory: true)
}
