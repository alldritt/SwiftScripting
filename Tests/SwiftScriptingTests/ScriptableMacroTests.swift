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
            @Scriptable
            class MyDoc {
                @ScriptableProperty("name", code: "pnam")
                var name: String = "Untitled"
            }
            """,
            expandedSource: """
            class MyDoc {
                @ScriptableProperty("name", code: "pnam")
                var name: String = "Untitled"

                public var scriptableID: String { ObjectIdentifier(self).debugDescription }

                public var scriptableName: String? { self.name }

                public static var scriptingClassDescription: ScriptingClassDescription {
                    ScriptingClassDescription(
                        name: "MyDoc",
                        code: FourCharCode("MyDo"),
                        properties: [
                            ScriptingPropertyDescription(name: "name", code: FourCharCode("pnam"), type: String.scriptingType, isReadOnly: false)
                        ],
                        elements: [
                            \n                ]
                    )
                }

                public func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
                    switch code {
                    case FourCharCode("pnam"): return self.name as any ScriptableValue
                    default:
                        return "" as any ScriptableValue
                    }
                }

                public func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {
                    switch code {
                    case FourCharCode("pnam"): self.name = value as! String
                    default:
                        throw ScriptingError.propertyNotFound(code)
                    }
                }

                public func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] {
                    switch code {
                    break
                    default:
                        return []
                    }
                }

                public func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
                    switch code {
                    break
                    default:
                        throw ScriptingError.elementNotFound(code)
                    }
                }

                public func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
                    switch code {
                    break
                    default:
                        throw ScriptingError.elementNotFound(code)
                    }
                }

                @ObservationIgnored private let _$observationRegistrar = Observation.ObservationRegistrar()
            }

            extension MyDoc: ScriptableObject, Observable {
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
