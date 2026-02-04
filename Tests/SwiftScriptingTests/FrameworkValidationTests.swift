import Testing
@testable import SwiftScripting

private typealias FCC = SwiftScripting.FourCharCode

// MARK: - Realistic Model Objects

/// Simulates the To-Do app's object model for validation testing.
private let todoListCode = FCC("tdls")
private let todoItemCode = FCC("tdim")
private let completedCode = FCC("done")
private let priorityCode = FCC("prio")
private let notesCode = FCC("note")

@MainActor
private final class ValTodoItem: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "todo item",
            code: todoItemCode,
            properties: [
                ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text),
                ScriptingPropertyDescription(name: "completed", code: completedCode, type: .boolean),
                ScriptingPropertyDescription(name: "priority", code: priorityCode, type: .integer),
                ScriptingPropertyDescription(name: "notes", code: notesCode, type: .text),
            ]
        )
    }

    nonisolated let scriptableID: String
    var scriptableName: String? { name }
    var name: String
    var completed: Bool
    var priority: Int
    var notes: String

    init(name: String, completed: Bool = false, priority: Int = 0, notes: String = "") {
        self.scriptableID = name
        self.name = name
        self.completed = completed
        self.priority = priority
        self.notes = notes
    }

    func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code {
        case .propertyName: return name
        case completedCode: return completed
        case priorityCode: return priority
        case notesCode: return notes
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
        case priorityCode:
            guard let i = value as? Int else { throw ScriptingError.typeMismatch(expected: "Int") }
            priority = i
        case notesCode:
            guard let s = value as? String else { throw ScriptingError.typeMismatch(expected: "String") }
            notes = s
        default:
            throw ScriptingError.propertyNotFound(code)
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
private final class ValTodoList: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "todo list",
            code: todoListCode,
            properties: [
                ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text),
            ],
            elements: [
                ScriptingElementDescription(name: "todo item", code: todoItemCode, objectType: "ValTodoItem"),
            ]
        )
    }

    nonisolated let scriptableID: String
    var scriptableName: String? { name }
    var name: String
    var items: [ValTodoItem]

    init(name: String, items: [ValTodoItem] = []) {
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
        default:
            throw ScriptingError.propertyNotFound(code)
        }
    }

    func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] {
        switch code {
        case todoItemCode: return items
        default: return []
        }
    }

    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
        guard code == todoItemCode, let item = object as? ValTodoItem else {
            throw ScriptingError.typeMismatch(expected: "ValTodoItem")
        }
        items.insert(item, at: index)
    }

    func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
        guard code == todoItemCode else { throw ScriptingError.elementNotFound(code) }
        items.remove(at: index)
    }
}

@MainActor
private final class ValTodoApp: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "application",
            code: .classApplication,
            properties: [
                ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text, isReadOnly: true),
            ],
            elements: [
                ScriptingElementDescription(name: "todo list", code: todoListCode, objectType: "ValTodoList"),
            ]
        )
    }

    nonisolated let scriptableID = "app"
    var scriptableName: String? { "TestApp" }
    var todoLists: [ValTodoList]

    init(todoLists: [ValTodoList] = []) {
        self.todoLists = todoLists
    }

    func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code {
        case .propertyName: return "TestApp" as any ScriptableValue
        default: return "" as any ScriptableValue
        }
    }

    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {
        throw ScriptingError.readOnlyProperty(code)
    }

    func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] {
        switch code {
        case todoListCode: return todoLists
        default: return []
        }
    }

    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
        guard code == todoListCode, let list = object as? ValTodoList else {
            throw ScriptingError.typeMismatch(expected: "ValTodoList")
        }
        todoLists.insert(list, at: index)
    }

    func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
        guard code == todoListCode else { throw ScriptingError.elementNotFound(code) }
        todoLists.remove(at: index)
    }
}

// MARK: - Text Editor Model Objects (with computed elements)

private let wordCode = FCC("cwor")
private let textCode = FCC("ctxt")
private let parCode = FCC("cpar")

@MainActor
private final class ValWord: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "word", code: wordCode,
            properties: [ScriptingPropertyDescription(name: "text", code: textCode, type: .text, isReadOnly: true)]
        )
    }

    nonisolated let scriptableID: String
    var scriptableName: String? { text }
    let text: String

    init(text: String) {
        self.scriptableID = text
        self.text = text
    }

    func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code { case textCode: return text; default: return "" as any ScriptableValue }
    }
    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws { throw ScriptingError.readOnlyProperty(code) }
    func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] { [] }
    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws { throw ScriptingError.elementNotFound(code) }
    func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws { throw ScriptingError.elementNotFound(code) }
}

