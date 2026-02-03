import Foundation

/// A type that can be used as a scriptable property value.
///
/// Provides a bridge between Swift types and Apple Event descriptor types.
/// All types used in `@ScriptableProperty` must conform to this protocol.
public protocol ScriptableValue: Sendable {
    /// The scripting type descriptor for this value type.
    static var scriptingType: ScriptingType { get }
}

// MARK: - Core Scalar Conformances

extension String: ScriptableValue {
    public static var scriptingType: ScriptingType { .text }
}

extension Int: ScriptableValue {
    public static var scriptingType: ScriptingType { .integer }
}

extension Double: ScriptableValue {
    public static var scriptingType: ScriptingType { .real }
}

extension Bool: ScriptableValue {
    public static var scriptingType: ScriptingType { .boolean }
}

extension Date: ScriptableValue {
    public static var scriptingType: ScriptingType { .date }
}

extension Data: ScriptableValue {
    public static var scriptingType: ScriptingType { .data }
}

extension URL: ScriptableValue {
    public static var scriptingType: ScriptingType { .fileURL }
}

// MARK: - Collection Conformance

extension Array: ScriptableValue where Element: ScriptableValue {
    public static var scriptingType: ScriptingType { .list(Element.scriptingType) }
}

// MARK: - Optional Conformance

extension Optional: ScriptableValue where Wrapped: ScriptableValue {
    public static var scriptingType: ScriptingType { .optional(Wrapped.scriptingType) }
}
