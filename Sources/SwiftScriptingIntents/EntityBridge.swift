import AppIntents
import SwiftScripting

/// Bridges a `ScriptableObject` to an `AppEntity`.
public struct ScriptableEntity: AppEntity, Sendable {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Scriptable Object"
    }

    public static var defaultQuery: ScriptableEntityQuery {
        ScriptableEntityQuery()
    }

    public var id: String
    public var displayName: String

    /// The four-char class code of the underlying scriptable object.
    public var classCode: SwiftScripting.FourCharCode

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    public init(id: String, displayName: String, classCode: SwiftScripting.FourCharCode) {
        self.id = id
        self.displayName = displayName
        self.classCode = classCode
    }

    /// Create an entity from a ScriptableObject (must be called on MainActor).
    @MainActor
    public init(from object: any ScriptableObject) {
        self.id = object.scriptableID
        self.displayName = object.scriptableName ?? object.scriptableID
        self.classCode = type(of: object).scriptingClassDescription.code
    }
}

/// Protocol for types that can bridge to App Intents entities.
@MainActor
public protocol EntityBridgeable: ScriptableObject {
    static var entityDisplayName: String { get }
}

extension EntityBridgeable {
    public static var entityDisplayName: String {
        scriptingClassDescription.name
    }
}
