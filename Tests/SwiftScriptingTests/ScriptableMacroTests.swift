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
                            ScriptingPropertyDescription(name: "id", code: .propertyID, type: String.scriptingType, isReadOnly: true),
                            ScriptingPropertyDescription(name: "name", code: SwiftScripting.FourCharCode("pnam"), type: String.scriptingType, isReadOnly: false)
                        ],
                        elements: [
                            \n                ]
                    )
                }

                public func scriptableValue(forProperty code: SwiftScripting.FourCharCode) -> any ScriptableValue {
                    switch code {
                    case SwiftScripting.FourCharCode("pnam"): return self.name as any ScriptableValue
                    default:
                        return "" as any ScriptableValue
                    }
                }

                public func setScriptableValue(_ value: any ScriptableValue, forProperty code: SwiftScripting.FourCharCode) throws {
                    switch code {
                    case SwiftScripting.FourCharCode("pnam"): self.name = value as! String
                    default:
                        throw ScriptingError.propertyNotFound(code)
                    }
                }

                public func scriptableElements(forCode code: SwiftScripting.FourCharCode) -> [any ScriptableObject] {
                    switch code {
                    break
                    default:
                        return []
                    }
                }

                public func insertScriptableElement(_ object: any ScriptableObject, forCode code: SwiftScripting.FourCharCode, at index: Int) throws {
                    switch code {
                    break
                    default:
                        throw ScriptingError.elementNotFound(code)
                    }
                }

                public func removeScriptableElement(at index: Int, forCode code: SwiftScripting.FourCharCode) throws {
                    switch code {
                    break
                    default:
                        throw ScriptingError.elementNotFound(code)
                    }
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
                            ScriptingPropertyDescription(name: "id", code: .propertyID, type: String.scriptingType, isReadOnly: true),
                            ScriptingPropertyDescription(name: "name", code: SwiftScripting.FourCharCode("pnam"), type: String.scriptingType, isReadOnly: false)
                        ],
                        elements: [
                            ScriptingElementDescription(type: TodoItem.self)
                        ]
                    )
                }

                public func scriptableValue(forProperty code: SwiftScripting.FourCharCode) -> any ScriptableValue {
                    switch code {
                    case SwiftScripting.FourCharCode("pnam"): return self.name as any ScriptableValue
                    default:
                        return "" as any ScriptableValue
                    }
                }

                public func setScriptableValue(_ value: any ScriptableValue, forProperty code: SwiftScripting.FourCharCode) throws {
                    switch code {
                    case SwiftScripting.FourCharCode("pnam"): self.name = value as! String
                    default:
                        throw ScriptingError.propertyNotFound(code)
                    }
                }

                public func scriptableElements(forCode code: SwiftScripting.FourCharCode) -> [any ScriptableObject] {
                    switch code {
                    case TodoItem.scriptingClassDescription.code: return self.items.map { $0 as any ScriptableObject }
                    default:
                        return []
                    }
                }

                public func insertScriptableElement(_ object: any ScriptableObject, forCode code: SwiftScripting.FourCharCode, at index: Int) throws {
                    switch code {
                    case TodoItem.scriptingClassDescription.code:
                        guard let typed = object as? TodoItem else {
                            throw ScriptingError.typeMismatch(expected: TodoItem.self)
                        }
                        self.items.insert(typed, at: index)
                    default:
                        throw ScriptingError.elementNotFound(code)
                    }
                }

                public func removeScriptableElement(at index: Int, forCode code: SwiftScripting.FourCharCode) throws {
                    switch code {
                    case TodoItem.scriptingClassDescription.code: self.items.remove(at: index)
                    default:
                        throw ScriptingError.elementNotFound(code)
                    }
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
                            ScriptingPropertyDescription(name: "id", code: .propertyID, type: String.scriptingType, isReadOnly: true)
                        ],
                        elements: [
                            \n                ]
                    )
                }

                public func scriptableValue(forProperty code: SwiftScripting.FourCharCode) -> any ScriptableValue {
                    return "" as any ScriptableValue
                }

                public func setScriptableValue(_ value: any ScriptableValue, forProperty code: SwiftScripting.FourCharCode) throws {
                    throw ScriptingError.propertyNotFound(code)
                }

                public func scriptableElements(forCode code: SwiftScripting.FourCharCode) -> [any ScriptableObject] {
                    return []
                }

                public func insertScriptableElement(_ object: any ScriptableObject, forCode code: SwiftScripting.FourCharCode, at index: Int) throws {
                    throw ScriptingError.elementNotFound(code)
                }

                public func removeScriptableElement(at index: Int, forCode code: SwiftScripting.FourCharCode) throws {
                    throw ScriptingError.elementNotFound(code)
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
                            ScriptingPropertyDescription(name: "id", code: .propertyID, type: String.scriptingType, isReadOnly: true)
                        ],
                        elements: [
                            \n                ]
                    )
                }

                public func scriptableValue(forProperty code: SwiftScripting.FourCharCode) -> any ScriptableValue {
                    return "" as any ScriptableValue
                }

                public func setScriptableValue(_ value: any ScriptableValue, forProperty code: SwiftScripting.FourCharCode) throws {
                    throw ScriptingError.propertyNotFound(code)
                }

                public func scriptableElements(forCode code: SwiftScripting.FourCharCode) -> [any ScriptableObject] {
                    return []
                }

                public func insertScriptableElement(_ object: any ScriptableObject, forCode code: SwiftScripting.FourCharCode, at index: Int) throws {
                    throw ScriptingError.elementNotFound(code)
                }

                public func removeScriptableElement(at index: Int, forCode code: SwiftScripting.FourCharCode) throws {
                    throw ScriptingError.elementNotFound(code)
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
