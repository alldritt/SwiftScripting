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

        // Extract the four-char code from the macro argument if provided
        let classCode = extractClassCode(from: node) ?? fourCharCodeFromName(className)

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

        // Generate scriptableID
        members.append("""
        public var scriptableID: String { ObjectIdentifier(self).debugDescription }
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
        let propDescriptions = propertyEntries.map { entry in
            "ScriptingPropertyDescription(name: \"\(entry.scriptingName)\", code: FourCharCode(\"\(entry.code)\"), type: \(entry.typeName).scriptingType, isReadOnly: \(entry.isReadOnly))"
        }.joined(separator: ",\n                ")

        let elemDescriptions = elementEntries.map { entry in
            "ScriptingElementDescription(name: \"\(entry.scriptingName)\", code: FourCharCode(\"\(entry.code)\"), objectType: \"\(entry.elementTypeName)\")"
        }.joined(separator: ",\n                ")

        members.append("""
        public static var scriptingClassDescription: ScriptingClassDescription {
            ScriptingClassDescription(
                name: "\(raw: className)",
                code: FourCharCode("\(raw: classCode)"),
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
        var getPropertyCases = propertyEntries.map { entry in
            "case FourCharCode(\"\(entry.code)\"): return self.\(entry.variableName) as any ScriptableValue"
        }.joined(separator: "\n            ")
        if getPropertyCases.isEmpty {
            getPropertyCases = "break"
        }

        members.append("""
        public func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
            switch code {
            \(raw: getPropertyCases)
            default:
                return "" as any ScriptableValue
            }
        }
        """)

        // Generate setScriptableValue(_:forProperty:)
        var setPropertyCases = propertyEntries.filter { !$0.isReadOnly }.map { entry in
            "case FourCharCode(\"\(entry.code)\"): self.\(entry.variableName) = value as! \(entry.typeName)"
        }.joined(separator: "\n            ")
        if setPropertyCases.isEmpty {
            setPropertyCases = "break"
        }

        members.append("""
        public func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {
            switch code {
            \(raw: setPropertyCases)
            default:
                throw ScriptingError.propertyNotFound(code)
            }
        }
        """)

        // Generate scriptableElements(forCode:)
        var getElementCases = elementEntries.map { entry in
            "case FourCharCode(\"\(entry.code)\"): return self.\(entry.variableName).map { $0 as any ScriptableObject }"
        }.joined(separator: "\n            ")
        if getElementCases.isEmpty {
            getElementCases = "break"
        }

        members.append("""
        public func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] {
            switch code {
            \(raw: getElementCases)
            default:
                return []
            }
        }
        """)

        // Generate insertScriptableElement
        var insertElementCases = elementEntries.map { entry in
            """
            case FourCharCode("\(entry.code)"):
                        guard let typed = object as? \(entry.elementTypeName) else {
                            throw ScriptingError.typeMismatch(expected: "\(entry.elementTypeName)")
                        }
                        self.\(entry.variableName).insert(typed, at: index)
            """
        }.joined(separator: "\n            ")
        if insertElementCases.isEmpty {
            insertElementCases = "break"
        }

        members.append("""
        public func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
            switch code {
            \(raw: insertElementCases)
            default:
                throw ScriptingError.elementNotFound(code)
            }
        }
        """)

        // Generate removeScriptableElement
        var removeElementCases = elementEntries.map { entry in
            "case FourCharCode(\"\(entry.code)\"): self.\(entry.variableName).remove(at: index)"
        }.joined(separator: "\n            ")
        if removeElementCases.isEmpty {
            removeElementCases = "break"
        }

        members.append("""
        public func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
            switch code {
            \(raw: removeElementCases)
            default:
                throw ScriptingError.elementNotFound(code)
            }
        }
        """)

        // Generate Observation tracking storage
        members.append("""
        @ObservationIgnored private let _$observationRegistrar = Observation.ObservationRegistrar()
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
        extension \(type.trimmed): Observable {}
        """
        guard let extDecl = ext.as(ExtensionDeclSyntax.self) else { return [] }
        return [extDecl]
    }

    // MARK: - Helpers

    private struct PropertyEntry {
        let variableName: String
        let scriptingName: String
        let code: String
        let typeName: String
        let isReadOnly: Bool
    }

    private struct ElementEntry {
        let variableName: String
        let scriptingName: String
        let code: String
        let elementTypeName: String
    }

    private static func extractClassCode(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let first = arguments.first,
              let stringLit = first.expression.as(StringLiteralExprSyntax.self) else {
            return nil
        }
        return stringLit.segments.description
    }

    private static func fourCharCodeFromName(_ name: String) -> String {
        let padded = name.prefix(4).padding(toLength: 4, withPad: " ", startingAt: 0)
        return padded
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

            let code = arguments.first(where: { $0.label?.text == "code" }).flatMap { arg in
                arg.expression.as(StringLiteralExprSyntax.self)?.segments.description
            } ?? ""

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
                code: code,
                typeName: typeName,
                isReadOnly: isReadOnly
            )
        }
        return nil
    }

    private static func extractScriptableElement(from varDecl: VariableDeclSyntax) -> ElementEntry? {
        for attribute in varDecl.attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                  attr.attributeName.trimmedDescription == "ScriptableElement",
                  let arguments = attr.arguments?.as(LabeledExprListSyntax.self) else {
                continue
            }

            let scriptingName = arguments.first.flatMap { arg in
                arg.expression.as(StringLiteralExprSyntax.self)?.segments.description
            } ?? ""

            let code = arguments.first(where: { $0.label?.text == "code" }).flatMap { arg in
                arg.expression.as(StringLiteralExprSyntax.self)?.segments.description
            } ?? ""

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
                scriptingName: scriptingName,
                code: code,
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
