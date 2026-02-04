import SwiftUI
import SwiftScripting
#if canImport(SwiftScriptingAppleEvents)
import SwiftScriptingAppleEvents
#endif

@main
struct ScriptableTextEditorApp: App {
    @State private var application = ScriptableApplication()
    @State private var registry = ScriptableObjectRegistry()
    @State private var isSetUp = false
    #if canImport(Carbon)
    @State private var aeInterface: AppleEventInterface?
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView(app: application)
                .environment(\.scriptingRegistry, registry)
                .onAppear { setupScripting() }
        }
    }

    @MainActor
    private func setupScripting() {
        guard !isSetUp else { return }
        isSetUp = true

        // Set up registry
        registry.setApplication(application)
        registry.registerClass(ScriptableApplication.self)
        registry.registerClass(TextDocument.self)
        registry.registerClass(TextParagraph.self)
        registry.registerClass(TextWord.self)
        registry.registerFactory(for: .classDocument) {
            TextDocument()
        }
        registry.registerFactory(for: TextParagraph.classCode) {
            TextParagraph(text: "")
        }

        // Populate with sample data
        let doc1 = TextDocument(name: "Welcome", bodyText: "Hello World!\nThis is a sample document.\nIt has three paragraphs.")
        doc1.syncParagraphsFromBody()
        application.documents = [doc1]

        // Install Apple Event handlers (macOS only)
        #if canImport(Carbon)
        let pipeline = MutationPipeline(registry: registry)
        let interface = AppleEventInterface(registry: registry, pipeline: pipeline)
        interface.install()
        aeInterface = interface
        #endif
    }
}
