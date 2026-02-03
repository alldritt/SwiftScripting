/// Result builder for declaring the scripting suite configuration.
///
/// Usage:
/// ```swift
/// ScriptSuite("MyApp", code: "MyAp") {
///     Document.self
///     Paragraph.self
/// }
/// ```
@resultBuilder
public struct ScriptSuiteBuilder {
    public static func buildBlock(_ components: [any ScriptableObject.Type]...) -> [any ScriptableObject.Type] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: any ScriptableObject.Type) -> [any ScriptableObject.Type] {
        [expression]
    }

    public static func buildOptional(_ component: [any ScriptableObject.Type]?) -> [any ScriptableObject.Type] {
        component ?? []
    }

    public static func buildEither(first component: [any ScriptableObject.Type]) -> [any ScriptableObject.Type] {
        component
    }

    public static func buildEither(second component: [any ScriptableObject.Type]) -> [any ScriptableObject.Type] {
        component
    }
}

/// Configuration for a scripting suite, declaring the app's scriptable classes.
public struct ScriptSuite: Sendable {
    /// The suite name.
    public let name: String

    /// The four-char suite code.
    public let code: FourCharCode

    /// The registered scriptable class types.
    public let classes: [any ScriptableObject.Type]

    public init(
        _ name: String,
        code: String,
        @ScriptSuiteBuilder classes: () -> [any ScriptableObject.Type]
    ) {
        self.name = name
        self.code = FourCharCode(code)
        self.classes = classes()
    }
}
