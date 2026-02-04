import SwiftUI

struct ContentView: View {
    @Bindable var app: TodoApplication
    @State private var selectedList: TodoList?

    var body: some View {
        NavigationSplitView {
            List(app.todoLists, selection: $selectedList) { list in
                NavigationLink(value: list) {
                    HStack {
                        Text(list.name)
                        Spacer()
                        Text("\(list.items.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                Button("Add List", systemImage: "plus") {
                    let newList = TodoList(name: "New List")
                    app.todoLists.append(newList)
                    selectedList = newList
                }
            }
        } detail: {
            if let list = selectedList {
                TodoListDetailView(list: list)
            } else {
                ContentUnavailableView("Select a List", systemImage: "list.bullet")
            }
        }
    }
}

struct TodoListDetailView: View {
    @Bindable var list: TodoList

    var body: some View {
        List {
            ForEach(list.items) { item in
                TodoItemRow(item: item)
            }
            .onDelete { indexSet in
                list.items.remove(atOffsets: indexSet)
            }
        }
        .navigationTitle(list.name)
        .toolbar {
            Button("Add Item", systemImage: "plus") {
                list.items.append(TodoItem(name: "New Item"))
            }
        }
    }
}
