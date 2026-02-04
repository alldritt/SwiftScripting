import SwiftScripting

@Scriptable("todo list", code: "tdls")
@MainActor
final class TodoList: ScriptableObject, @unchecked Sendable {
    @ScriptableProperty("name", code: .propertyName)
    var name: String = "Untitled"

    @ScriptableElement
    var items: [TodoItem] = [] {
        didSet {
            print("todo items changed")
        }
    }

    init(name: String = "Untitled", items: [TodoItem] = []) {
        self.name = name
        self.items = items
    }
}

extension TodoList: Hashable {
    nonisolated static func == (lhs: TodoList, rhs: TodoList) -> Bool { lhs === rhs }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
