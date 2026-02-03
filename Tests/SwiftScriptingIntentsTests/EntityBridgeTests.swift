import Testing
@testable import SwiftScripting
@testable import SwiftScriptingIntents

@Suite("EntityBridge Tests")
@MainActor
struct EntityBridgeTests {

    @Test("ScriptableEntity creation from object")
    func entityFromObject() {
        let entity = ScriptableEntity(id: "doc1", displayName: "Test Doc", classCode: .classDocument)
        #expect(entity.id == "doc1")
        #expect(entity.displayName == "Test Doc")
        #expect(entity.classCode == .classDocument)
    }

    @Test("RegistryEntityQuery finds by class code")
    func queryByClassCode() {
        let registry = ScriptableObjectRegistry()
        let app = MockAppForIntents(documents: [
            MockDocForIntents(name: "Doc A"),
            MockDocForIntents(name: "Doc B"),
        ])
        registry.setApplication(app)

        let query = RegistryEntityQuery(registry: registry)
        let entities = query.allEntities(classCode: .classDocument)
        #expect(entities.count == 2)
    }

    @Test("RegistryEntityQuery search by name")
    func queryByName() {
        let registry = ScriptableObjectRegistry()
        let app = MockAppForIntents(documents: [
            MockDocForIntents(name: "Alpha"),
            MockDocForIntents(name: "Beta"),
            MockDocForIntents(name: "Alphabet"),
        ])
        registry.setApplication(app)

        let query = RegistryEntityQuery(registry: registry)
        let entities = query.entities(matching: "Alph", classCode: .classDocument)
        #expect(entities.count == 2)
    }
}

// MARK: - Test Mocks

@MainActor
final class MockDocForIntents: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(name: "document", code: .classDocument, properties: [
            ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text),
        ])
    }

    let scriptableID: String
    var scriptableName: String? { name }
    var name: String

    init(name: String) {
        self.scriptableID = name
        self.name = name
    }

    func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code {
        case .propertyName: return name
        default: return "" as any ScriptableValue
        }
    }
    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {}
    func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] { [] }
    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {}
    func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {}
}

@MainActor
final class MockAppForIntents: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(name: "application", code: .classApplication, elements: [
            ScriptingElementDescription(name: "document", code: .classDocument, objectType: "MockDocForIntents"),
        ])
    }

    let scriptableID = "app"
    var scriptableName: String? { "TestApp" }
    var documents: [MockDocForIntents]

    init(documents: [MockDocForIntents] = []) {
        self.documents = documents
    }

    func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue { "" as any ScriptableValue }
    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {}
    func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] {
        switch code {
        case .classDocument: return documents
        default: return []
        }
    }
    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {}
    func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {}
}