@MainActor
private final class ValParagraph: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "paragraph", code: parCode,
            properties: [ScriptingPropertyDescription(name: "text", code: textCode, type: .text)],
            elements: [ScriptingElementDescription(name: "word", code: wordCode, objectType: "ValWord")]
        )
    }

    nonisolated let scriptableID: String
    var scriptableName: String? { text }
    var text: String

    init(text: String) {
        self.scriptableID = text
        self.text = text
    }

    func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code { case textCode: return text; default: return "" as any ScriptableValue }
    }

    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {
        switch code {
        case textCode:
            guard let s = value as? String else { throw ScriptingError.typeMismatch(expected: "String") }
            text = s
        default: throw ScriptingError.propertyNotFound(code)
        }
    }

    func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] {
        switch code {
        case wordCode: return text.split(separator: " ").map { ValWord(text: String($0)) }
        default: return []
        }
    }

    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
        throw ScriptingError.commandFailed("Words are computed")
    }
    func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
        throw ScriptingError.commandFailed("Words are computed")
    }
}

@MainActor
private final class ValTextDoc: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "document", code: .classDocument,
            properties: [
                ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text),
                ScriptingPropertyDescription(name: "body text", code: textCode, type: .text),
            ],
            elements: [ScriptingElementDescription(name: "paragraph", code: parCode, objectType: "ValParagraph")]
        )
    }

    nonisolated let scriptableID: String
    var scriptableName: String? { name }
    var name: String
    var bodyText: String
    var paragraphs: [ValParagraph]

    init(name: String, bodyText: String = "", paragraphs: [ValParagraph] = []) {
        self.scriptableID = name
        self.name = name
        self.bodyText = bodyText
        self.paragraphs = paragraphs
    }

    func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code {
        case .propertyName: return name
        case textCode: return bodyText
        default: return "" as any ScriptableValue
        }
    }

    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {
        switch code {
        case .propertyName:
            guard let s = value as? String else { throw ScriptingError.typeMismatch(expected: "String") }
            name = s
        case textCode:
            guard let s = value as? String else { throw ScriptingError.typeMismatch(expected: "String") }
            bodyText = s
        default: throw ScriptingError.propertyNotFound(code)
        }
    }

    func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] {
        switch code {
        case parCode: return paragraphs
        default: return []
        }
    }

    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
        guard code == parCode, let p = object as? ValParagraph else {
            throw ScriptingError.typeMismatch(expected: "ValParagraph")
        }
        paragraphs.insert(p, at: index)
    }

    func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
        guard code == parCode else { throw ScriptingError.elementNotFound(code) }
        paragraphs.remove(at: index)
    }
}

// MARK: - Test Helper

@MainActor
private func makeTodoSetup() -> (ScriptableObjectRegistry, ObjectResolver, MutationPipeline, ValTodoApp) {
    let registry = ScriptableObjectRegistry()
    let app = ValTodoApp(todoLists: [
        ValTodoList(name: "Shopping", items: [
            ValTodoItem(name: "Milk", priority: 1),
            ValTodoItem(name: "Bread", priority: 2),
            ValTodoItem(name: "Eggs", completed: true),
        ]),
        ValTodoList(name: "Work", items: [
            ValTodoItem(name: "Review PR", priority: 3),
            ValTodoItem(name: "Write tests", completed: true),
        ]),
    ])
    registry.setApplication(app)
    registry.registerClass(ValTodoApp.self)
    registry.registerClass(ValTodoList.self)
    registry.registerClass(ValTodoItem.self)
    registry.registerFactory(for: todoListCode) { ValTodoList(name: "New List") }
    registry.registerFactory(for: todoItemCode) { ValTodoItem(name: "New Item") }

    let resolver = ObjectResolver(registry: registry)
    let pipeline = MutationPipeline(registry: registry)
    return (registry, resolver, pipeline, app)
}

