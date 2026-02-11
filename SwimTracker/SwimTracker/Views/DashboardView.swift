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

// MARK: - Import Date Range

enum ImportDateRange: String, CaseIterable {
    case last7 = "Last 7 Days"
    case last30 = "Last 30 Days"
    case since2026 = "Since January 2026"
    case allTime = "All Time"

    var startDate: Date {
        switch self {
        case .last7: return Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        case .last30: return Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        case .since2026: return Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .now
        case .allTime: return Calendar.current.date(from: DateComponents(year: 2015, month: 1, day: 1)) ?? .now
        }
    }
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

    private var importedIds: Set<String> {
        Set(sessions.compactMap(\.healthKitId))
    }

    private var unimportedCount: Int {
        healthKitManager.recentSwimWorkouts.filter { !importedIds.contains($0.uuid.uuidString) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // HealthKit import banner
                    if healthKitEnabled && unimportedCount > 0 {
                        Button {
                            showingHealthKitImport = true
                        } label: {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                                Text("Found \(unimportedCount) swim workout\(unimportedCount == 1 ? "" : "s") — Tap to import")
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
                HealthKitImportSheet(healthKitManager: healthKitManager)
            }
            .task {
                if healthKitEnabled {
                    await healthKitManager.requestAuthorization()
                    let jan2026 = ImportDateRange.since2026.startDate
                    await healthKitManager.fetchSwimWorkouts(from: jan2026, to: .now)
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

    @Query(sort: \SwimSession.date, order: .reverse) private var sessions: [SwimSession]
    @Query(sort: \Workout.scheduledDate) private var upcomingWorkouts: [Workout]

    @State private var dateRange: ImportDateRange = .last7
    @State private var selectedWorkout: HKWorkoutProxy?
    @State private var importDifficulty: Int = 5
    @State private var importNotes: String = ""
    @State private var linkedWorkoutId: String?
    @State private var detailedData: WorkoutDetailedData?
    @State private var isLoadingDetails = false
    @State private var showImportSuccess = false

    // Bulk import state
    @State private var showBulkConfirm = false
    @State private var isBulkImporting = false
    @State private var bulkImportProgress = 0
    @State private var bulkImportTotal = 0
    @State private var bulkImportDone = false
    @State private var bulkImportedCount = 0

    private var importedIds: Set<String> {
        Set(sessions.compactMap(\.healthKitId))
    }

    private var unimportedWorkouts: [HKWorkoutProxy] {
        healthKitManager.recentSwimWorkouts.compactMap { workout in
            let id = workout.uuid.uuidString
            guard !importedIds.contains(id) else { return nil }
            let data = healthKitManager.extractWorkoutData(workout: workout)
            return HKWorkoutProxy(id: id, workout: workout, distance: data.distance, duration: data.duration, date: data.date)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selected = selectedWorkout {
                    importForm(for: selected)
                } else {
                    workoutListView
                }
            }
            .navigationTitle(selectedWorkout == nil ? "Import Workouts" : "Import Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(selectedWorkout == nil ? "Done" : "Back") {
                        if selectedWorkout != nil {
                            resetSingleImportState()
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(isBulkImporting)
                }
            }
            .alert("Workout Imported!", isPresented: $showImportSuccess) {
                Button("OK") {
                    resetSingleImportState()
                }
            }
            .alert("Import \(unimportedWorkouts.count) workouts?", isPresented: $showBulkConfirm) {
                Button("Import All", role: .none) {
                    startBulkImport()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will import \(unimportedWorkouts.count) swim workouts from Apple Health with detailed lap data. This may take a moment.")
            }
            .alert("Import Complete", isPresented: $bulkImportDone) {
                Button("OK") {
                    if unimportedWorkouts.isEmpty {
                        dismiss()
                    }
                }
            } message: {
                Text("Successfully imported \(bulkImportedCount) workout\(bulkImportedCount == 1 ? "" : "s").")
            }
        }
        .presentationDetents([.large])
        .onChange(of: dateRange) { _, newRange in
            Task {
                await healthKitManager.fetchSwimWorkouts(from: newRange.startDate, to: .now)
            }
        }
    }

    // MARK: - Workout List View

    private var workoutListView: some View {
        List {
            // Date range picker
            Section {
                Picker("Show workouts from:", selection: $dateRange) {
                    ForEach(ImportDateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
            }

            if healthKitManager.isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Loading workouts...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if isBulkImporting {
                Section {
                    VStack(spacing: 12) {
                        ProgressView(value: Double(bulkImportProgress), total: Double(bulkImportTotal)) {
                            Text("Importing workouts...")
                                .font(.subheadline.bold())
                        } currentValueLabel: {
                            Text("\(bulkImportProgress) of \(bulkImportTotal)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else if unimportedWorkouts.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                            Text("All workouts imported!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
            } else {
                // Bulk import button
                Section {
                    Button {
                        showBulkConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down.on.square.fill")
                            Text("Import All (\(unimportedWorkouts.count))")
                                .font(.subheadline.bold())
                            Spacer()
                            if unimportedWorkouts.count > 50 {
                                Text("First 50")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Individual workouts
                Section("\(unimportedWorkouts.count) Unimported Workouts") {
                    ForEach(unimportedWorkouts) { proxy in
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
            }
        }
    }

    // MARK: - Import Form (single workout)

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
                    importSingleWorkout(proxy: proxy)
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

    // MARK: - Actions

    private func resetSingleImportState() {
        selectedWorkout = nil
        detailedData = nil
        importDifficulty = 5
        importNotes = ""
        linkedWorkoutId = nil
    }

    private func loadDetails(for proxy: HKWorkoutProxy) {
        isLoadingDetails = true
        Task {
            detailedData = await healthKitManager.fetchWorkoutDetails(for: proxy.workout)
            isLoadingDetails = false
        }
    }

    private func importSingleWorkout(proxy: HKWorkoutProxy) {
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

    private func startBulkImport() {
        // Limit to 50 at a time
        let workoutsToImport = Array(unimportedWorkouts.prefix(50))
        guard !workoutsToImport.isEmpty else { return }

        isBulkImporting = true
        bulkImportProgress = 0
        bulkImportTotal = workoutsToImport.count
        bulkImportedCount = 0

        Task {
            for proxy in workoutsToImport {
                // Double-check not already imported (could race with SwiftData updates)
                guard !importedIds.contains(proxy.id) else {
                    bulkImportProgress += 1
                    continue
                }

                // Fetch detailed data for this workout
                let details = await healthKitManager.fetchWorkoutDetails(for: proxy.workout)

                let session = SwimSession(
                    date: proxy.date,
                    distance: proxy.distance,
                    duration: proxy.duration,
                    notes: "",
                    difficulty: 5,
                    healthKitId: proxy.id,
                    detailedData: details
                )
                modelContext.insert(session)
                bulkImportedCount += 1
                bulkImportProgress += 1
            }

            isBulkImporting = false
            bulkImportDone = true
        }
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
