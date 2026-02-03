/// Property wrapper that marks a collection property as a scriptable element container.
///
/// Usage:
/// ```swift
/// @Scriptable
/// class Document {
///     @ScriptableElement("paragraph", code: "cpar")
///     var paragraphs: [Paragraph] = []
/// }
/// ```
///
/// The first argument is the singular AppleScript name. The `code` parameter
/// is the four-character class code for the contained element type.
@propertyWrapper
public struct ScriptableElement<Element: ScriptableObject>: Sendable where Element: Sendable {
    /// The singular AppleScript name for elements in this collection.
    public let scriptingName: String

    /// The four-character class code for the element type.
    public let code: String

    private var _elements: [Element]

    public var wrappedValue: [Element] {
        get { _elements }
        set { _elements = newValue }
    }

    public init(wrappedValue: [Element], _ scriptingName: String, code: String) {
        self._elements = wrappedValue
        self.scriptingName = scriptingName
        self.code = code
    }
}