@MainActor
private func makeTextSetup() -> (ScriptableObjectRegistry, ObjectResolver, MutationPipeline, MockApp) {
    let registry = ScriptableObjectRegistry()
    let doc = ValTextDoc(
        name: "Test",
        bodyText: "Hello World\nSwift is great\nFoo bar baz",
        paragraphs: [
            ValParagraph(text: "Hello World"),
            ValParagraph(text: "Swift is great"),
            ValParagraph(text: "Foo bar baz"),
        ]
    )
    let app = MockApp(documents: [])
    // Use MockApp for text setup — we need a document element container
    // that uses .classDocument. Reuse from ObjectResolverTests.
    registry.setApplication(app)

    // Can't use MockApp directly for documents since types differ.
    // Use a separate TextApp.
    let textApp = ValTextApp(documents: [doc])
    registry.setApplication(textApp)
    registry.registerClass(ValTextApp.self)
    registry.registerClass(ValTextDoc.self)
    registry.registerClass(ValParagraph.self)
    registry.registerClass(ValWord.self)
    registry.registerFactory(for: .classDocument) { ValTextDoc(name: "New Document") }
    registry.registerFactory(for: parCode) { ValParagraph(text: "") }

    let resolver = ObjectResolver(registry: registry)
    let pipeline = MutationPipeline(registry: registry)
    return (registry, resolver, pipeline, app)
}

@MainActor
private final class ValTextApp: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "application", code: .classApplication,
            properties: [ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text, isReadOnly: true)],
            elements: [ScriptingElementDescription(name: "document", code: .classDocument, objectType: "ValTextDoc")]
        )
    }

    nonisolated let scriptableID = "app"
    var scriptableName: String? { "TextApp" }
    var documents: [ValTextDoc]

    init(documents: [ValTextDoc] = []) { self.documents = documents }

    func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code { case .propertyName: return "TextApp"; default: return "" as any ScriptableValue }
    }
    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws { throw ScriptingError.readOnlyProperty(code) }
    func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] {
        switch code { case .classDocument: return documents; default: return [] }
    }
    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
        guard code == .classDocument, let doc = object as? ValTextDoc else { throw ScriptingError.typeMismatch(expected: "ValTextDoc") }
        documents.insert(doc, at: index)
    }
    func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
        guard code == .classDocument else { throw ScriptingError.elementNotFound(code) }
        documents.remove(at: index)
    }
}

// MARK: - Framework Validation Tests

@Suite("Framework Validation — Todo App")
@MainActor
struct TodoValidationTests {

    // MARK: Property Access

    @Test("Property of element: name of todo list 1")
    func propertyOfElement() throws {
        let (_, resolver, _, _) = makeTodoSetup()
        let listSpec = ObjectSpecifier.index(classCode: todoListCode, index: 1, container: .application)
        let propSpec = ObjectSpecifier.property(propertyCode: .propertyName, container: listSpec)
        let results = try resolver.resolve(propSpec)
        #expect(results.count == 1)
        let nameValue = results.first?.scriptableValue(forProperty: .propertyName) as? String
        #expect(nameValue == "Shopping")
    }

    @Test("Property of nested element: name of todo item 1 of todo list 1")
    func propertyOfNestedElement() throws {
        let (_, resolver, _, _) = makeTodoSetup()
        let listSpec = ObjectSpecifier.index(classCode: todoListCode, index: 1, container: .application)
        let itemSpec = ObjectSpecifier.index(classCode: todoItemCode, index: 1, container: listSpec)
        let propSpec = ObjectSpecifier.property(propertyCode: .propertyName, container: itemSpec)
        let results = try resolver.resolve(propSpec)
        #expect(results.count == 1)
        let name = results.first?.scriptableValue(forProperty: .propertyName) as? String
        #expect(name == "Milk")
    }

    @Test("Set property via pipeline: set name of todo list 1 to 'Groceries'")
    func setPropertyViaPipeline() throws {
        let (_, resolver, pipeline, _) = makeTodoSetup()
        let listSpec = ObjectSpecifier.index(classCode: todoListCode, index: 1, container: .application)
        let target = try resolver.resolveSingle(listSpec)
        try pipeline.setProperty(.propertyName, of: target, to: "Groceries" as any ScriptableValue)

        // Verify the change
        let updated = try resolver.resolveSingle(listSpec)
        #expect(updated.scriptableName == "Groceries")
    }

