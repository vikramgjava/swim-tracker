import SwiftUI
import SwiftData

struct LogSwimView: View {
    @Binding var isDarkMode: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var distance: Double = 500
    @State private var duration: Double = 30
    @State private var notes = ""
    @State private var difficulty = 5
    @State private var showConfirmation = false
    @State private var savedDistance: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    VStack(alignment: .leading) {
                        Text("Distance: \(Int(distance)) meters")
                        Slider(value: $distance, in: 100...3000, step: 50)
                    }

                    VStack(alignment: .leading) {
                        Text("Duration: \(Int(duration)) minutes")
                        Slider(value: $duration, in: 5...180, step: 5)
                    }
                }

                Section("Difficulty (1-10)") {
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(1...10, id: \.self) { level in
                            Text("\(level)").tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notes") {
                    TextField("How did the swim feel?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button(action: saveSession) {
                        Label("Save Swim", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Log Swim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Swim Logged!", isPresented: $showConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your \(savedDistance)m swim has been saved.")
            }
        }
    }

    private func saveSession() {
        let session = SwimSession(
            date: date,
            distance: distance,
            duration: duration,
            notes: notes,
            difficulty: difficulty
        )
        modelContext.insert(session)
        savedDistance = Int(distance)
        showConfirmation = true
        resetForm()
    }

    private func resetForm() {
        date = .now
        distance = 500
        duration = 30
        notes = ""
        difficulty = 5
    }
}

#Preview {
    LogSwimView(isDarkMode: .constant(false))
        .modelContainer(for: SwimSession.self, inMemory: true)
}
