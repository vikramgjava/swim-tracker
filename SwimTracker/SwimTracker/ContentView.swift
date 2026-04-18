import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            DashboardView(isDarkMode: $isDarkMode)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            StatisticsView(isDarkMode: $isDarkMode)
                .tabItem {
                    Label("Statistics", systemImage: "chart.xyaxis.line")
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
        .task {
            UnitMigration.migrateIfNeeded(modelContext: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SwimSession.self, ChatMessage.self, Workout.self], inMemory: true)
}
