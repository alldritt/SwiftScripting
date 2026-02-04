import Foundation
import Observation

/// Built-in scriptable application object.
///
/// Represents the running application in the scripting object model.
/// Automatically populated with name, version, and serves as the root
/// container for documents and windows.
@Observable
@MainActor
public final class ScriptableApplication: ScriptableObject, @unchecked Sendable {
    public static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "application",
            code: .classApplication,
            properties: [
                ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text, isReadOnly: true),
                ScriptingPropertyDescription(name: "version", code: FourCharCode("vers"), type: .text, isReadOnly: true),
                ScriptingPropertyDescription(name: "frontmost", code: FourCharCode("pisf"), type: .boolean, isReadOnly: true),
            ],
            elements: [
                ScriptingElementDescription(name: "document", code: .classDocument),
                ScriptingElementDescription(name: "window", code: .classWindow),
            ]
        )
    }

    public nonisolated var scriptableID: String { "application" }
    public var scriptableName: String? { name }

    /// The application name, derived from the main bundle.
    public private(set) var name: String

    /// The application version, derived from the main bundle.
    public private(set) var version: String

    /// Whether this is the frontmost application.
    public var frontmost: Bool {
        #if canImport(AppKit)
        return NSApplication.shared.isActive
        #else
        return true
        #endif
    }

    /// The open documents.
    public var documents: [any ScriptableDocument] = []

    /// The open windows.
    public var windows: [ScriptableWindow] = []

    public init() {
        let bundle = Bundle.main
        self.name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Application"
        self.version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    // MARK: - ScriptableObject

    public func scriptableValue(forProperty code: FourCharCode) -> any ScriptableValue {
        switch code {
        case .propertyName: return name
        case FourCharCode("vers"): return version
        case FourCharCode("pisf"): return frontmost
        default: return "" as any ScriptableValue
        }
    }

    public func setScriptableValue(_ value: any ScriptableValue, forProperty code: FourCharCode) throws {
        throw ScriptingError.readOnlyProperty(code)
    }

    public func scriptableElements(forCode code: FourCharCode) -> [any ScriptableObject] {
        switch code {
        case .classDocument:
            return documents.map { $0 as any ScriptableObject }
        case .classWindow:
            return windows.map { $0 as any ScriptableObject }
        default:
            return []
        }
    }

    public func insertScriptableElement(_ object: any ScriptableObject, forCode code: FourCharCode, at index: Int) throws {
        switch code {
        case .classDocument:
            guard let doc = object as? any ScriptableDocument else {
                throw ScriptingError.typeMismatch(expected: (any ScriptableDocument).self)
            }
            documents.insert(doc, at: index)
        case .classWindow:
            guard let window = object as? ScriptableWindow else {
                throw ScriptingError.typeMismatch(expected: ScriptableWindow.self)
            }
            windows.insert(window, at: index)
        default:
            throw ScriptingError.elementNotFound(code)
        }
    }

    public func removeScriptableElement(at index: Int, forCode code: FourCharCode) throws {
        switch code {
        case .classDocument:
            documents.remove(at: index)
        case .classWindow:
            windows.remove(at: index)
        default:
            throw ScriptingError.elementNotFound(code)
        }
    }
}

#if canImport(AppKit)
import AppKit
#endif
