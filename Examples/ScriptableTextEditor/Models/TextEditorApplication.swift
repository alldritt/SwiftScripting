import Foundation
import Observation
import SwiftScripting

/// Custom application root for the text editor.
///
/// Tracks open documents via `registerDocument`/`unregisterDocument`
/// called from the DocumentGroup's `onAppear`/`onDisappear`.
@Observable
@MainActor
final class TextEditorApplication: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "application",
            code: .classApplication,
            properties: [
                ScriptingPropertyDescription(
                    name: "name", code: .propertyName, type: .text, isReadOnly: true,
                    getter: { ($0 as! TextEditorApplication).scriptableName },
                    setter: nil
                ),
            ],
            elements: [
                ScriptingElementDescription(
                    type: TextDocument.self,
                    getter: { ($0 as! TextEditorApplication).documents.map { $0 as any ScriptableObject } },
                    inserter: { parent, obj, index in
                        guard let doc = obj as? TextDocument else {
                            throw ScriptingError.typeMismatch(expected: TextDocument.self)
                        }
                        (parent as! TextEditorApplication).documents.insert(doc, at: index)
                    },
                    remover: { parent, index in
                        (parent as! TextEditorApplication).documents.remove(at: index)
                    }
                ),
                ScriptingElementDescription(
                    type: TextEditorWindow.self,
                    getter: { ($0 as! TextEditorApplication).windows.map { $0 as any ScriptableObject } },
                    inserter: { _, _, _ in throw ScriptingError.commandFailed("Windows are managed by the system") },
                    remover: { _, _ in throw ScriptingError.commandFailed("Windows are managed by the system") }
                ),
            ]
        )
    }

    nonisolated let scriptableID = "application"
    var scriptableName: String? { "ScriptableTextEditor" }
    var documents: [TextDocument] = []
    var windows: [TextEditorWindow] = []
}
