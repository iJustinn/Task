import SwiftUI

struct TaskCardView: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title.isEmpty ? "Untitled" : task.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let tags = task.tags, !tags.isEmpty {
                FlowLayout(spacing: 4, lineSpacing: 4) {
                    ForEach(tags, id: \.id) { tag in
                        TagChip(name: tag.name, colorKey: tag.colorKey, compact: true)
                    }
                }
            }

            if let start = task.workingStart {
                let today = Calendar.current.startOfDay(for: Date())
                let upcoming = Calendar.current.startOfDay(for: start) > today
                DateRow(
                    start: start,
                    end: task.workingEnd,
                    tint: upcoming ? ColorKey.blue.foreground : ColorKey.red.foreground
                )
            }

            if let due = task.dueDate {
                let today = Calendar.current.startOfDay(for: Date())
                let upcoming = Calendar.current.startOfDay(for: due) > today
                DueDateRow(date: due, isUpcoming: upcoming)
            }

            if task.hasNotes || task.hasReminder {
                HStack(spacing: 6) {
                    footerDividerLine
                    if task.hasNotes {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if task.hasReminder {
                        Image(systemName: "alarm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    footerDividerLine
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 0.5)
        )
    }

    private var footerDividerLine: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 0.5)
    }
}
