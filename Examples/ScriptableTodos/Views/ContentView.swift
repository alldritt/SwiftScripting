import SwiftUI

struct ContentView: View {
    @Bindable var app: TodoApplication

    var body: some View {
        NavigationSplitView {
            List(app.todoLists, selection: $app.selectedList) { list in
                NavigationLink(value: list) {
                    HStack {
                        Text(list.name)
                        Spacer()
                        Text("\(list.items.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        if app.selectedList === list { app.selectedList = nil }
                        app.todoLists.removeAll { $0 === list }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                Button("Add List", systemImage: "plus") {
                    let newList = TodoList(name: "New List")
                    app.todoLists.append(newList)
                    app.selectedList = newList
                }
            }
        } detail: {
            if let list = app.selectedList {
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
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            list.items.removeAll { $0 === item }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
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
