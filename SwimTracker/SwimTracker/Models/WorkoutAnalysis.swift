import Foundation

struct WorkoutAnalysis: Codable {
    var performanceScore: Int           // 1-10, overall workout quality
    var insights: [String]              // 3-4 key observations from the AI
    var recommendation: String          // What to focus on next
    var swolfTrend: String             // "improving", "declining", or "stable"
    var paceTrend: String              // "faster", "slower", or "consistent"
    var effortVsPerformance: String    // "efficient", "hard_but_slow", or "easy_cruise"
}
