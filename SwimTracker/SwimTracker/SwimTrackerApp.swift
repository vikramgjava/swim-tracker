import SwiftUI
import SwiftData

@main
struct SwimTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [SwimSession.self, ChatMessage.self, Workout.self, EnduranceTarget.self])
    }
}
