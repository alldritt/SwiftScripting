import AppIntents
import SwiftScripting

/// Bridges scripting property reads to an App Intent.
///
/// Usage:
/// ```swift
/// struct GetDocumentNameIntent: AppIntent {
///     static var title: LocalizedStringResource = "Get Document Name"
///
///     @Parameter(title: "Document") var target: ScriptableEntity
///
///     func perform() async throws -> some IntentResult & ReturnsValue<String> {
///         let value = try await GetPropertyBridge.getProperty(
///             code: SwiftScripting.FourCharCode("pnam"),
///             of: target,
///             registry: myRegistry
///         )
///         return .result(value: value as! String)
///     }
/// }
/// ```
@MainActor
public enum GetPropertyBridge {
    /// Get a property value from a scriptable entity.
    public static func getProperty(
        code: SwiftScripting.FourCharCode,
        of entity: ScriptableEntity,
        registry: ScriptableObjectRegistry
    ) throws -> any ScriptableValue {
        guard let app = registry.application else {
            throw ScriptingError.objectNotFound("No application")
        }

        let specifier = ObjectSpecifier.id(
            classCode: entity.classCode,
            id: entity.id,
            container: .application
        )

        let resolver = ObjectResolver(registry: registry)
        let objects = try resolver.resolve(specifier)
        guard let target = objects.first else {
            throw ScriptingError.objectNotFound("Entity not found: \(entity.id)")
        }

        return target.scriptableValue(forProperty: code)
    }
}

/// Bridges scripting property writes to an App Intent.
@MainActor
public enum SetPropertyBridge {
    /// Set a property value on a scriptable entity.
    public static func setProperty(
        code: SwiftScripting.FourCharCode,
        of entity: ScriptableEntity,
        to value: any ScriptableValue,
        registry: ScriptableObjectRegistry
    ) throws {
        guard let app = registry.application else {
            throw ScriptingError.objectNotFound("No application")
        }

        let specifier = ObjectSpecifier.id(
            classCode: entity.classCode,
            id: entity.id,
            container: .application
        )

        let resolver = ObjectResolver(registry: registry)
        let objects = try resolver.resolve(specifier)
        guard let target = objects.first else {
            throw ScriptingError.objectNotFound("Entity not found: \(entity.id)")
        }

        let pipeline = MutationPipeline(registry: registry)
        try pipeline.setProperty(code, of: target, to: value)
    }
}

/// Bridges scripting "make" commands to an App Intent.
@MainActor
public enum MakeElementBridge {
    /// Create a new element in the application.
    public static func makeElement(
        classCode: SwiftScripting.FourCharCode,
        withProperties properties: [(SwiftScripting.FourCharCode, any ScriptableValue)] = [],
        registry: ScriptableObjectRegistry
    ) throws -> ScriptableEntity {
        guard let app = registry.application else {
            throw ScriptingError.objectNotFound("No application")
        }

        let pipeline = MutationPipeline(registry: registry)
        let newObject = try pipeline.makeElement(
            classCode: classCode,
            in: app,
            withProperties: properties
        )

        return ScriptableEntity(from: newObject)
    }
}

/// Bridges scripting "delete" commands to an App Intent.
@MainActor
public enum DeleteElementBridge {
    /// Delete an element from the application.
    public static func deleteElement(
        _ entity: ScriptableEntity,
        registry: ScriptableObjectRegistry
    ) throws {
        guard let app = registry.application else {
            throw ScriptingError.objectNotFound("No application")
        }

        let elements = app.scriptableElements(forCode: entity.classCode)
        guard let index = elements.firstIndex(where: { $0.scriptableID == entity.id }) else {
            throw ScriptingError.objectNotFound("Entity not found: \(entity.id)")
        }

        let pipeline = MutationPipeline(registry: registry)
        try pipeline.deleteElement(at: index, classCode: entity.classCode, from: app)
    }
}
