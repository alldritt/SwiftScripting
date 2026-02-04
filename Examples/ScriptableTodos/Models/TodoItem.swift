import SwiftScripting

@Scriptable("todo item", code: "tdim")
@MainActor
final class TodoItem: ScriptableObject, @unchecked Sendable {
    @ScriptableProperty("name", code: .propertyName)
    var name: String = ""

    @ScriptableProperty("completed", code: "done")
    var completed: Bool = false

    @ScriptableProperty("priority", code: "prio")
    var priority: Int = 0

    @ScriptableProperty("notes", code: "note")
    var notes: String = ""

    init(name: String = "", completed: Bool = false, priority: Int = 0, notes: String = "") {
        self.name = name
        self.completed = completed
        self.priority = priority
        self.notes = notes
    }
}
