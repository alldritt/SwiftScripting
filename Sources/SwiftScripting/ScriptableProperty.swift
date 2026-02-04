import Observation

/// Property wrapper that marks a stored property as scriptable.
///
/// Usage:
/// ```swift
/// @Scriptable
/// class Document {
///     @ScriptableProperty("name", code: "pnam")
///     var name: String = "Untitled"
///
///     @ScriptableProperty("word count", code: "wCnt", readOnly: true)
///     var wordCount: Int = 0
/// }
/// ```
///
/// The first argument is the AppleScript-visible name. The `code` parameter
/// is the four-character code used in Apple Event descriptors.
@propertyWrapper
public struct ScriptableProperty<Value: ScriptableValue>: Sendable where Value: Sendable {
    /// The AppleScript-visible name for this property.
    public let scriptingName: String

    /// The four-character code for this property.
    public let code: String

    /// Whether this property is read-only to scripting.
    public let isReadOnly: Bool

    private var _value: Value

    public var wrappedValue: Value {
        get { _value }
        set { _value = newValue }
    }

    public static subscript<EnclosingSelf: _ScriptableObservable>(
        _enclosingInstance observed: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
    ) -> Value {
        get {
            observed._$observationRegistrar.access(observed, keyPath: wrappedKeyPath)
            return observed[keyPath: storageKeyPath]._value
        }
        set {
            observed._$observationRegistrar.withMutation(of: observed, keyPath: wrappedKeyPath) {
                observed[keyPath: storageKeyPath]._value = newValue
            }
        }
    }

    public init(wrappedValue: Value, _ scriptingName: String, code: String, readOnly: Bool = false) {
        self._value = wrappedValue
        self.scriptingName = scriptingName
        self.code = code
        self.isReadOnly = readOnly
    }
}
