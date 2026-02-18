import SwiftUI

enum WorkoutCardStatus {
    case pending
    case accepted
    case rejected
}

struct WorkoutCardView: View {
    let workouts: [Workout]
    let status: WorkoutCardStatus
    let onTap: () -> Void

    private var distanceRange: String {
        let distances = workouts.map { $0.actualTotalDistance }
        guard let lo = distances.min(), let hi = distances.max() else { return "" }
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        let loStr = fmt.string(from: NSNumber(value: lo)) ?? "\(lo)"
        if lo == hi { return "\(loStr)m" }
        let hiStr = fmt.string(from: NSNumber(value: hi)) ?? "\(hi)"
        return "\(loStr)–\(hiStr)m"
    }

    private var scheduleSummary: String {
        guard let first = workouts.first?.scheduledDate,
              let last = workouts.last?.scheduledDate else { return "" }
        let days = max(1, (Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0) + 1)
        return "over next \(days) days"
    }

    var body: some View {
        switch status {
        case .pending: pendingCard
        case .accepted: acceptedCard
        case .rejected: rejectedCard
        }
    }

    // MARK: - Pending

    private var pendingCard: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    Text("Workout Plan Generated")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(workouts.count) workouts \u{00B7} \(distanceRange) each")
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Text("Scheduled \(scheduleSummary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Tap to Review & Accept")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Accepted

    private var acceptedCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Workout Plan Accepted")
                    .font(.subheadline.bold())
                Text("\(workouts.count) workouts saved to Upcoming")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Rejected

    private var rejectedCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Workout Plan Rejected")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
