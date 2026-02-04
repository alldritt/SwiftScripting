import SwiftUI
import SwiftScripting
import SwiftScriptingIntents
#if canImport(SwiftScriptingAppleEvents)
import SwiftScriptingAppleEvents
#endif

@main
struct ScriptableTodosApp: App {
    @State private var todoApp = TodoApplication()
    @State private var registry = ScriptableObjectRegistry()
    @State private var isSetUp = false
    #if canImport(Carbon)
    @State private var aeInterface: AppleEventInterface?
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView(app: todoApp)
                .onAppear { setupScripting() }
        }
    }

    @MainActor
    private func setupScripting() {
        guard !isSetUp else { return }
        isSetUp = true

        // Populate with sample data
        let shopping = TodoList(name: "Shopping", items: [
            TodoItem(name: "Milk", priority: 1),
            TodoItem(name: "Bread", priority: 2),
            TodoItem(name: "Eggs"),
        ])
        let work = TodoList(name: "Work", items: [
            TodoItem(name: "Review PR", priority: 3),
            TodoItem(name: "Write tests", completed: true),
        ])
        todoApp.todoLists = [shopping, work]

        // Set up scripting registry
        registry.setApplication(todoApp)
        registry.registerClass(TodoApplication.self)
        registry.registerClass(TodoList.self)
        registry.registerClass(TodoItem.self)
        registry.registerFactory(for: TodoList.self) {
            TodoList()
        }
        registry.registerFactory(for: TodoItem.self) {
            TodoItem()
        }

        // Wire up App Intents bridge
        SharedRegistry.registry = registry

        // Install Apple Event handlers (macOS only)
        #if canImport(Carbon)
        let pipeline = MutationPipeline(registry: registry)
        let interface = AppleEventInterface(registry: registry, pipeline: pipeline)
        interface.install()
        aeInterface = interface
        #endif
    }
}
