# SwiftScripting

A Swift framework for making SwiftUI apps scriptable. Declare your object model with macros, and the framework handles Apple Event dispatch and App Intents bridging.

## What It Does

SwiftScripting provides three libraries:

- **SwiftScripting** — Core object model with the `@Scriptable` macro, property/element wrappers, object resolution, and mutation pipeline.
- **SwiftScriptingAppleEvents** — Apple Event handler installation, `NSAppleEventDescriptor` packing/unpacking, and object specifier parsing. macOS only.
- **SwiftScriptingIntents** — App Intents bridge types for exposing your scriptable objects through Shortcuts and Siri.

## The `@Scriptable` Macro

Mark a class with `@Scriptable` to generate `ScriptableObject` conformance, a unique ID, and a `ScriptingClassDescription` with closure-based dispatch:

```swift
@Scriptable("todo list", code: "tdls")
@MainActor
final class TodoList: ScriptableObject, @unchecked Sendable {
    @ScriptableProperty("name", code: .propertyName)
    var name: String = "Untitled"

    @ScriptableElement
    var items: [TodoItem] = []
}
```

`@ScriptableProperty` declares a property visible to scripting. `@ScriptableElement` declares a contained element collection. The macro generates the `scriptingClassDescription` with getter/setter closures, so the default `ScriptableObject` protocol extensions handle get, set, insert, and remove without any manual switch statements.

## Setting Up Scripting

Register your classes with a `ScriptableObjectRegistry` and install the event handlers:

```swift
let registry = ScriptableObjectRegistry()
registry.setApplication(myApp)
registry.registerClass(TodoList.self)
registry.registerClass(TodoItem.self)
registry.registerFactory(for: TodoList.self) { TodoList() }
registry.registerFactory(for: TodoItem.self) { TodoItem() }

// Apple Events (macOS)
let pipeline = MutationPipeline(registry: registry)
let interface = AppleEventInterface(registry: registry, pipeline: pipeline)
interface.install()
```

All mutations go through `MutationPipeline`, which centralizes make/delete/set operations in one place.

## Custom Application Roots

For apps that don't follow the standard document model, write a custom application root conforming to `ScriptableObject` directly. Use closure-based `ScriptingPropertyDescription` and `ScriptingElementDescription` for full control:

```swift
@Observable
@MainActor
final class TodoApplication: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "application",
            code: .classApplication,
            properties: [
                ScriptingPropertyDescription(
                    name: "name", code: .propertyName, type: .text, isReadOnly: true,
                    getter: { ($0 as! TodoApplication).scriptableName },
                    setter: nil
                ),
            ],
            elements: [
                ScriptingElementDescription(
                    type: TodoList.self,
                    getter: { ($0 as! TodoApplication).todoLists.map { $0 } },
                    inserter: { /* ... */ },
                    remover: { /* ... */ }
                ),
            ]
        )
    }

    nonisolated let scriptableID = "application"
    var scriptableName: String? { "MyApp" }
    var todoLists: [TodoList] = []
}
```

For standard document-based apps, use the built-in `ScriptableApplication` and `ScriptableDocument` types instead.

## App Intents Integration

The `SwiftScriptingIntents` library provides bridge types for connecting your scriptable objects to Shortcuts:

- `MakeElementBridge` — Creates scriptable objects through the mutation pipeline.
- `DeleteElementBridge` — Deletes scriptable objects by ID.
- `GetPropertyBridge` / `SetPropertyBridge` — Read and write properties by code.
- `ScriptableEntity` — A generic `AppEntity` for use in intent parameters.

For Shortcuts to discover your app's intents, define app-specific `AppEntity` types with real queries backed by your object model. The ScriptableTodos example demonstrates this pattern.

## Example Apps

### ScriptableTodos

A non-document-based app with custom element types (todo lists containing todo items). Demonstrates:

- Custom application root with closure-based dispatch
- `@Scriptable` macro on model classes
- Apple Event handling (get, set, make, delete, count, exists)
- App Intents with five concrete intents and an `AppShortcutsProvider`
- An AppleScript test suite (`TestScriptableTodos.applescript`)

### ScriptableTextEditor

A document-based text editor using the built-in `ScriptableApplication` and `ScriptableDocument` types. Demonstrates:

- Standard document model with paragraphs and words as nested elements
- `@Scriptable` macro on document and text element classes
- Apple Event handling for the document hierarchy

## Requirements

- Swift 6.0+
- macOS 15+ / iOS 18+
- swift-syntax 600.0.0+

## Package Structure

```
Sources/
  SwiftScripting/           Core framework, macros, object model
  SwiftScriptingMacros/     Compiler plugin (@Scriptable macro implementation)
  SwiftScriptingMacrosClient/  Macro declarations re-exported by SwiftScripting
  SwiftScriptingAppleEvents/   Apple Event interface (macOS)
  SwiftScriptingIntents/       App Intents bridge
Examples/
  ScriptableTodos/          Non-document app with App Intents
  ScriptableTextEditor/     Document-based app
Tests/
  SwiftScriptingTests/            Core + macro tests
  SwiftScriptingAppleEventsTests/ Apple Event packing/parsing tests
  SwiftScriptingIntentsTests/     Intent bridge tests
```

## Building

```bash
swift build
swift test
```

The example apps have Xcode projects generated with [xcodegen](https://github.com/yonaskolb/XcodeGen). To regenerate after changing `project.yml`:

```bash
cd Examples/ScriptableTodos && xcodegen generate
cd Examples/ScriptableTextEditor && xcodegen generate
```

## License

MIT License. See [LICENSE](LICENSE) for details.