    @Test("Set boolean property: set completed of todo item 1 of todo list 1 to true")
    func setBooleanProperty() throws {
        let (_, resolver, pipeline, _) = makeTodoSetup()
        let listSpec = ObjectSpecifier.index(classCode: todoListCode, index: 1, container: .application)
        let itemSpec = ObjectSpecifier.index(classCode: todoItemCode, index: 1, container: listSpec)
        let target = try resolver.resolveSingle(itemSpec)

        let before = target.scriptableValue(forProperty: completedCode) as? Bool
        #expect(before == false)

        try pipeline.setProperty(completedCode, of: target, to: true as any ScriptableValue)

        let after = target.scriptableValue(forProperty: completedCode) as? Bool
        #expect(after == true)
    }

    // MARK: Element Access

    @Test("Element by index: todo item 2 of todo list 1")
    func elementByIndex() throws {
        let (_, resolver, _, _) = makeTodoSetup()
        let listSpec = ObjectSpecifier.index(classCode: todoListCode, index: 1, container: .application)
        let itemSpec = ObjectSpecifier.index(classCode: todoItemCode, index: 2, container: listSpec)
        let results = try resolver.resolve(itemSpec)
        #expect(results.count == 1)
        #expect(results.first?.scriptableName == "Bread")
    }

    @Test("Element by name: todo list 'Work'")
    func elementByName() throws {
        let (_, resolver, _, _) = makeTodoSetup()
        let spec = ObjectSpecifier.name(classCode: todoListCode, name: "Work", container: .application)
        let results = try resolver.resolve(spec)
        #expect(results.count == 1)
        #expect(results.first?.scriptableName == "Work")
    }

    @Test("Every element: every todo item of todo list 1")
    func everyElement() throws {
        let (_, resolver, _, _) = makeTodoSetup()
        let listSpec = ObjectSpecifier.index(classCode: todoListCode, index: 1, container: .application)
        let allItems = ObjectSpecifier.every(classCode: todoItemCode, container: listSpec)
        let results = try resolver.resolve(allItems)
        #expect(results.count == 3)
    }

    @Test("Whose clause: todo items whose completed is true")
    func whoseClause() throws {
        let (_, resolver, _, _) = makeTodoSetup()
        let listSpec = ObjectSpecifier.index(classCode: todoListCode, index: 1, container: .application)
        let spec = ObjectSpecifier.whose(
            classCode: todoItemCode,
            test: .comparison(property: completedCode, op: .equal, value: .boolean(true)),
            container: listSpec
        )
        let results = try resolver.resolve(spec)
        #expect(results.count == 1)
        #expect(results.first?.scriptableName == "Eggs")
    }

    @Test("Whose clause with integer: todo items whose priority > 1")
    func whoseClauseInteger() throws {
        let (_, resolver, _, _) = makeTodoSetup()
        let listSpec = ObjectSpecifier.index(classCode: todoListCode, index: 1, container: .application)
        let spec = ObjectSpecifier.whose(
            classCode: todoItemCode,
            test: .comparison(property: priorityCode, op: .greaterThan, value: .integer(1)),
            container: listSpec
        )
        let results = try resolver.resolve(spec)
        #expect(results.count == 1)
        #expect(results.first?.scriptableName == "Bread")
    }

    // MARK: Mutation

    @Test("Make element: make new todo item in todo list 1")
    func makeElement() throws {
        let (_, resolver, pipeline, _) = makeTodoSetup()
        let listSpec = ObjectSpecifier.index(classCode: todoListCode, index: 1, container: .application)
        let container = try resolver.resolveSingle(listSpec)

        let before = container.scriptableElements(forCode: todoItemCode).count
        #expect(before == 3)

        let newItem = try pipeline.makeElement(classCode: todoItemCode, in: container)
        #expect(newItem.scriptableName == "New Item")

        let after = container.scriptableElements(forCode: todoItemCode).count
        #expect(after == 4)
    }

    @Test("Make element with properties")
    func makeElementWithProperties() throws {
        let (_, resolver, pipeline, _) = makeTodoSetup()
        let container = try resolver.resolveSingle(.application)

        let newList = try pipeline.makeElement(
            classCode: todoListCode,
            in: container,
            withProperties: [(.propertyName, "Groceries" as any ScriptableValue)]
        )
        #expect(newList.scriptableName == "Groceries")
    }

