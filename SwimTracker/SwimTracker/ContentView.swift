import SwiftUI

struct ContentView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        TabView {
            DashboardView(isDarkMode: $isDarkMode)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            LogSwimView(isDarkMode: $isDarkMode)
                .tabItem {
                    Label("Log Swim", systemImage: "plus.circle.fill")
                }

            UpcomingView(isDarkMode: $isDarkMode)
                .tabItem {
                    Label("Upcoming", systemImage: "calendar")
                }

            ChatView(isDarkMode: $isDarkMode)
                .tabItem {
                    Label("Coach", systemImage: "bubble.left.and.bubble.right.fill")
                }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SwimSession.self, ChatMessage.self], inMemory: true)
}
