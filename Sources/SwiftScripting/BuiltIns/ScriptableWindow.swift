import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Built-in scriptable window object.
///
/// Bridges to the platform's window representation and exposes
/// standard window properties (name, bounds, visible, etc.).
@MainActor
public final class ScriptableWindow: ScriptableObject, @unchecked Sendable {
    public static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "window",
            code: .classWindow,
            properties: [
                ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text, isReadOnly: true),
                ScriptingPropertyDescription(name: "index", code: FourCharCode("pidx"), type: .integer),
                ScriptingPropertyDescription(name: "visible", code: FourCharCode("pvis"), type: .boolean),
                ScriptingPropertyDescription(name: "miniaturized", code: FourCharCode("pmnd"), type: .boolean),
                ScriptingPropertyDescription(name: "zoomed", code: FourCharCode("pzum"), type: .boolean),
            ],
            elements: []
        )
    }

    public nonisolated let scriptableID: String
    public var scriptableName: String? { name }

    public private(set) var name: String
    public var index: Int
    public var visible: Bool
    public var miniaturized: Bool
    public var zoomed: Bool

    /// The associated document, if any.
    public weak var document: (any ScriptableDocument)?

    #if canImport(AppKit)
    /// The backing NSWindow, if available.
    public weak var nsWindow: NSWindow?
    #endif

    public init(name: String, index: Int = 1) {
        self.scriptableID = UUID().uuidString
        self.name = name
        self.index = index
        self.visible = true
        self.miniaturized = false
        self.zoomed = false
    }

    // MARK: - ScriptableObject

    public func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code {
        case .propertyName: return name
        case FourCharCode("pidx"): return index
        case FourCharCode("pvis"): return visible
        case FourCharCode("pmnd"): return miniaturized
        case FourCharCode("pzum"): return zoomed
        default: return "" as any ScriptableValue
        }
    }

    public func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {
        switch code {
        case FourCharCode("pidx"):
            guard let v = value as? Int else { throw ScriptingError.typeMismatch(expected: "Int") }
            self.index = v
        case FourCharCode("pvis"):
            guard let v = value as? Bool else { throw ScriptingError.typeMismatch(expected: "Bool") }
            self.visible = v
        case FourCharCode("pmnd"):
            guard let v = value as? Bool else { throw ScriptingError.typeMismatch(expected: "Bool") }
            self.miniaturized = v
        case FourCharCode("pzum"):
            guard let v = value as? Bool else { throw ScriptingError.typeMismatch(expected: "Bool") }
            self.zoomed = v
        default:
            throw ScriptingError.propertyNotFound(code)
        }
    }

    public func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] {
        []
    }

    public func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
        throw ScriptingError.elementNotFound(code)
    }

    public func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
        throw ScriptingError.elementNotFound(code)
    }
}
