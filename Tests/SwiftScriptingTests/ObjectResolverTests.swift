import Testing
@testable import SwiftScripting

private typealias FCC = SwiftScripting.FourCharCode

// MARK: - Mock Objects

@MainActor
final class MockDocument: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "document",
            code: .classDocument,
            properties: [
                ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text),
                ScriptingPropertyDescription(name: "body text", code: FCC("ctxt"), type: .text),
            ],
            elements: [
                ScriptingElementDescription(name: "paragraph", code: FCC("cpar")),
            ]
        )
    }

    let scriptableID: String
    var scriptableName: String? { name }

    var name: String
    var bodyText: String
    var paragraphs: [MockParagraph]

    init(name: String, bodyText: String = "", paragraphs: [MockParagraph] = []) {
        self.scriptableID = name  // Use name as ID for testing simplicity
        self.name = name
        self.bodyText = bodyText
        self.paragraphs = paragraphs
    }

    func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code {
        case .propertyName: return name
        case FCC("ctxt"): return bodyText
        default: return "" as any ScriptableValue
        }
    }

    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {
        switch code {
        case .propertyName:
            guard let s = value as? String else { throw ScriptingError.typeMismatch(expected: String.self) }
            name = s
        case FCC("ctxt"):
            guard let s = value as? String else { throw ScriptingError.typeMismatch(expected: String.self) }
            bodyText = s
        default:
            throw ScriptingError.propertyNotFound(code)
        }
    }

    func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] {
        switch code {
        case FCC("cpar"): return paragraphs
        default: return []
        }
    }

    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
        guard code == FCC("cpar"), let p = object as? MockParagraph else {
            throw ScriptingError.typeMismatch(expected: MockParagraph.self)
        }
        paragraphs.insert(p, at: index)
    }

    func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
        guard code == FCC("cpar") else {
            throw ScriptingError.elementNotFound(code)
        }
        paragraphs.remove(at: index)
    }
}

@MainActor
final class MockParagraph: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "paragraph",
            code: FCC("cpar"),
            properties: [
                ScriptingPropertyDescription(name: "text", code: FCC("ctxt"), type: .text),
            ],
            elements: []
        )
    }

    let scriptableID: String
    var scriptableName: String? { text }
    var text: String

    init(text: String) {
        self.scriptableID = text
        self.text = text
    }

    func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code {
        case FCC("ctxt"): return text
        default: return "" as any ScriptableValue
        }
    }

    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {
        switch code {
        case FCC("ctxt"):
            guard let s = value as? String else { throw ScriptingError.typeMismatch(expected: String.self) }
            text = s
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
final class MockApp: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "application",
            code: .classApplication,
            properties: [
                ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text, isReadOnly: true),
            ],
            elements: [
                ScriptingElementDescription(name: "document", code: .classDocument),
            ]
        )
    }

    let scriptableID = "app"
    var scriptableName: String? { "TestApp" }
    var documents: [MockDocument]

    init(documents: [MockDocument] = []) {
        self.documents = documents
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
        case .classDocument: return documents
        default: return []
        }
    }

    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
        guard code == .classDocument, let doc = object as? MockDocument else {
            throw ScriptingError.typeMismatch(expected: MockDocument.self)
        }
        documents.insert(doc, at: index)
    }

    func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
        guard code == .classDocument else { throw ScriptingError.elementNotFound(code) }
        documents.remove(at: index)
    }
}

// MARK: - Tests

@Suite("ObjectResolver Tests")
@MainActor
struct ObjectResolverTests {

    func makeTestRegistry() -> (ScriptableObjectRegistry, ObjectResolver, MockApp) {
        let registry = ScriptableObjectRegistry()
        let doc1 = MockDocument(name: "First", bodyText: "Hello", paragraphs: [
            MockParagraph(text: "Para 1"),
            MockParagraph(text: "Para 2"),
            MockParagraph(text: "Para 3"),
        ])
        let doc2 = MockDocument(name: "Second", bodyText: "World")
        let doc3 = MockDocument(name: "Third", bodyText: "!")
        let app = MockApp(documents: [doc1, doc2, doc3])
        registry.setApplication(app)
        let resolver = ObjectResolver(registry: registry)
        return (registry, resolver, app)
    }

    @Test("Resolve application")
    func resolveApplication() throws {
        let (_, resolver, _) = makeTestRegistry()
        let results = try resolver.resolve(.application)
        #expect(results.count == 1)
        #expect(results.first?.scriptableName == "TestApp")
    }

    @Test("Resolve by index (1-based)")
    func resolveByIndex() throws {
        let (_, resolver, _) = makeTestRegistry()
        let spec = ObjectSpecifier.index(classCode: .classDocument, index: 1, container: .application)
        let results = try resolver.resolve(spec)
        #expect(results.count == 1)
        #expect(results.first?.scriptableName == "First")
    }

