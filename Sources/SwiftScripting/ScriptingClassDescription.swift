/// The scripting type descriptor used by `ScriptableValue` conformances.
public indirect enum ScriptingType: Hashable, Sendable {
    case text
    case integer
    case real
    case boolean
    case date
    case data
    case fileURL
    case list(ScriptingType)
    case optional(ScriptingType)
    case enumerated(String)
    case record
    case objectSpecifier(String)
    case color
    case any

    /// Type-safe factory that derives the class name from a `ScriptableObject` type.
    @MainActor public static func objectSpecifier<T: ScriptableObject>(_ type: T.Type) -> ScriptingType {
        .objectSpecifier(T.scriptingClassDescription.name)
    }

    /// The four-char Apple Event type code for this scripting type.
    public var aeTypeCode: FourCharCode {
        switch self {
        case .text: return "utxt"
        case .integer: return "long"
        case .real: return "doub"
        case .boolean: return "bool"
        case .date: return "ldt "
        case .data: return "tdta"
        case .fileURL: return "furl"
        case .list: return "list"
        case .optional(let inner): return inner.aeTypeCode
        case .enumerated: return "enum"
        case .record: return "reco"
        case .objectSpecifier: return "obj "
        case .color: return "cRGB"
        case .any: return "****"
        }
    }
}

/// Describes a property on a scriptable class.
public struct ScriptingPropertyDescription: Hashable, Sendable {
    /// The human-readable AppleScript name (e.g., "body text").
    public let name: String

    /// The four-char code identifying this property (e.g., `"ctxt"` for body text).
    public let code: FourCharCode

    /// The scripting type of this property.
    public let type: ScriptingType

    /// Whether this property is read-only.
    public let isReadOnly: Bool

    public init(name: String, code: FourCharCode, type: ScriptingType, isReadOnly: Bool = false) {
        self.name = name
        self.code = code
        self.type = type
        self.isReadOnly = isReadOnly
    }
}

/// Describes a contained element collection on a scriptable class.
public struct ScriptingElementDescription: Hashable, Sendable {
    /// The singular AppleScript name (e.g., "paragraph").
    public let name: String

    /// The four-char code identifying this element type (e.g., `"cpar"`).
    public let code: FourCharCode

    /// Derive name and code from the element type's class description.
    @MainActor public init<T: ScriptableObject>(type: T.Type) {
        let desc = T.scriptingClassDescription
        self.name = desc.name
        self.code = desc.code
    }

    /// Manual initializer for non-macro classes (e.g., custom application roots).
    public init(name: String, code: FourCharCode) {
        self.name = name
        self.code = code
    }
}

/// Describes a scriptable class: its name, code, properties, and elements.
public struct ScriptingClassDescription: Hashable, Sendable {
    /// The class name (e.g., "Document").
    public let name: String

    /// The four-char class code (e.g., `"docu"`).
    public let code: FourCharCode

    /// The properties this class exposes to scripting.
    public let properties: [ScriptingPropertyDescription]

    /// The element collections this class contains.
    public let elements: [ScriptingElementDescription]

    /// Optional superclass code (for inheritance).
    public let superclassCode: FourCharCode?

    public init(
        name: String,
        code: FourCharCode,
        properties: [ScriptingPropertyDescription] = [],
        elements: [ScriptingElementDescription] = [],
        superclassCode: FourCharCode? = nil
    ) {
        self.name = name
        self.code = code
        self.properties = properties
        self.elements = elements
        self.superclassCode = superclassCode
    }

    /// Look up a property description by its four-char code.
    public func property(forCode code: FourCharCode) -> ScriptingPropertyDescription? {
        properties.first { $0.code == code }
    }

    /// Look up an element description by its four-char code.
    public func element(forCode code: FourCharCode) -> ScriptingElementDescription? {
        elements.first { $0.code == code }
    }
}
