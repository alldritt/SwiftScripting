/// Property wrapper that marks a collection property as a scriptable element container.
///
/// Usage:
/// ```swift
/// @Scriptable("document", code: "docu")
/// class Document {
///     @ScriptableElement
///     var paragraphs: [Paragraph] = []
/// }
/// ```
///
/// The element's SDEF name and four-char code are derived automatically from
/// the element type's `scriptingClassDescription` by the `@Scriptable` macro.
@propertyWrapper
public struct ScriptableElement<Element: ScriptableObject>: Sendable where Element: Sendable {
    private var _elements: [Element]

    public var wrappedValue: [Element] {
        get { _elements }
        set { _elements = newValue }
    }

    public static subscript<EnclosingSelf: _ScriptableObservable>(
        _enclosingInstance observed: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, [Element]>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
    ) -> [Element] {
        get {
            observed._$observationRegistrar.access(observed, keyPath: wrappedKeyPath)
            return observed[keyPath: storageKeyPath]._elements
        }
        set {
            observed._$observationRegistrar.withMutation(of: observed, keyPath: wrappedKeyPath) {
                observed[keyPath: storageKeyPath]._elements = newValue
            }
        }
    }

    public init(wrappedValue: [Element]) {
        self._elements = wrappedValue
    }
}
