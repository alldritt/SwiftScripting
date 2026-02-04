import AppIntents
import SwiftScripting
import SwiftScriptingIntents

// MARK: - Get Todo Lists

struct GetTodoListsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Todo Lists"
    static let description: IntentDescription = "Returns all todo lists."

    func perform() async throws -> some IntentResult & ReturnsValue<[TodoListEntity]> {
        let entities = await MainActor.run {
            SharedRegistry.app.todoLists.map { TodoListEntity(from: $0) }
        }
        return .result(value: entities)
    }
}

// MARK: - Create Todo List

struct CreateTodoListIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Todo List"
    static let description: IntentDescription = "Creates a new todo list."

    @Parameter(title: "Name")
    var name: String

    func perform() async throws -> some IntentResult & ReturnsValue<TodoListEntity> {
        let entity = try await MainActor.run {
            let scriptableEntity = try MakeElementBridge.makeElement(
                classCode: FourCharCode("tdls"),
                withProperties: [(.propertyName, name)],
                registry: SharedRegistry.registry
            )
            let list = SharedRegistry.app.todoLists.first { $0.scriptableID == scriptableEntity.id }!
            return TodoListEntity(from: list)
        }
        return .result(value: entity)
    }
}

// MARK: - Add Todo Item

struct AddTodoItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Todo Item"
    static let description: IntentDescription = "Adds a new todo item to a list."

    @Parameter(title: "List")
    var list: TodoListEntity

    @Parameter(title: "Name")
    var name: String

    @Parameter(title: "Priority", default: 0)
    var priority: Int

    func perform() async throws -> some IntentResult & ReturnsValue<TodoItemEntity> {
        let entity = try await MainActor.run {
            guard let todoList = SharedRegistry.app.todoLists.first(where: { $0.scriptableID == list.id }) else {
                throw ScriptingError.objectNotFound("List not found: \(list.id)")
            }
            let pipeline = MutationPipeline(registry: SharedRegistry.registry)
            let newObject = try pipeline.makeElement(
                classCode: FourCharCode("tdim"),
                in: todoList,
                withProperties: [
                    (.propertyName, name),
                    (FourCharCode("prio"), priority),
                ]
            )
            return TodoItemEntity(from: newObject as! TodoItem)
        }
        return .result(value: entity)
    }
}

// MARK: - Toggle Todo Item

struct ToggleTodoItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Todo Item"
    static let description: IntentDescription = "Toggles the completed state of a todo item."

    @Parameter(title: "Item")
    var item: TodoItemEntity

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let newState = await MainActor.run {
            let allItems = SharedRegistry.app.todoLists.flatMap(\.items)
            guard let todoItem = allItems.first(where: { $0.scriptableID == item.id }) else {
                return false
            }
            todoItem.completed.toggle()
            return todoItem.completed
        }
        return .result(value: newState)
    }
}

// MARK: - Delete Todo List

struct DeleteTodoListIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Todo List"
    static let description: IntentDescription = "Deletes a todo list."

    @Parameter(title: "List")
    var list: TodoListEntity

    func perform() async throws -> some IntentResult {
        try await MainActor.run {
            let entity = ScriptableEntity(
                id: list.id,
                displayName: list.displayName,
                classCode: FourCharCode("tdls")
            )
            try DeleteElementBridge.deleteElement(entity, registry: SharedRegistry.registry)
        }
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct TodoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTodoListsIntent(),
            phrases: ["Show my todo lists in \(.applicationName)"],
            shortTitle: "Show Lists",
            systemImageName: "list.bullet"
        )
        AppShortcut(
            intent: CreateTodoListIntent(),
            phrases: ["Create a new todo list in \(.applicationName)"],
            shortTitle: "New List",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: AddTodoItemIntent(),
            phrases: ["Add a todo item in \(.applicationName)"],
            shortTitle: "Add Item",
            systemImageName: "plus"
        )
        AppShortcut(
            intent: ToggleTodoItemIntent(),
            phrases: ["Toggle a todo in \(.applicationName)"],
            shortTitle: "Toggle Todo",
            systemImageName: "checkmark.circle"
        )
    }
}
