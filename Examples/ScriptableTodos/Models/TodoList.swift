import SwiftScripting

@Scriptable("tdls")
@MainActor
final class TodoList: ScriptableObject, @unchecked Sendable {
    @ScriptableProperty("name", code: "pnam")
    var name: String = "Untitled"

    @ScriptableElement("todo item", code: "tdim")
    var items: [TodoItem] = []

    init(name: String = "Untitled", items: [TodoItem] = []) {
        self.name = name
        self.items = items
    }
}

extension TodoList: Hashable {
    nonisolated static func == (lhs: TodoList, rhs: TodoList) -> Bool { lhs === rhs }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
