import SwiftUI
import SwiftData

// MARK: - Helper Functions

func hrZoneColor(_ bpm: Int) -> Color {
    switch bpm {
    case ..<120: return .blue
    case 120..<150: return .green
    case 150..<170: return .orange
    default: return .red
    }
}

func hrZoneLabel(_ bpm: Int) -> String {
    switch bpm {
    case ..<120: return "Recovery"
    case 120..<150: return "Aerobic"
    case 150..<170: return "Threshold"
    default: return "Max Effort"
    }
}

func swolfColor(_ swolf: Int) -> Color {
    switch swolf {
    case ..<35: return .blue
    case 35...45: return .green
    default: return .orange
    }
}

func swolfLabel(_ swolf: Int) -> String {
    switch swolf {
    case ..<35: return "Excellent"
    case 35...45: return "Good"
    default: return "Needs Work"
    }
}

func formatPace(_ minutesPer100m: Double) -> String {
    let totalSeconds = Int(minutesPer100m * 60)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
}

// MARK: - DashboardView

struct DashboardView: View {
    @Binding var isDarkMode: Bool
    @Query(sort: \SwimSession.date, order: .reverse) private var sessions: [SwimSession]
    @State private var showingLogSwim = false
    @State private var healthKitManager = HealthKitManager()
    @State private var showingHealthKitImport = false
    @AppStorage("healthKitEnabled") private var healthKitEnabled = false

    private var weeklyDistance: Double {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return sessions.filter { $0.date >= startOfWeek }.reduce(0) { $0 + $1.distance }
    }

    private var monthlyDistance: Double {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        return sessions.filter { $0.date >= startOfMonth }.reduce(0) { $0 + $1.distance }
    }

    private var unimportedWorkouts: [HKWorkoutProxy] {
        let importedIds = Set(sessions.compactMap(\.healthKitId))
        return healthKitManager.recentSwimWorkouts.compactMap { workout in
            let id = workout.uuid.uuidString
            guard !importedIds.contains(id) else { return nil }
            let data = healthKitManager.extractWorkoutData(workout: workout)
            return HKWorkoutProxy(id: id, workout: workout, distance: data.distance, duration: data.duration, date: data.date)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // HealthKit import banner
                    if healthKitEnabled && !unimportedWorkouts.isEmpty {
                        Button {
                            showingHealthKitImport = true
                        } label: {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                                Text("Found \(unimportedWorkouts.count) swim workout\(unimportedWorkouts.count == 1 ? "" : "s") — Tap to import")
                                    .font(.subheadline.bold())
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    // Distance stats
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(title: "This Week", value: String(format: "%.0fm", weeklyDistance), icon: "calendar", color: .blue)
                        StatCard(title: "This Month", value: String(format: "%.0fm", monthlyDistance), icon: "calendar.badge.clock", color: .teal)
                    }

                    // Recent swims
                    if !sessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Sessions")
                                .font(.headline)

                            ForEach(sessions.prefix(5)) { session in
                                NavigationLink(value: session) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            HStack(spacing: 4) {
                                                Text(session.date, style: .date)
                                                    .font(.subheadline.bold())
                                                if session.healthKitId != nil {
                                                    Image(systemName: "applewatch")
                                                        .font(.caption2)
                                                        .foregroundStyle(.blue)
                                                }
                                            }
                                            Text("\(Int(session.distance))m  ·  \(Int(session.duration)) min")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("\(session.difficulty)/10")
                                            .font(.caption.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.blue.opacity(0.15), in: Capsule())
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        ContentUnavailableView(
                            "No Swims Yet",
                            systemImage: "drop.triangle",
                            description: Text("Log your first swim to start tracking progress.")
                        )
                    }
                }
                .padding()
            }
            .navigationDestination(for: SwimSession.self) { session in
                SessionDetailView(session: session)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingLogSwim = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        Button {
                            isDarkMode.toggle()
                        } label: {
                            Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingLogSwim) {
                LogSwimView(isDarkMode: $isDarkMode)
            }
            .sheet(isPresented: $showingHealthKitImport) {
                HealthKitImportSheet(
                    healthKitManager: healthKitManager,
                    unimportedWorkouts: unimportedWorkouts
                )
            }
            .task {
                if healthKitEnabled {
                    await healthKitManager.requestAuthorization()
                    let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
                    await healthKitManager.fetchRecentSwimWorkouts(since: thirtyDaysAgo)
                }
            }
        }
    }
}

// MARK: - HKWorkoutProxy

import HealthKit

struct HKWorkoutProxy: Identifiable {
    let id: String
    let workout: HKWorkout
    let distance: Double
    let duration: Double
    let date: Date
}

// MARK: - HealthKit Import Sheet

