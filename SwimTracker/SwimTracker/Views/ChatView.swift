import SwiftUI
import SwiftData

struct ChatView: View {
    @Binding var isDarkMode: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatMessage.timestamp) private var messages: [ChatMessage]
    @Query(sort: \SwimSession.date, order: .reverse) private var sessions: [SwimSession]

    @State private var service = AnthropicService()
    @State private var messageText = ""
    @State private var showSettings = false
    @AppStorage("anthropicAPIKey") private var apiKey = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
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
                    .onChange(of: messages.count) {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: service.isLoading) {
                        scrollToBottom(proxy: proxy)
                    }
                }

                Divider()

                // Input area
                HStack(spacing: 12) {
                    Button {
                        shareLastSwim()
                    } label: {
                        Image(systemName: "figure.open.water.swim")
                            .font(.title3)
                    }
                    .disabled(sessions.isEmpty || service.isLoading)

                    TextField("Ask your coach...", text: $messageText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { sendMessage() }

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

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messageText = ""

        let userMessage = ChatMessage(content: text, isUser: true)
        modelContext.insert(userMessage)

        Task {
            do {
                let historyWithoutNew = messages
                let response = try await service.sendMessage(userContent: text, conversationHistory: historyWithoutNew)
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

        text += "\n\nPlease analyze my progress and suggest what I should focus on next."

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
        .modelContainer(for: [SwimSession.self, ChatMessage.self], inMemory: true)
}
