import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - @Scriptable Macro

/// The `@Scriptable` macro transforms a class into a scriptable object by:
/// 1. Adding `@Observable` macro behavior (observation tracking)
/// 2. Generating `ScriptableObject` protocol conformance
/// 3. Adding `@MainActor` isolation
///
/// The macro inspects `@ScriptableProperty` and `@ScriptableElement` annotations
/// on stored properties to generate the protocol requirements.
public struct ScriptableMacro: MemberMacro, ExtensionMacro {

    // Fully-qualified name to avoid ambiguity with Carbon's FourCharCode typedef on macOS
    private static let fcc = "SwiftScripting.FourCharCode"

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.requiresClass
        }

        let className = classDecl.name.trimmedDescription

        // Extract name and code from the macro arguments
        let (sdefName, classCodeExpr) = extractNameAndCode(from: node, className: className)

        // Collect property and element metadata
        var propertyEntries: [PropertyEntry] = []
        var elementEntries: [ElementEntry] = []

        for member in classDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }

            if let entry = extractScriptableProperty(from: varDecl) {
                propertyEntries.append(entry)
            }
            if let entry = extractScriptableElement(from: varDecl) {
                elementEntries.append(entry)
            }
        }

        var members: [DeclSyntax] = []

        // Generate scriptableID (must be nonisolated to satisfy protocol requirement)
        members.append("""
        public nonisolated let scriptableID: String = SwiftScripting._makeScriptableID()
        """)

        // Generate scriptableName (uses first string property named "name" if available)
        let nameProperty = propertyEntries.first { $0.variableName == "name" }
        if nameProperty != nil {
            members.append("""
            public var scriptableName: String? { self.name }
            """)
        } else {
            members.append("""
            public var scriptableName: String? { nil }
            """)
        }

        // Generate scriptingClassDescription
        // Always include pID as a read-only property (ScriptableObject requires Identifiable)
        var allPropDescriptions = [
            "ScriptingPropertyDescription(name: \"id\", code: .propertyID, type: String.scriptingType, isReadOnly: true)"
        ]
        allPropDescriptions += propertyEntries.map { entry in
            "ScriptingPropertyDescription(name: \"\(entry.scriptingName)\", code: \(entry.codeExpr), type: \(entry.typeName).scriptingType, isReadOnly: \(entry.isReadOnly))"
        }
        let propDescriptions = allPropDescriptions.joined(separator: ",\n                ")

        let elemDescriptions = elementEntries.map { entry in
            "ScriptingElementDescription(type: \(entry.elementTypeName).self)"
        }.joined(separator: ",\n                ")

        members.append("""
        public static var scriptingClassDescription: ScriptingClassDescription {
            ScriptingClassDescription(
                name: "\(raw: sdefName)",
                code: \(raw: classCodeExpr),
                properties: [
                    \(raw: propDescriptions)
                ],
                elements: [
                    \(raw: elemDescriptions)
                ]
            )
        }
        """)

        // Generate scriptableValue(forProperty:)
        let getPropertyCases = propertyEntries.map { entry in
            "case \(entry.codeExpr): return self.\(entry.variableName) as any ScriptableValue"
        }.joined(separator: "\n            ")

        if propertyEntries.isEmpty {
            members.append("""
            public func scriptableValue(forProperty code: \(raw: fcc)) -> any ScriptableValue {
                return "" as any ScriptableValue
            }
            """)
        } else {
            members.append("""
            public func scriptableValue(forProperty code: \(raw: fcc)) -> any ScriptableValue {
                switch code {
                \(raw: getPropertyCases)
                default:
                    return "" as any ScriptableValue
                }
            }
            """)
        }

        // Generate setScriptableValue(_:forProperty:)
        let writableEntries = propertyEntries.filter { !$0.isReadOnly }
        let setPropertyCases = writableEntries.map { entry in
            "case \(entry.codeExpr): self.\(entry.variableName) = value as! \(entry.typeName)"
        }.joined(separator: "\n            ")

        if writableEntries.isEmpty {
            members.append("""
            public func setScriptableValue(_ value: any ScriptableValue, forProperty code: \(raw: fcc)) throws {
                throw ScriptingError.propertyNotFound(code)
            }
            """)
        } else {
            members.append("""
            public func setScriptableValue(_ value: any ScriptableValue, forProperty code: \(raw: fcc)) throws {
                switch code {
                \(raw: setPropertyCases)
                default:
                    throw ScriptingError.propertyNotFound(code)
                }
            }
            """)
        }

        // Generate scriptableElements(forCode:)
        let getElementCases = elementEntries.map { entry in
            "case \(entry.elementTypeName).scriptingClassDescription.code: return self.\(entry.variableName).map { $0 as any ScriptableObject }"
        }.joined(separator: "\n            ")

        if elementEntries.isEmpty {
            members.append("""
            public func scriptableElements(forCode code: \(raw: fcc)) -> [any ScriptableObject] {
                return []
            }
            """)
        } else {
            members.append("""
            public func scriptableElements(forCode code: \(raw: fcc)) -> [any ScriptableObject] {
                switch code {
                \(raw: getElementCases)
                default:
                    return []
                }
            }
            """)
        }

        // Generate insertScriptableElement
        let insertElementCases = elementEntries.map { entry in
            """
            case \(entry.elementTypeName).scriptingClassDescription.code:
                        guard let typed = object as? \(entry.elementTypeName) else {
                            throw ScriptingError.typeMismatch(expected: \(entry.elementTypeName).self)
                        }
                        self.\(entry.variableName).insert(typed, at: index)
            """
        }.joined(separator: "\n            ")

        if elementEntries.isEmpty {
            members.append("""
            public func insertScriptableElement(_ object: any ScriptableObject, forCode code: \(raw: fcc), at index: Int) throws {
                throw ScriptingError.elementNotFound(code)
            }
            """)
        } else {
            members.append("""
            public func insertScriptableElement(_ object: any ScriptableObject, forCode code: \(raw: fcc), at index: Int) throws {
                switch code {
                \(raw: insertElementCases)
                default:
                    throw ScriptingError.elementNotFound(code)
                }
            }
            """)
        }

        // Generate removeScriptableElement
        let removeElementCases = elementEntries.map { entry in
            "case \(entry.elementTypeName).scriptingClassDescription.code: self.\(entry.variableName).remove(at: index)"
        }.joined(separator: "\n            ")

        if elementEntries.isEmpty {
            members.append("""
            public func removeScriptableElement(at index: Int, forCode code: \(raw: fcc)) throws {
                throw ScriptingError.elementNotFound(code)
            }
            """)
        } else {
            members.append("""
            public func removeScriptableElement(at index: Int, forCode code: \(raw: fcc)) throws {
                switch code {
                \(raw: removeElementCases)
                default:
                    throw ScriptingError.elementNotFound(code)
                }
            }
            """)
        }

        // Generate Observation tracking storage (public to satisfy _ScriptableObservable protocol)
        members.append("""
        @ObservationIgnored public let _$observationRegistrar = Observation.ObservationRegistrar()
        """)

        return members
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let ext: DeclSyntax = """
        extension \(type.trimmed): Observable, SwiftScripting._ScriptableObservable {}
        """
        guard let extDecl = ext.as(ExtensionDeclSyntax.self) else { return [] }
        return [extDecl]
    }

    // MARK: - Helpers

    private struct PropertyEntry {
        let variableName: String
        let scriptingName: String
        let codeExpr: String  // Full expression to emit in generated code
        let typeName: String
        let isReadOnly: Bool
    }

    private struct ElementEntry {
        let variableName: String
        let elementTypeName: String
    }

    private static func extractNameAndCode(from node: AttributeSyntax, className: String) -> (name: String, codeExpr: String) {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return (className, "\(fcc)(\"\(fourCharCodeFromName(className))\")")
        }

        // First unlabeled argument is the SDEF name
        let sdefName = arguments.first(where: { $0.label == nil }).flatMap { arg in
            arg.expression.as(StringLiteralExprSyntax.self)?.segments.description
        } ?? className

        // Labeled "code" argument is the four-char code
        let codeExpr: String
        if let codeArg = arguments.first(where: { $0.label?.text == "code" }) {
            codeExpr = codeExpression(from: codeArg.expression)
        } else {
            codeExpr = "\(fcc)(\"\(fourCharCodeFromName(className))\")"
        }

        return (sdefName, codeExpr)
    }

    private static func fourCharCodeFromName(_ name: String) -> String {
        let padded = name.prefix(4).padding(toLength: 4, withPad: " ", startingAt: 0)
        return padded
    }

    /// Convert a code argument expression to a fully-qualified expression string for code generation.
    /// String literals like `"pnam"` become `SwiftScripting.FourCharCode("pnam")`.
    /// Member access like `.propertyName` becomes `SwiftScripting.FourCharCode.propertyName`.
    /// Other expressions (e.g. `FourCharCode("pnam")`) are emitted as-is.
    private static func codeExpression(from expr: ExprSyntax) -> String {
        if let stringLiteral = expr.as(StringLiteralExprSyntax.self) {
            return "\(fcc)(\"\(stringLiteral.segments.description)\")"
        }
        let text = expr.trimmedDescription
        if text.hasPrefix(".") {
            return "\(fcc)\(text)"
        }
        return text
    }

    private static func extractScriptableProperty(from varDecl: VariableDeclSyntax) -> PropertyEntry? {
        for attribute in varDecl.attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                  attr.attributeName.trimmedDescription == "ScriptableProperty",
                  let arguments = attr.arguments?.as(LabeledExprListSyntax.self) else {
                continue
            }

            let scriptingName = arguments.first.flatMap { arg in
                arg.expression.as(StringLiteralExprSyntax.self)?.segments.description
            } ?? ""

            let codeExpr: String
            if let codeArg = arguments.first(where: { $0.label?.text == "code" }) {
                codeExpr = codeExpression(from: codeArg.expression)
            } else {
                codeExpr = "\(fcc)(\"\")"
            }

            let isReadOnly = arguments.first(where: { $0.label?.text == "readOnly" }).flatMap { arg in
                arg.expression.as(BooleanLiteralExprSyntax.self)?.literal.text == "true"
            } ?? false

            guard let binding = varDecl.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }

            let variableName = pattern.identifier.text
            let typeName = binding.typeAnnotation?.type.trimmedDescription ?? "String"

            return PropertyEntry(
                variableName: variableName,
                scriptingName: scriptingName,
                codeExpr: codeExpr,
                typeName: typeName,
                isReadOnly: isReadOnly
            )
        }
        return nil
    }

    private static func extractScriptableElement(from varDecl: VariableDeclSyntax) -> ElementEntry? {
        for attribute in varDecl.attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                  attr.attributeName.trimmedDescription == "ScriptableElement" else {
                continue
            }

            guard let binding = varDecl.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }

            let variableName = pattern.identifier.text

            // Extract element type from [Type] annotation
            let typeName = binding.typeAnnotation?.type.trimmedDescription ?? "[Any]"
            let elementTypeName: String
            if typeName.hasPrefix("[") && typeName.hasSuffix("]") {
                elementTypeName = String(typeName.dropFirst().dropLast())
            } else {
                elementTypeName = typeName
            }

            return ElementEntry(
                variableName: variableName,
                elementTypeName: elementTypeName
            )
        }
        return nil
    }
}

// MARK: - Errors

enum MacroError: Error, CustomStringConvertible {
    case requiresClass

    var description: String {
        switch self {
        case .requiresClass:
            return "@Scriptable can only be applied to classes"
        }
    }
}
