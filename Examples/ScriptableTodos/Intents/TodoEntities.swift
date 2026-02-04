import AppIntents
import SwiftScripting
import SwiftScriptingIntents

// MARK: - Shared Registry Accessor

@MainActor
enum SharedRegistry {
    static var registry: ScriptableObjectRegistry!
    static var app: TodoApplication { registry.application as! TodoApplication }
}

// MARK: - TodoListEntity

struct TodoListEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo List"
    static let defaultQuery = TodoListEntityQuery()

    var id: String
    var displayName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    @MainActor
    init(from list: TodoList) {
        self.id = list.scriptableID
        self.displayName = list.name
    }

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

struct TodoListEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [TodoListEntity.ID]) async throws -> [TodoListEntity] {
        await MainActor.run {
            let lists = SharedRegistry.app.todoLists
            return lists
                .filter { identifiers.contains($0.scriptableID) }
                .map { TodoListEntity(from: $0) }
        }
    }

    func suggestedEntities() async throws -> [TodoListEntity] {
        await MainActor.run {
            SharedRegistry.app.todoLists.map { TodoListEntity(from: $0) }
        }
    }

    func entities(matching query: String) async throws -> [TodoListEntity] {
        await MainActor.run {
            let lists = SharedRegistry.app.todoLists
            if query.isEmpty {
                return lists.map { TodoListEntity(from: $0) }
            }
            return lists
                .filter { $0.name.localizedCaseInsensitiveContains(query) }
                .map { TodoListEntity(from: $0) }
        }
    }
}

// MARK: - TodoItemEntity

struct TodoItemEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo Item"
    static let defaultQuery = TodoItemEntityQuery()

    var id: String
    var displayName: String
    var isCompleted: Bool
    var priority: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    @MainActor
    init(from item: TodoItem) {
        self.id = item.scriptableID
        self.displayName = item.name
        self.isCompleted = item.completed
        self.priority = item.priority
    }

    init(id: String, displayName: String, isCompleted: Bool = false, priority: Int = 0) {
        self.id = id
        self.displayName = displayName
        self.isCompleted = isCompleted
        self.priority = priority
    }
}

struct TodoItemEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    private var allItems: [TodoItem] {
        SharedRegistry.app.todoLists.flatMap(\.items)
    }

    func entities(for identifiers: [TodoItemEntity.ID]) async throws -> [TodoItemEntity] {
        await MainActor.run {
            allItems
                .filter { identifiers.contains($0.scriptableID) }
                .map { TodoItemEntity(from: $0) }
        }
    }

    func suggestedEntities() async throws -> [TodoItemEntity] {
        await MainActor.run {
            allItems.map { TodoItemEntity(from: $0) }
        }
    }

    func entities(matching query: String) async throws -> [TodoItemEntity] {
        await MainActor.run {
            if query.isEmpty {
                return allItems.map { TodoItemEntity(from: $0) }
            }
            return allItems
                .filter { $0.name.localizedCaseInsensitiveContains(query) }
                .map { TodoItemEntity(from: $0) }
        }
    }
}
