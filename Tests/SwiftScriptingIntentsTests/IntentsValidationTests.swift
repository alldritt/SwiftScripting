import Testing
@testable import SwiftScripting
@testable import SwiftScriptingIntents

private typealias FCC = SwiftScripting.FourCharCode

// MARK: - Model Objects for Intents Validation

private let todoListCode = FCC("tdls")
private let todoItemCode = FCC("tdim")
private let completedCode = FCC("done")

@MainActor
private final class IntTodoItem: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "todo item",
            code: todoItemCode,
            properties: [
                ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text),
                ScriptingPropertyDescription(name: "completed", code: completedCode, type: .boolean),
            ]
        )
    }

    nonisolated let scriptableID: String
    var scriptableName: String? { name }
    var name: String
    var completed: Bool

    init(name: String, completed: Bool = false) {
        self.scriptableID = name
        self.name = name
        self.completed = completed
    }

    func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code {
        case .propertyName: return name
        case completedCode: return completed
        default: return "" as any ScriptableValue
        }
    }

    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {
        switch code {
        case .propertyName:
            guard let s = value as? String else { throw ScriptingError.typeMismatch(expected: "String") }
            name = s
        case completedCode:
            guard let b = value as? Bool else { throw ScriptingError.typeMismatch(expected: "Bool") }
            completed = b
        default: throw ScriptingError.propertyNotFound(code)
        }
    }

    func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] { [] }
    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
        throw ScriptingError.elementNotFound(code)
    }
    func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
        throw ScriptingError.elementNotFound(code)
    }
}

@MainActor
private final class IntTodoList: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "todo list",
            code: todoListCode,
            properties: [
                ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text),
            ],
            elements: [
                ScriptingElementDescription(name: "todo item", code: todoItemCode, objectType: "IntTodoItem"),
            ]
        )
    }

    nonisolated let scriptableID: String
    var scriptableName: String? { name }
    var name: String
    var items: [IntTodoItem]

    init(name: String, items: [IntTodoItem] = []) {
        self.scriptableID = name
        self.name = name
        self.items = items
    }

    func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code {
        case .propertyName: return name
        default: return "" as any ScriptableValue
        }
    }

    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {
        switch code {
        case .propertyName:
            guard let s = value as? String else { throw ScriptingError.typeMismatch(expected: "String") }
            name = s
        default: throw ScriptingError.propertyNotFound(code)
        }
    }

    func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] {
        switch code {
        case todoItemCode: return items
        default: return []
        }
    }

    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
        guard code == todoItemCode, let item = object as? IntTodoItem else {
            throw ScriptingError.typeMismatch(expected: "IntTodoItem")
        }
        items.insert(item, at: index)
    }

    func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
        guard code == todoItemCode else { throw ScriptingError.elementNotFound(code) }
        items.remove(at: index)
    }
}

@MainActor
private final class IntTodoApp: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "application",
            code: .classApplication,
            properties: [
                ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text, isReadOnly: true),
            ],
            elements: [
                ScriptingElementDescription(name: "todo list", code: todoListCode, objectType: "IntTodoList"),
            ]
        )
    }

    nonisolated let scriptableID = "app"
    var scriptableName: String? { "TestApp" }
    var todoLists: [IntTodoList]

    init(todoLists: [IntTodoList] = []) { self.todoLists = todoLists }

    func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code { case .propertyName: return "TestApp"; default: return "" as any ScriptableValue }
    }
    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {
        throw ScriptingError.readOnlyProperty(code)
    }
    func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] {
        switch code { case todoListCode: return todoLists; default: return [] }
    }
    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
        guard code == todoListCode, let list = object as? IntTodoList else {
            throw ScriptingError.typeMismatch(expected: "IntTodoList")
        }
        todoLists.insert(list, at: index)
    }
    func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
        guard code == todoListCode else { throw ScriptingError.elementNotFound(code) }
        todoLists.remove(at: index)
    }
}

// MARK: - Tests

@Suite("App Intents Validation")
@MainActor
struct IntentsValidationTests {

    private func makeSetup() -> (ScriptableObjectRegistry, IntTodoApp) {
        let registry = ScriptableObjectRegistry()
        let app = IntTodoApp(todoLists: [
            IntTodoList(name: "Shopping", items: [
                IntTodoItem(name: "Milk"),
                IntTodoItem(name: "Bread", completed: true),
            ]),
            IntTodoList(name: "Work", items: [
                IntTodoItem(name: "Review PR"),
            ]),
        ])
        registry.setApplication(app)
        registry.registerClass(IntTodoApp.self)
        registry.registerClass(IntTodoList.self)
        registry.registerClass(IntTodoItem.self)
        registry.registerFactory(for: todoListCode) { IntTodoList(name: "New List") }
        registry.registerFactory(for: todoItemCode) { IntTodoItem(name: "New Item") }
        return (registry, app)
    }

