import SwiftUI

struct CoachOption: Identifiable {
    let id = UUID()
    let number: Int
    let title: String
    let description: String
}

struct CoachOptionCardsView: View {
    let options: [CoachOption]
    let selectedIndex: Int?
    let onSelect: (CoachOption) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private let icons = [
        "1.circle.fill",
        "2.circle.fill",
        "3.circle.fill",
        "4.circle.fill"
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(options) { option in
                let index = option.number - 1
                let isSelected = selectedIndex == index
                let isArchived = selectedIndex != nil

                Button {
                    if !isArchived {
                        onSelect(option)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : icons[min(index, icons.count - 1)])
                                .font(.title3)
                                .foregroundStyle(isSelected ? .green : (isArchived ? .secondary : .blue))
                            Spacer()
                        }

                        Text(option.title)
                            .font(.caption.bold())
                            .foregroundStyle(isArchived && !isSelected ? .secondary : .primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(option.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        isSelected ? Color.green.opacity(0.08) :
                            (isArchived ? Color(.systemGray6) : Color.blue.opacity(0.06)),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isSelected ? Color.green.opacity(0.3) :
                                    (isArchived ? Color.clear : Color.blue.opacity(0.15)),
                                lineWidth: 1
                            )
                    )
                    .opacity(isArchived && !isSelected ? 0.5 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(isArchived)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Parsing

func parseCoachOptions(from text: String) -> (textBefore: String, options: [CoachOption], textAfter: String)? {
    guard let startRange = text.range(of: "OPTIONS_START"),
          let endRange = text.range(of: "OPTIONS_END") else {
        return nil
    }

    let textBefore = String(text[text.startIndex..<startRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    let textAfter = String(text[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    let optionsBlock = String(text[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

    let lines = optionsBlock.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    var options: [CoachOption] = []

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Match "Option N: Title - Description"
        guard let colonIndex = trimmed.range(of: ": ", range: trimmed.index(trimmed.startIndex, offsetBy: 6, limitedBy: trimmed.endIndex).flatMap { $0..<trimmed.endIndex } ?? trimmed.startIndex..<trimmed.endIndex) else {
            continue
        }

        let afterColon = String(trimmed[colonIndex.upperBound...]).trimmingCharacters(in: .whitespaces)

        let title: String
        let description: String
        if let dashRange = afterColon.range(of: " - ") {
            title = String(afterColon[afterColon.startIndex..<dashRange.lowerBound])
            description = String(afterColon[dashRange.upperBound...])
        } else {
            title = afterColon
            description = ""
        }

        options.append(CoachOption(number: options.count + 1, title: title, description: description))
    }

    guard options.count >= 2 else { return nil }
    return (textBefore, options, textAfter)
}