struct HealthKitImportSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var healthKitManager: HealthKitManager
    let unimportedWorkouts: [HKWorkoutProxy]

    @Query(sort: \Workout.scheduledDate) private var upcomingWorkouts: [Workout]

    @State private var selectedWorkout: HKWorkoutProxy?
    @State private var importDifficulty: Int = 5
    @State private var importNotes: String = ""
    @State private var linkedWorkoutId: String?
    @State private var detailedData: WorkoutDetailedData?
    @State private var isLoadingDetails = false
    @State private var showImportSuccess = false

    var body: some View {
        NavigationStack {
            Group {
                if let selected = selectedWorkout {
                    importForm(for: selected)
                } else {
                    workoutList
                }
            }
            .navigationTitle(selectedWorkout == nil ? "Import Workouts" : "Import Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(selectedWorkout == nil ? "Done" : "Back") {
                        if selectedWorkout != nil {
                            selectedWorkout = nil
                            detailedData = nil
                            importDifficulty = 5
                            importNotes = ""
                            linkedWorkoutId = nil
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Workout Imported!", isPresented: $showImportSuccess) {
                Button("OK") {
                    selectedWorkout = nil
                    detailedData = nil
                    importDifficulty = 5
                    importNotes = ""
                    linkedWorkoutId = nil
                    if unimportedWorkouts.isEmpty {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var workoutList: some View {
        List(unimportedWorkouts) { proxy in
            Button {
                selectedWorkout = proxy
                loadDetails(for: proxy)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(proxy.date, style: .date)
                            .font(.subheadline.bold())
                        Text("\(Int(proxy.distance))m · \(Int(proxy.duration)) min")
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

    private func importForm(for proxy: HKWorkoutProxy) -> some View {
        Form {
            Section("Workout Info") {
                LabeledContent("Date") {
                    Text(proxy.date, style: .date)
                }
                LabeledContent("Distance") {
                    Text("\(Int(proxy.distance)) meters")
                }
                LabeledContent("Duration") {
                    Text("\(Int(proxy.duration)) minutes")
                }
            }

            Section("Detailed Data") {
                if isLoadingDetails {
                    HStack {
                        ProgressView()
                        Text("Loading workout details...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let data = detailedData {
                    LabeledContent("Sets Detected") {
                        Text("\(data.sets.count)")
                    }
                    if let swolf = data.averageSWOLF {
                        LabeledContent("Avg SWOLF") {
                            Text("\(Int(swolf))")
                                .foregroundStyle(swolfColor(Int(swolf)))
                        }
                    }
                    if let pace = data.averagePace {
                        LabeledContent("Avg Pace") {
                            Text("\(formatPace(pace)) /100m")
                                .monospacedDigit()
                        }
                    }
                    if let hr = data.averageHeartRate {
                        LabeledContent("Avg HR") {
                            Text("\(hr) bpm")
                                .foregroundStyle(hrZoneColor(hr))
                        }
                    }
                    if let maxHR = data.maxHeartRate {
                        LabeledContent("Max HR") {
                            Text("\(maxHR) bpm")
                                .foregroundStyle(hrZoneColor(maxHR))
                        }
                    }

                    // Set summary
                    ForEach(Array(data.sets.enumerated()), id: \.offset) { index, set in
                        Text("Set \(index + 1): \(Int(set.totalDistance))m (\(set.laps.count) laps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No detailed data available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Difficulty (1-10)") {
                Picker("Difficulty", selection: $importDifficulty) {
                    ForEach(1...10, id: \.self) { level in
                        Text("\(level)").tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Notes") {
                TextField("How did the swim feel?", text: $importNotes, axis: .vertical)
                    .lineLimit(3...6)
            }

            if !upcomingWorkouts.isEmpty {
                Section("Link to Workout") {
                    Picker("Workout", selection: $linkedWorkoutId) {
                        Text("None").tag(String?.none)
                        ForEach(upcomingWorkouts) { workout in
                            Text("\(workout.title) — \(workout.scheduledDate.formatted(date: .abbreviated, time: .omitted))")
                                .tag(Optional(workout.id.uuidString))
                        }
                    }
                }
            }

            Section {
                Button {
                    importWorkout(proxy: proxy)
                } label: {
                    Label("Import Workout", systemImage: "square.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }

    private func loadDetails(for proxy: HKWorkoutProxy) {
        isLoadingDetails = true
        Task {
            detailedData = await healthKitManager.fetchWorkoutDetails(for: proxy.workout)
            isLoadingDetails = false
        }
    }

    private func importWorkout(proxy: HKWorkoutProxy) {
        let session = SwimSession(
            date: proxy.date,
            distance: proxy.distance,
            duration: proxy.duration,
            notes: importNotes,
            difficulty: importDifficulty,
            workoutId: linkedWorkoutId,
            healthKitId: proxy.id,
            detailedData: detailedData
        )
        modelContext.insert(session)
        showImportSuccess = true
    }
}

// MARK: - StatCard

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DashboardView(isDarkMode: .constant(false))
        .modelContainer(for: SwimSession.self, inMemory: true)
}