    @Test("Delete element: delete todo item 1 of todo list 1")
    func deleteElement() throws {
        let (_, resolver, pipeline, _) = makeTodoSetup()
        let listSpec = ObjectSpecifier.index(classCode: todoListCode, index: 1, container: .application)
        let container = try resolver.resolveSingle(listSpec)

        #expect(container.scriptableElements(forCode: todoItemCode).count == 3)
        try pipeline.deleteElement(at: 0, classCode: todoItemCode, from: container)
        #expect(container.scriptableElements(forCode: todoItemCode).count == 2)
        // "Milk" was at index 0, now "Bread" should be first
        #expect(container.scriptableElements(forCode: todoItemCode).first?.scriptableName == "Bread")
    }

    @Test("Make new todo list at application level")
    func makeTopLevelElement() throws {
        let (_, resolver, pipeline, app) = makeTodoSetup()
        #expect(app.todoLists.count == 2)

        let container = try resolver.resolveSingle(.application)
        _ = try pipeline.makeElement(classCode: todoListCode, in: container)
        #expect(app.todoLists.count == 3)
    }
}

@Suite("Framework Validation — Text Editor")
@MainActor
struct TextEditorValidationTests {

    private func makeSetup() -> (ObjectResolver, MutationPipeline, ValTextApp) {
        let registry = ScriptableObjectRegistry()
        let doc = ValTextDoc(
            name: "Test",
            bodyText: "Hello World\nSwift is great\nFoo bar baz",
            paragraphs: [
                ValParagraph(text: "Hello World"),
                ValParagraph(text: "Swift is great"),
                ValParagraph(text: "Foo bar baz"),
            ]
        )
        let app = ValTextApp(documents: [doc])
        registry.setApplication(app)
        registry.registerClass(ValTextApp.self)
        registry.registerClass(ValTextDoc.self)
        registry.registerClass(ValParagraph.self)
        registry.registerClass(ValWord.self)
        registry.registerFactory(for: .classDocument) { ValTextDoc(name: "New Document") }
        registry.registerFactory(for: parCode) { ValParagraph(text: "") }

        let resolver = ObjectResolver(registry: registry)
        let pipeline = MutationPipeline(registry: registry)
        return (resolver, pipeline, app)
    }

    @Test("Nested 2-level: paragraph 2 of document 1")
    func nestedTwoLevel() throws {
        let (resolver, _, _) = makeSetup()
        let docSpec = ObjectSpecifier.index(classCode: .classDocument, index: 1, container: .application)
        let paraSpec = ObjectSpecifier.index(classCode: parCode, index: 2, container: docSpec)
        let results = try resolver.resolve(paraSpec)
        #expect(results.count == 1)
        let text = results.first?.scriptableValue(forProperty: textCode) as? String
        #expect(text == "Swift is great")
    }

    @Test("Nested 3-level: word 2 of paragraph 1 of document 1")
    func nestedThreeLevel() throws {
        let (resolver, _, _) = makeSetup()
        let docSpec = ObjectSpecifier.index(classCode: .classDocument, index: 1, container: .application)
        let paraSpec = ObjectSpecifier.index(classCode: parCode, index: 1, container: docSpec)
        let wordSpec = ObjectSpecifier.index(classCode: wordCode, index: 2, container: paraSpec)
        let results = try resolver.resolve(wordSpec)
        #expect(results.count == 1)
        let text = results.first?.scriptableValue(forProperty: textCode) as? String
        #expect(text == "World")
    }

    @Test("Every word of paragraph 3 of document 1")
    func everyWordInParagraph() throws {
        let (resolver, _, _) = makeSetup()
        let docSpec = ObjectSpecifier.index(classCode: .classDocument, index: 1, container: .application)
        let paraSpec = ObjectSpecifier.index(classCode: parCode, index: 3, container: docSpec)
        let wordsSpec = ObjectSpecifier.every(classCode: wordCode, container: paraSpec)
        let results = try resolver.resolve(wordsSpec)
        #expect(results.count == 3) // "Foo", "bar", "baz"
    }

    @Test("Property of nested element: text of paragraph 1 of document 1")
    func propertyOfNestedElement() throws {
        let (resolver, _, _) = makeSetup()
        let docSpec = ObjectSpecifier.index(classCode: .classDocument, index: 1, container: .application)
        let paraSpec = ObjectSpecifier.index(classCode: parCode, index: 1, container: docSpec)
        let propSpec = ObjectSpecifier.property(propertyCode: textCode, container: paraSpec)
        let results = try resolver.resolve(propSpec)
        #expect(results.count == 1)
        let text = results.first?.scriptableValue(forProperty: textCode) as? String
        #expect(text == "Hello World")
    }

