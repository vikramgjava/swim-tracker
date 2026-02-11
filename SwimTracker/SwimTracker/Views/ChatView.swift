import SwiftUI
import SwiftData

struct ChatView: View {
    @Binding var isDarkMode: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatMessage.timestamp) private var messages: [ChatMessage]
    @Query(sort: \SwimSession.date, order: .reverse) private var sessions: [SwimSession]
    @Query(
        filter: #Predicate<Workout> { !$0.isCompleted },
        sort: \Workout.scheduledDate
    ) private var upcomingWorkouts: [Workout]

    @State private var service = AnthropicService()
    @State private var messageText = ""
    @State private var showSettings = false
    @AppStorage("anthropicAPIKey") private var apiKey = ""
    @State private var showError = false
    @State private var showWorkoutBanner = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if service.isLoading {
                            HStack {
                                ProgressView()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 16))
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("loading")
                        }
                    }
                    .padding(.vertical)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: service.isLoading) {
                    scrollToBottom(proxy: proxy)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        if !service.proposedWorkouts.isEmpty {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Coach proposed \(service.proposedWorkouts.count) workouts")
                                        .font(.subheadline.bold())
                                    Text("Review and accept to add to Upcoming")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Decline") {
                                    withAnimation {
                                        service.declineWorkouts()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                Button("Accept") {
                                    withAnimation {
                                        service.acceptWorkouts(modelContext: modelContext)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if showWorkoutBanner {
                            HStack {
                                Text("\u{2705} Next 3 workouts updated! Check Upcoming tab.")
                                    .font(.subheadline.bold())
                                Spacer()
                            }
                            .padding()
                            .background(.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        Divider()
                        HStack(spacing: 12) {
                            Button {
                                shareLastSwim()
                            } label: {
                                Image(systemName: "figure.open.water.swim")
                                    .font(.title3)
                            }
                            .disabled(sessions.isEmpty || service.isLoading)

                            TextField("Ask your coach...", text: $messageText, axis: .vertical)
                                .lineLimit(1...5)
                                .onSubmit { sendMessage() }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))

                            Button {
                                sendMessage()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                            }
                            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || service.isLoading)
                        }
                        .padding()
                    }
                    .background(.bar)
                }
            }
            .navigationTitle("Coach")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
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
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    service.errorMessage = nil
                }
            } message: {
                Text(service.errorMessage ?? "An unknown error occurred.")
            }
            .onChange(of: service.errorMessage) {
                if service.errorMessage != nil {
                    showError = true
                }
            }
            .onChange(of: service.workoutsUpdated) {
                if service.workoutsUpdated {
                    withAnimation {
                        showWorkoutBanner = true
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation {
                            showWorkoutBanner = false
                        }
                    }
                }
            }
        }
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Anthropic API Key") {
                    SecureField("sk-ant-...", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Text("Your API key is stored locally on this device and used only to communicate with the Anthropic API.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSettings = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var swimContext: String {
        var parts: [String] = []

        // Recent swim sessions
        let recentSessions = sessions.prefix(5)
        if !recentSessions.isEmpty {
            var sessionLines = ["RECENT SWIM SESSIONS:"]
            for s in recentSessions {
                var line = "  \(s.date.formatted(date: .abbreviated, time: .omitted)): \(Int(s.distance))m in \(Int(s.duration))min, difficulty \(s.difficulty)/10"
                if !s.notes.isEmpty { line += " — \(s.notes)" }
                sessionLines.append(line)
            }
            parts.append(sessionLines.joined(separator: "\n"))
        }

        // Overall progress
        if !sessions.isEmpty {
            let totalSwims = sessions.count
            let totalDistance = sessions.reduce(0) { $0 + $1.distance }
            let totalDuration = sessions.reduce(0) { $0 + $1.duration }
            let avgPace = totalDuration > 0 ? totalDistance / totalDuration : 0
            parts.append("""
            PROGRESS SUMMARY:
              Total swims: \(totalSwims)
              Total distance: \(Int(totalDistance))m
              Average pace: \(String(format: "%.0f", avgPace))m/min
              Goal: 3,000m continuous by August 30, 2026
            """)
        }

        // Existing upcoming workouts
        if !upcomingWorkouts.isEmpty {
            var workoutLines = ["CURRENT UPCOMING WORKOUTS:"]
            for w in upcomingWorkouts {
                workoutLines.append("  \(w.scheduledDate.formatted(date: .abbreviated, time: .omitted)): \(w.title) — \(w.totalDistance)m, \(w.focus), effort \(w.effortLevel)")
            }
            parts.append(workoutLines.joined(separator: "\n"))
        }

        return parts.joined(separator: "\n\n")
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messageText = ""

        let userMessage = ChatMessage(content: text, isUser: true)
        modelContext.insert(userMessage)

        let context = swimContext
        Task {
            do {
                let historyWithoutNew = messages
                let response = try await service.sendMessage(
                    userContent: text,
                    conversationHistory: historyWithoutNew,
                    swimContext: context
                )
                let assistantMessage = ChatMessage(content: response, isUser: false)
                modelContext.insert(assistantMessage)
            } catch {
                service.errorMessage = error.localizedDescription
            }
        }
    }

    private func shareLastSwim() {
        guard let lastSwim = sessions.first else { return }

        let totalDistance = sessions.reduce(0) { $0 + $1.distance }
        let goalDistance = 3000.0
        let progress = min(totalDistance / goalDistance * 100, 100)

        var text = """
        Here's my latest swim data:
        - Date: \(lastSwim.date.formatted(date: .abbreviated, time: .omitted))
        - Distance: \(Int(lastSwim.distance))m
        - Duration: \(Int(lastSwim.duration)) min
        - Difficulty: \(lastSwim.difficulty)/10
        """

        if !lastSwim.notes.isEmpty {
            text += "\n- Notes: \(lastSwim.notes)"
        }

        text += "\n\nProgress toward 3,000m goal: \(String(format: "%.0f", progress))% (\(Int(totalDistance))m total)"

        let recentSwims = sessions.prefix(3)
        if recentSwims.count > 1 {
            text += "\n\nLast \(recentSwims.count) swims:"
            for swim in recentSwims {
                text += "\n  \(swim.date.formatted(date: .abbreviated, time: .omitted)): \(Int(swim.distance))m in \(Int(swim.duration))min (difficulty \(swim.difficulty)/10)"
            }
        }

        text += "\n\nPlease analyze my progress and give me my next 3 workouts."

        messageText = text
        sendMessage()
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if service.isLoading {
            withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
        } else if let lastMessage = messages.last {
            withAnimation { proxy.scrollTo(lastMessage.id, anchor: .bottom) }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    message.isUser ? Color.blue : Color(.systemGray5),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(message.isUser ? .white : .primary)

            if !message.isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}

#Preview {
    ChatView(isDarkMode: .constant(false))
        .modelContainer(for: [SwimSession.self, ChatMessage.self, Workout.self], inMemory: true)
}
