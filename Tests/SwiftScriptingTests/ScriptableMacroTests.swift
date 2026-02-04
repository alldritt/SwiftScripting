import Testing
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftScriptingMacros

@Suite("@Scriptable Macro Tests")
struct ScriptableMacroTests {

    let macros: [String: Macro.Type] = [
        "Scriptable": ScriptableMacro.self,
    ]

    @Test("Macro generates scriptableID")
    func generatesScriptableID() {
        assertMacroExpansion(
            """
            @Scriptable("my doc", code: "MyDo")
            class MyDoc {
                @ScriptableProperty("name", code: "pnam")
                var name: String = "Untitled"
            }
            """,
            expandedSource: """
            class MyDoc {
                @ScriptableProperty("name", code: "pnam")
                var name: String = "Untitled"

                public nonisolated let scriptableID: String = SwiftScripting._makeScriptableID()

                public var scriptableName: String? { self.name }

                public static var scriptingClassDescription: ScriptingClassDescription {
                    ScriptingClassDescription(
                        name: "my doc",
                        code: SwiftScripting.FourCharCode("MyDo"),
                        properties: [
                            ScriptingPropertyDescription(name: "id", code: .propertyID, type: String.scriptingType, isReadOnly: true, getter: { $0.scriptableID }, setter: nil),
                            ScriptingPropertyDescription(name: "name", code: SwiftScripting.FourCharCode("pnam"), type: String.scriptingType, isReadOnly: false, getter: { ($0 as! MyDoc).name }, setter: { ($0 as! MyDoc).name = $1 as! String })
                        ],
                        elements: [
                            \n                ]
                    )
                }

                @ObservationIgnored public let _$observationRegistrar = Observation.ObservationRegistrar()
            }

            extension MyDoc: Observable, SwiftScripting._ScriptableObservable {
            }
            """,
            macros: macros
        )
    }

    @Test("Macro with elements generates type-based ScriptingElementDescription")
    func generatesElementDescription() {
        assertMacroExpansion(
            """
            @Scriptable("todo list", code: "tdls")
            class TodoList {
                @ScriptableProperty("name", code: "pnam")
                var name: String = "Untitled"

                @ScriptableElement
                var items: [TodoItem] = []
            }
            """,
            expandedSource: """
            class TodoList {
                @ScriptableProperty("name", code: "pnam")
                var name: String = "Untitled"

                @ScriptableElement
                var items: [TodoItem] = []

                public nonisolated let scriptableID: String = SwiftScripting._makeScriptableID()

                public var scriptableName: String? { self.name }

                public static var scriptingClassDescription: ScriptingClassDescription {
                    ScriptingClassDescription(
                        name: "todo list",
                        code: SwiftScripting.FourCharCode("tdls"),
                        properties: [
                            ScriptingPropertyDescription(name: "id", code: .propertyID, type: String.scriptingType, isReadOnly: true, getter: { $0.scriptableID }, setter: nil),
                            ScriptingPropertyDescription(name: "name", code: SwiftScripting.FourCharCode("pnam"), type: String.scriptingType, isReadOnly: false, getter: { ($0 as! TodoList).name }, setter: { ($0 as! TodoList).name = $1 as! String })
                        ],
                        elements: [
                            ScriptingElementDescription(type: TodoItem.self, getter: { ($0 as! TodoList).items.map { $0 as any ScriptableObject } }, inserter: { guard let typed = $1 as? TodoItem else { throw ScriptingError.typeMismatch(expected: TodoItem.self) }; ($0 as! TodoList).items.insert(typed, at: $2) }, remover: { ($0 as! TodoList).items.remove(at: $1) })
                        ]
                    )
                }

                @ObservationIgnored public let _$observationRegistrar = Observation.ObservationRegistrar()
            }

            extension TodoList: Observable, SwiftScripting._ScriptableObservable {
            }
            """,
            macros: macros
        )
    }

    @Test("Macro defaults name to class name and code to first 4 chars")
    func defaultsNameAndCode() {
        assertMacroExpansion(
            """
            @Scriptable
            class MyDoc {
            }
            """,
            expandedSource: """
            class MyDoc {

                public nonisolated let scriptableID: String = SwiftScripting._makeScriptableID()

                public var scriptableName: String? { nil }

                public static var scriptingClassDescription: ScriptingClassDescription {
                    ScriptingClassDescription(
                        name: "MyDoc",
                        code: SwiftScripting.FourCharCode("MyDo"),
                        properties: [
                            ScriptingPropertyDescription(name: "id", code: .propertyID, type: String.scriptingType, isReadOnly: true, getter: { $0.scriptableID }, setter: nil)
                        ],
                        elements: [
                            \n                ]
                    )
                }

                @ObservationIgnored public let _$observationRegistrar = Observation.ObservationRegistrar()
            }

            extension MyDoc: Observable, SwiftScripting._ScriptableObservable {
            }
            """,
            macros: macros
        )
    }

    @Test("Macro with code only defaults name to class name")
    func codeOnlyDefaultsName() {
        assertMacroExpansion(
            """
            @Scriptable(code: "tdim")
            class TodoItem {
            }
            """,
            expandedSource: """
            class TodoItem {

                public nonisolated let scriptableID: String = SwiftScripting._makeScriptableID()

                public var scriptableName: String? { nil }

                public static var scriptingClassDescription: ScriptingClassDescription {
                    ScriptingClassDescription(
                        name: "TodoItem",
                        code: SwiftScripting.FourCharCode("tdim"),
                        properties: [
                            ScriptingPropertyDescription(name: "id", code: .propertyID, type: String.scriptingType, isReadOnly: true, getter: { $0.scriptableID }, setter: nil)
                        ],
                        elements: [
                            \n                ]
                    )
                }

                @ObservationIgnored public let _$observationRegistrar = Observation.ObservationRegistrar()
            }

            extension TodoItem: Observable, SwiftScripting._ScriptableObservable {
            }
            """,
            macros: macros
        )
    }

    @Test("Macro requires class")
    func requiresClass() {
        assertMacroExpansion(
            """
            @Scriptable
            struct NotAClass {
            }
            """,
            expandedSource: """
            struct NotAClass {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Scriptable can only be applied to classes", line: 1, column: 1),
            ],
            macros: macros
        )
    }
}
