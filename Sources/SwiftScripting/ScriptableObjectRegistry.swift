import Observation

/// Maintains the live object graph for scriptable object resolution.
///
/// The registry holds a reference to the root application object and
/// provides lookup of class descriptions by code. It serves as the
/// entry point for `ObjectResolver` to traverse the object model.
@MainActor
@Observable
public final class ScriptableObjectRegistry: Sendable {
    /// The root application object.
    public private(set) var application: (any ScriptableObject)?

    /// Registered class descriptions, keyed by class code.
    private var classDescriptions: [FourCharCode: ScriptingClassDescription] = [:]

    /// Registered class factory closures for `make` commands.
    private var factories: [FourCharCode: @MainActor @Sendable () -> any ScriptableObject] = [:]

    public init() {}

    /// Set the root application object.
    public func setApplication(_ app: any ScriptableObject) {
        self.application = app
    }

    /// Register a scriptable class.
    public func registerClass(_ type: any ScriptableObject.Type) {
        let desc = type.scriptingClassDescription
        classDescriptions[desc.code] = desc
    }

    /// Register a factory for creating new instances of a class.
    public func registerFactory(
        for code: FourCharCode,
        factory: @escaping @MainActor @Sendable () -> any ScriptableObject
    ) {
        factories[code] = factory
    }

    /// Register a factory, deriving the class code from the type's `scriptingClassDescription`.
    public func registerFactory<T: ScriptableObject>(
        for type: T.Type,
        factory: @escaping @MainActor @Sendable () -> T
    ) {
        factories[T.scriptingClassDescription.code] = factory
    }

    /// Look up a class description by its four-char code.
    public func classDescription(for code: FourCharCode) -> ScriptingClassDescription? {
        classDescriptions[code]
    }

    /// Create a new instance of the given class code using the registered factory.
    public func createObject(classCode: FourCharCode) throws -> any ScriptableObject {
        guard let factory = factories[classCode] else {
            throw ScriptingError.objectNotFound("No factory for class \(classDescriptions[classCode]?.name ?? classCode.stringValue)")
        }
        return factory()
    }

    /// All registered class descriptions.
    public var allClassDescriptions: [ScriptingClassDescription] {
        Array(classDescriptions.values)
    }
}
