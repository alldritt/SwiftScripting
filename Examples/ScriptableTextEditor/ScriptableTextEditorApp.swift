import SwiftUI
import SwiftScripting
#if canImport(SwiftScriptingAppleEvents)
import SwiftScriptingAppleEvents
#endif

@main
struct ScriptableTextEditorApp: App {
    @State private var application = TextEditorApplication()
    @State private var registry = ScriptableObjectRegistry()
    @State private var isSetUp = false
    #if canImport(Carbon)
    @State private var aeInterface: AppleEventInterface?
    #endif

    var body: some Scene {
        DocumentGroup(newDocument: { TextDocument() }) { config in
            DocumentEditorView(document: config.document)
                .onAppear { registerDocument(config.document) }
                .onDisappear { unregisterDocument(config.document) }
                .onAppear { setupScripting() }
        }
    }

    @MainActor
    private func registerDocument(_ doc: TextDocument) {
        if !application.documents.contains(where: { $0.scriptableID == doc.scriptableID }) {
            application.documents.append(doc)
        }
    }

    @MainActor
    private func unregisterDocument(_ doc: TextDocument) {
        application.documents.removeAll { $0.scriptableID == doc.scriptableID }
    }

    @MainActor
    private func setupScripting() {
        guard !isSetUp else { return }
        isSetUp = true

        registry.setApplication(application)
        registry.registerClass(TextEditorApplication.self)
        registry.registerClass(TextDocument.self)
        registry.registerClass(TextParagraph.self)
        registry.registerClass(TextWord.self)
        registry.registerFactory(for: .classDocument) {
            TextDocument()
        }
        registry.registerFactory(for: TextParagraph.classCode) {
            TextParagraph(text: "")
        }

        #if canImport(Carbon)
        let pipeline = MutationPipeline(registry: registry)
        let interface = AppleEventInterface(registry: registry, pipeline: pipeline)
        interface.install()
        aeInterface = interface
        #endif
    }
}
