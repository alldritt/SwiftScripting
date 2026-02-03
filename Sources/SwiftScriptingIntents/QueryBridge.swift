import AppIntents
import SwiftScripting

/// Bridges `ObjectResolver` to an `EntityQuery` for App Intents.
public struct ScriptableEntityQuery: EntityQuery, Sendable {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [ScriptableEntity] {
        // Default implementation returns empty. Apps should subclass or provide
        // their own query types with access to the registry.
        []
    }

    public func suggestedEntities() async throws -> [ScriptableEntity] {
        []
    }
}

/// A query bridge that wraps a specific registry for entity resolution.
@MainActor
public final class RegistryEntityQuery: Sendable {
    private let registry: ScriptableObjectRegistry
    private let resolver: ObjectResolver

    public init(registry: ScriptableObjectRegistry) {
        self.registry = registry
        self.resolver = ObjectResolver(registry: registry)
    }

    public func entities(for identifiers: [String], classCode: SwiftScripting.FourCharCode) -> [ScriptableEntity] {
        guard let app = registry.application else { return [] }
        let allElements = app.scriptableElements(forCode: classCode)
        return allElements
            .filter { identifiers.contains($0.scriptableID) }
            .map { ScriptableEntity(from: $0) }
    }

    public func entities(matching query: String, classCode: SwiftScripting.FourCharCode) -> [ScriptableEntity] {
        guard let app = registry.application else { return [] }
        let allElements = app.scriptableElements(forCode: classCode)
        let matches: [any ScriptableObject]
        if query.isEmpty {
            matches = allElements
        } else {
            matches = allElements.filter { obj in
                obj.scriptableName?.localizedCaseInsensitiveContains(query) ?? false
            }
        }
        return matches.map { ScriptableEntity(from: $0) }
    }

    public func allEntities(classCode: SwiftScripting.FourCharCode) -> [ScriptableEntity] {
        guard let app = registry.application else { return [] }
        return app.scriptableElements(forCode: classCode)
            .map { ScriptableEntity(from: $0) }
    }
}
