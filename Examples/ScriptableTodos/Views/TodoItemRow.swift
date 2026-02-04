import SwiftUI

struct TodoItemRow: View {
    @Bindable var item: TodoItem

    var body: some View {
        HStack {
            Button {
                item.completed.toggle()
            } label: {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.completed ? .green : .secondary)
            }
            .buttonStyle(.plain)

            TextField("Item name", text: $item.name)
                .strikethrough(item.completed)
                .foregroundStyle(item.completed ? .secondary : .primary)

            Spacer()

            if item.priority > 0 {
                Text("\(item.priority)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
    }
}