    @Test("Set text of paragraph via pipeline")
    func setTextOfParagraph() throws {
        let (resolver, pipeline, _) = makeSetup()
        let docSpec = ObjectSpecifier.index(classCode: .classDocument, index: 1, container: .application)
        let paraSpec = ObjectSpecifier.index(classCode: parCode, index: 1, container: docSpec)
        let target = try resolver.resolveSingle(paraSpec)

        try pipeline.setProperty(textCode, of: target, to: "Goodbye World" as any ScriptableValue)

        let updated = target.scriptableValue(forProperty: textCode) as? String
        #expect(updated == "Goodbye World")
    }

    @Test("Make new paragraph in document")
    func makeNewParagraph() throws {
        let (resolver, pipeline, _) = makeSetup()
        let docSpec = ObjectSpecifier.index(classCode: .classDocument, index: 1, container: .application)
        let container = try resolver.resolveSingle(docSpec)

        #expect(container.scriptableElements(forCode: parCode).count == 3)
        _ = try pipeline.makeElement(classCode: parCode, in: container)
        #expect(container.scriptableElements(forCode: parCode).count == 4)
    }

    @Test("Delete paragraph from document")
    func deleteParagraph() throws {
        let (resolver, pipeline, _) = makeSetup()
        let docSpec = ObjectSpecifier.index(classCode: .classDocument, index: 1, container: .application)
        let container = try resolver.resolveSingle(docSpec)

        #expect(container.scriptableElements(forCode: parCode).count == 3)
        try pipeline.deleteElement(at: 0, classCode: parCode, from: container)
        #expect(container.scriptableElements(forCode: parCode).count == 2)
    }

    @Test("Computed word elements update when paragraph text changes")
    func computedWordsUpdate() throws {
        let (resolver, pipeline, _) = makeSetup()
        let docSpec = ObjectSpecifier.index(classCode: .classDocument, index: 1, container: .application)
        let paraSpec = ObjectSpecifier.index(classCode: parCode, index: 1, container: docSpec)
        let paragraph = try resolver.resolveSingle(paraSpec)

        // Before: "Hello World" → 2 words
        #expect(paragraph.scriptableElements(forCode: wordCode).count == 2)

        // Change text
        try pipeline.setProperty(textCode, of: paragraph, to: "Hello Beautiful World" as any ScriptableValue)

        // After: "Hello Beautiful World" → 3 words
        #expect(paragraph.scriptableElements(forCode: wordCode).count == 3)
    }

    @Test("Whose clause across paragraphs: paragraphs whose text begins with 'F'")
    func whoseParagraphs() throws {
        let (resolver, _, _) = makeSetup()
        let docSpec = ObjectSpecifier.index(classCode: .classDocument, index: 1, container: .application)
        let spec = ObjectSpecifier.whose(
            classCode: parCode,
            test: .comparison(property: textCode, op: .beginsWith, value: .string("F")),
            container: docSpec
        )
        let results = try resolver.resolve(spec)
        #expect(results.count == 1)
        #expect(results.first?.scriptableValue(forProperty: textCode) as? String == "Foo bar baz")
    }

    @Test("Make new document at application level")
    func makeDocument() throws {
        let (resolver, pipeline, app) = makeSetup()
        #expect(app.documents.count == 1)

        let container = try resolver.resolveSingle(.application)
        let newDoc = try pipeline.makeElement(classCode: .classDocument, in: container)
        #expect(newDoc.scriptableName == "New Document")
        #expect(app.documents.count == 2)
    }

    @Test("Computed words cannot be inserted")
    func wordInsertThrows() throws {
        let (resolver, _, _) = makeSetup()
        let docSpec = ObjectSpecifier.index(classCode: .classDocument, index: 1, container: .application)
        let paraSpec = ObjectSpecifier.index(classCode: parCode, index: 1, container: docSpec)
        let paragraph = try resolver.resolveSingle(paraSpec)

        #expect(throws: ScriptingError.self) {
            try paragraph.insertScriptableElement(ValWord(text: "test"), forCode: wordCode, at: 0)
        }
    }
}
