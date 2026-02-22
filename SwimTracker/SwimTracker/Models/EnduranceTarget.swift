import Foundation
import SwiftData

@Model
final class EnduranceTarget {
    @Attribute(.unique) var weekNumber: Int
    var targetDistance: Double
    var setDate: Date
    var coachNotes: String?

    init(weekNumber: Int, targetDistance: Double, setDate: Date = .now, coachNotes: String? = nil) {
        self.weekNumber = weekNumber
        self.targetDistance = targetDistance
        self.setDate = setDate
        self.coachNotes = coachNotes
    }
}
