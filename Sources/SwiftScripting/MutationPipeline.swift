#if canImport(AppKit)
import AppKit
#endif

/// Centralizes all mutation operations on scriptable objects.
///
/// All write paths (Apple Events, App Intents, direct Swift code) converge
/// through the mutation pipeline, which optionally registers undo actions
/// so that scripted changes are undoable.
@MainActor
public final class MutationPipeline: Sendable {
    private let registry: ScriptableObjectRegistry
    #if canImport(AppKit)
    private weak var undoManager: UndoManager?
    #endif

    public init(registry: ScriptableObjectRegistry) {
        self.registry = registry
    }

    #if canImport(AppKit)
    /// Set the undo manager for registering undo actions on mutations.
    public func setUndoManager(_ undoManager: UndoManager?) {
        self.undoManager = undoManager
    }
    #endif

    // MARK: - Set Property

    /// Set a property on a target object, optionally registering undo.
    public func setProperty(
        _ code: FourCharCode,
        of target: any ScriptableObject,
        to value: any ScriptableValue
    ) throws {
        #if canImport(AppKit)
        if let undoManager {
            let oldValue = target.scriptableValue(forProperty: code)
            undoManager.registerUndo(withTarget: UndoTarget.shared) { [weak target] _ in
                guard let target else { return }
                try? target.setScriptableValue(oldValue, forProperty: code)
            }
        }
        #endif

        try target.setScriptableValue(value, forProperty: code)
    }

    // MARK: - Make (Create Element)

    /// Create a new element in the given container.
    public func makeElement(
        classCode: FourCharCode,
        in container: any ScriptableObject,
        withProperties properties: [(FourCharCode, any ScriptableValue)] = [],
        at index: Int? = nil
    ) throws -> any ScriptableObject {
        let newObject = try registry.createObject(classCode: classCode)

        // Apply initial properties
        for (propCode, value) in properties {
            try newObject.setScriptableValue(value, forProperty: propCode)
        }

        // Insert into container
        let insertIndex = index ?? container.scriptableElements(forCode: classCode).count
        try container.insertScriptableElement(newObject, forCode: classCode, at: insertIndex)

        #if canImport(AppKit)
        if let undoManager {
            let elementIndex = insertIndex
            undoManager.registerUndo(withTarget: UndoTarget.shared) { [weak container] _ in
                guard let container else { return }
                try? container.removeScriptableElement(at: elementIndex, forCode: classCode)
            }
        }
        #endif

        return newObject
    }

    // MARK: - Delete Element

    /// Delete an element from its container.
    public func deleteElement(
        at index: Int,
        classCode: FourCharCode,
        from container: any ScriptableObject
    ) throws {
        guard index >= 0, index < container.scriptableElements(forCode: classCode).count else {
            throw ScriptingError.indexOutOfBounds(
                index: index,
                count: container.scriptableElements(forCode: classCode).count
            )
        }

        #if canImport(AppKit)
        if let undoManager {
            let removed = container.scriptableElements(forCode: classCode)[index]
            undoManager.registerUndo(withTarget: UndoTarget.shared) { [weak container] _ in
                guard let container else { return }
                try? container.insertScriptableElement(removed, forCode: classCode, at: index)
            }
        }
        #endif

        try container.removeScriptableElement(at: index, forCode: classCode)
    }

    // MARK: - Move Element

    /// Move an element from one container to another.
    public func moveElement(
        _ object: any ScriptableObject,
        classCode: FourCharCode,
        from sourceContainer: any ScriptableObject,
        sourceIndex: Int,
        to destContainer: any ScriptableObject,
        destIndex: Int
    ) throws {
        try sourceContainer.removeScriptableElement(at: sourceIndex, forCode: classCode)
        try destContainer.insertScriptableElement(object, forCode: classCode, at: destIndex)
    }

    // MARK: - Duplicate Element

    /// Duplicate an element. Requires the class to have a registered factory.
    /// The caller is responsible for copying property values.
    public func duplicateElement(
        _ original: any ScriptableObject,
        classCode: FourCharCode,
        in container: any ScriptableObject,
        at index: Int? = nil
    ) throws -> any ScriptableObject {
        let copy = try registry.createObject(classCode: classCode)

        // Copy all property values from original
        guard let classDesc = registry.classDescription(for: classCode) else {
            throw ScriptingError.objectNotFound("Unknown class \(classCode)")
        }

        for prop in classDesc.properties where !prop.isReadOnly {
            let value = original.scriptableValue(forProperty: prop.code)
            try? copy.setScriptableValue(value, forProperty: prop.code)
        }

        let insertIndex = index ?? container.scriptableElements(forCode: classCode).count
        try container.insertScriptableElement(copy, forCode: classCode, at: insertIndex)

        return copy
    }
}

// MARK: - Undo Target

/// A shared target for NSUndoManager registrations (needed because
/// registerUndo requires an NSObject target).
#if canImport(AppKit)
private final class UndoTarget: NSObject, @unchecked Sendable {
    static let shared = UndoTarget()
}
#endif