    @Test("Resolve by index (second document)")
    func resolveByIndexSecond() throws {
        let (_, resolver, _) = makeTestRegistry()
        let spec = ObjectSpecifier.index(classCode: .classDocument, index: 2, container: .application)
        let results = try resolver.resolve(spec)
        #expect(results.count == 1)
        #expect(results.first?.scriptableName == "Second")
    }

    @Test("Resolve by negative index (last)")
    func resolveByNegativeIndex() throws {
        let (_, resolver, _) = makeTestRegistry()
        let spec = ObjectSpecifier.index(classCode: .classDocument, index: -1, container: .application)
        let results = try resolver.resolve(spec)
        #expect(results.count == 1)
        #expect(results.first?.scriptableName == "Third")
    }

    @Test("Resolve by name")
    func resolveByName() throws {
        let (_, resolver, _) = makeTestRegistry()
        let spec = ObjectSpecifier.name(classCode: .classDocument, name: "Second", container: .application)
        let results = try resolver.resolve(spec)
        #expect(results.count == 1)
        #expect(results.first?.scriptableName == "Second")
    }

    @Test("Resolve by name not found throws")
    func resolveByNameNotFound() throws {
        let (_, resolver, _) = makeTestRegistry()
        let spec = ObjectSpecifier.name(classCode: .classDocument, name: "Nonexistent", container: .application)
        #expect(throws: ScriptingError.self) {
            try resolver.resolve(spec)
        }
    }

    @Test("Resolve every")
    func resolveEvery() throws {
        let (_, resolver, _) = makeTestRegistry()
        let spec = ObjectSpecifier.every(classCode: .classDocument, container: .application)
        let results = try resolver.resolve(spec)
        #expect(results.count == 3)
    }

    @Test("Resolve by ID")
    func resolveByID() throws {
        let (_, resolver, _) = makeTestRegistry()
        // MockDocument uses name as ID
        let spec = ObjectSpecifier.id(classCode: .classDocument, id: "First", container: .application)
        let results = try resolver.resolve(spec)
        #expect(results.count == 1)
        #expect(results.first?.scriptableName == "First")
    }

    @Test("Resolve range")
    func resolveRange() throws {
        let (_, resolver, _) = makeTestRegistry()
        let spec = ObjectSpecifier.range(
            classCode: .classDocument,
            from: .index(1),
            to: .index(2),
            container: .application
        )
        let results = try resolver.resolve(spec)
        #expect(results.count == 2)
    }

    @Test("Resolve nested specifier (paragraph of document)")
    func resolveNested() throws {
        let (_, resolver, _) = makeTestRegistry()
        let docSpec = ObjectSpecifier.index(classCode: .classDocument, index: 1, container: .application)
        let paraSpec = ObjectSpecifier.index(classCode: FCC("cpar"), index: 2, container: docSpec)
        let results = try resolver.resolve(paraSpec)
        #expect(results.count == 1)
        #expect(results.first?.scriptableName == "Para 2")
    }

    @Test("Resolve whose clause")
    func resolveWhose() throws {
        let (_, resolver, _) = makeTestRegistry()
        let spec = ObjectSpecifier.whose(
            classCode: .classDocument,
            test: .comparison(property: .propertyName, op: .beginsWith, value: .string("F")),
            container: .application
        )
        let results = try resolver.resolve(spec)
        #expect(results.count == 1)
        #expect(results.first?.scriptableName == "First")
    }

    @Test("Resolve whose with AND")
    func resolveWhoseAnd() throws {
        let (_, resolver, _) = makeTestRegistry()
        let spec = ObjectSpecifier.whose(
            classCode: .classDocument,
            test: .and(
                .comparison(property: FCC("ctxt"), op: .equal, value: .string("Hello")),
                .comparison(property: .propertyName, op: .equal, value: .string("First"))
            ),
            container: .application
        )
        let results = try resolver.resolve(spec)
        #expect(results.count == 1)
    }

    @Test("Resolve property specifier")
    func resolveProperty() throws {
        let (_, resolver, _) = makeTestRegistry()
        let docSpec = ObjectSpecifier.index(classCode: .classDocument, index: 1, container: .application)
        let propSpec = ObjectSpecifier.property(propertyCode: FCC("ctxt"), container: docSpec)
        let results = try resolver.resolve(propSpec)
        // Property resolution returns the container
        #expect(results.count == 1)
    }

    @Test("Index out of bounds throws")
    func indexOutOfBounds() throws {
        let (_, resolver, _) = makeTestRegistry()
        let spec = ObjectSpecifier.index(classCode: .classDocument, index: 10, container: .application)
        #expect(throws: ScriptingError.self) {
            try resolver.resolve(spec)
        }
    }
}