    // MARK: Entity Creation

    @Test("ScriptableEntity from ScriptableObject")
    func entityCreation() {
        let item = IntTodoItem(name: "Test Item", completed: false)
        let entity = ScriptableEntity(from: item)
        #expect(entity.id == "Test Item")
        #expect(entity.displayName == "Test Item")
        #expect(entity.classCode == todoItemCode)
    }

    @Test("ScriptableEntity from object without name uses ID")
    func entityCreationFallback() {
        let app = IntTodoApp()
        let entity = ScriptableEntity(from: app)
        #expect(entity.displayName == "TestApp")
        #expect(entity.classCode == .classApplication)
    }

    // MARK: Registry Entity Query

    @Test("RegistryEntityQuery finds all entities by class code")
    func queryAllByClassCode() {
        let (registry, _) = makeSetup()
        let query = RegistryEntityQuery(registry: registry)
        let entities = query.allEntities(classCode: todoListCode)
        #expect(entities.count == 2)
    }

    @Test("RegistryEntityQuery search by name")
    func queryByName() {
        let (registry, _) = makeSetup()
        let query = RegistryEntityQuery(registry: registry)
        let entities = query.entities(matching: "Shop", classCode: todoListCode)
        #expect(entities.count == 1)
        #expect(entities.first?.displayName == "Shopping")
    }

    @Test("RegistryEntityQuery search returns empty for no match")
    func queryNoMatch() {
        let (registry, _) = makeSetup()
        let query = RegistryEntityQuery(registry: registry)
        let entities = query.entities(matching: "Nonexistent", classCode: todoListCode)
        #expect(entities.isEmpty)
    }

    // MARK: GetPropertyBridge

    @Test("GetPropertyBridge reads property from entity")
    func getPropertyBridge() throws {
        let (registry, _) = makeSetup()
        let entity = ScriptableEntity(id: "Shopping", displayName: "Shopping", classCode: todoListCode)
        let value = try GetPropertyBridge.getProperty(code: .propertyName, of: entity, registry: registry)
        #expect(value as? String == "Shopping")
    }

    @Test("GetPropertyBridge throws for missing entity")
    func getPropertyBridgeMissing() {
        let (registry, _) = makeSetup()
        let entity = ScriptableEntity(id: "Nonexistent", displayName: "Nonexistent", classCode: todoListCode)
        #expect(throws: ScriptingError.self) {
            try GetPropertyBridge.getProperty(code: .propertyName, of: entity, registry: registry)
        }
    }

    // MARK: SetPropertyBridge

    @Test("SetPropertyBridge writes property")
    func setPropertyBridge() throws {
        let (registry, app) = makeSetup()
        let entity = ScriptableEntity(id: "Shopping", displayName: "Shopping", classCode: todoListCode)
        try SetPropertyBridge.setProperty(code: .propertyName, of: entity, to: "Groceries" as any ScriptableValue, registry: registry)
        #expect(app.todoLists.first?.name == "Groceries")
    }

    // MARK: MakeElementBridge

    @Test("MakeElementBridge creates element")
    func makeElementBridge() throws {
        let (registry, app) = makeSetup()
        #expect(app.todoLists.count == 2)
        let entity = try MakeElementBridge.makeElement(classCode: todoListCode, registry: registry)
        #expect(app.todoLists.count == 3)
        #expect(entity.classCode == todoListCode)
    }

    @Test("MakeElementBridge with properties")
    func makeElementBridgeWithProperties() throws {
        let (registry, app) = makeSetup()
        let entity = try MakeElementBridge.makeElement(
            classCode: todoListCode,
            withProperties: [(.propertyName, "New List" as any ScriptableValue)],
            registry: registry
        )
        #expect(entity.displayName == "New List")
        #expect(app.todoLists.last?.name == "New List")
    }

    // MARK: DeleteElementBridge

    @Test("DeleteElementBridge removes element")
    func deleteElementBridge() throws {
        let (registry, app) = makeSetup()
        #expect(app.todoLists.count == 2)
        let entity = ScriptableEntity(id: "Shopping", displayName: "Shopping", classCode: todoListCode)
        try DeleteElementBridge.deleteElement(entity, registry: registry)
        #expect(app.todoLists.count == 1)
        #expect(app.todoLists.first?.name == "Work")
    }

    @Test("DeleteElementBridge throws for missing entity")
    func deleteElementBridgeMissing() {
        let (registry, _) = makeSetup()
        let entity = ScriptableEntity(id: "Nonexistent", displayName: "Nonexistent", classCode: todoListCode)
        #expect(throws: ScriptingError.self) {
            try DeleteElementBridge.deleteElement(entity, registry: registry)
        }
    }
}
