import Testing
@testable import SwiftScripting

private typealias FCC = SwiftScripting.FourCharCode

@Suite("MutationPipeline Tests")
@MainActor
struct MutationPipelineTests {

    func makeTestSetup() -> (ScriptableObjectRegistry, MutationPipeline, MockApp) {
        let registry = ScriptableObjectRegistry()
        let doc1 = MockDocument(name: "First", bodyText: "Hello")
        let app = MockApp(documents: [doc1])
        registry.setApplication(app)
        registry.registerClass(MockDocument.self)
        registry.registerFactory(for: .classDocument) {
            MockDocument(name: "New Document")
        }
        let pipeline = MutationPipeline(registry: registry)
        return (registry, pipeline, app)
    }

    @Test("Set property updates value")
    func setProperty() throws {
        let (_, pipeline, app) = makeTestSetup()
        let doc = app.documents[0]
        try pipeline.setProperty(FCC("ctxt"), of: doc, to: "World" as any ScriptableValue)
        #expect(doc.bodyText == "World")
    }

    @Test("Make element creates and inserts")
    func makeElement() throws {
        let (_, pipeline, app) = makeTestSetup()
        #expect(app.documents.count == 1)
        let newDoc = try pipeline.makeElement(classCode: .classDocument, in: app)
        #expect(app.documents.count == 2)
        #expect(newDoc.scriptableName == "New Document")
    }

    @Test("Make element with properties")
    func makeElementWithProperties() throws {
        let (_, pipeline, app) = makeTestSetup()
        let newDoc = try pipeline.makeElement(
            classCode: .classDocument,
            in: app,
            withProperties: [
                (.propertyName, "Custom Name" as any ScriptableValue),
            ]
        )
        #expect(newDoc.scriptableName == "Custom Name")
    }

    @Test("Delete element removes from container")
    func deleteElement() throws {
        let (_, pipeline, app) = makeTestSetup()
        #expect(app.documents.count == 1)
        try pipeline.deleteElement(at: 0, classCode: .classDocument, from: app)
        #expect(app.documents.count == 0)
    }

    @Test("Delete out of bounds throws")
    func deleteOutOfBounds() throws {
        let (_, pipeline, app) = makeTestSetup()
        #expect(throws: ScriptingError.self) {
            try pipeline.deleteElement(at: 5, classCode: .classDocument, from: app)
        }
    }
}
