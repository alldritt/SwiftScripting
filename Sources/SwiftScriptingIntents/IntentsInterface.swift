import SwiftScripting

/// Top-level registration point for the App Intents interface.
///
/// The intents interface generates `AppEntity`, `EntityQuery`, and `AppIntent`
/// types that bridge the scriptable object model to Siri and Shortcuts.
@MainActor
public final class IntentsInterface: Sendable {
    private let registry: ScriptableObjectRegistry

    public init(registry: ScriptableObjectRegistry) {
        self.registry = registry
    }

    /// Register all scriptable classes as App Intents entities.
    /// Call this during app startup after the registry is configured.
    public func register() {
        // Registration happens implicitly through the AppEntity/AppIntent types
        // that are generated or bridged. This method serves as the explicit
        // activation point.
    }
}
