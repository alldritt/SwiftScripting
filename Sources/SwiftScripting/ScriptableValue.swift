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

// MARK: - Unique ID Generation

/// Generates a unique identifier string for scriptable objects.
/// Used by the `@Scriptable` macro to initialize `scriptableID`.
public nonisolated func _makeScriptableID() -> String {
    UUID().uuidString
}

// MARK: - Missing Value

/// Sentinel representing AppleScript's `missing value`.
///
/// Return this from `scriptableValue(forProperty:)` when a property has no value
/// (e.g. an optional that is nil). It packs as `typeType(cMissingValue)`.
public struct ScriptingMissingValue: ScriptableValue, Sendable {
    public static var scriptingType: ScriptingType { .any }
    public init() {}
}

// MARK: - Enumeration Value

/// Wraps a `FourCharCode` to return as an AppleScript enumeration value.
///
/// Return this from property getters for enumerated properties so they
/// pack as `typeEnumerated` descriptors rather than strings:
/// ```swift
/// getter: {
///     let node = $0 as! ScriptableNode
///     return ScriptingEnumValue(FourCharCode("ACns"))  // "source node" enum
/// }
/// ```
public struct ScriptingEnumValue: ScriptableValue, Sendable {
    public static var scriptingType: ScriptingType { .any }
    public let code: FourCharCode

    public init(_ code: FourCharCode) {
        self.code = code
    }
}

// MARK: - Object Reference with Container

/// Wraps a `ScriptableObject` with its container for proper object specifier chaining.
///
/// Return this from property getters to include the full object path:
/// ```swift
/// getter: {
///     let conn = $0 as! ScriptableConnection
///     guard let doc = conn.document, let nodeID = conn.resolvedConnection?.sourceNodeID else {
///         return ScriptingMissingValue()
///     }
///     let node = ScriptableNode(document: doc, entityID: nodeID)
///     let docWrapper = ScriptableCanvasDocument(document: doc)
///     return ScriptingObjectReference(object: node, container: docWrapper)
/// }
/// ```
/// This produces `node "Foo" of document "Bar"` instead of just `node "Foo"`.
///
/// For deeper nesting (e.g., `port of node of document`), nest containers:
/// ```swift
/// let docWrapper = ScriptableCanvasDocument(document: doc)
/// let nodeRef = ScriptingObjectReference(object: nodeWrapper, container: docWrapper)
/// return ScriptingObjectReference(object: port, container: nodeRef)
/// ```
public struct ScriptingObjectReference: ScriptableValue, @unchecked Sendable {
    public static var scriptingType: ScriptingType { .objectSpecifier("") }

    public let object: any ScriptableObject
    /// The container can be a ScriptableObject directly or another ScriptingObjectReference for nesting.
    public let container: (any ScriptableValue)?

    public init(object: any ScriptableObject, container: (any ScriptableValue)? = nil) {
        self.object = object
        self.container = container
    }
}
