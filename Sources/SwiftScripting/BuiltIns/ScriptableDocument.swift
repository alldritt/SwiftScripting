import Foundation

/// Protocol for document objects in the scriptable object model.
///
/// Apps conform their document types to this protocol to participate
/// in standard scripting (e.g., `document 1`, `document "Untitled"`).
@MainActor
public protocol ScriptableDocument: ScriptableObject {
    /// The display name of the document.
    var name: String { get }

    /// Whether the document has unsaved changes.
    var modified: Bool { get }

    /// The file URL, if saved.
    var filePath: URL? { get }
}

// MARK: - Default implementations

extension ScriptableDocument {
    public var scriptableName: String? { name }
}
