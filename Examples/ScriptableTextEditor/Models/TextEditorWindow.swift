import Foundation
import SwiftScripting

/// A standalone scriptable window object for the text editor.
///
/// Cannot subclass `ScriptableWindow` (it's final), so this replicates
/// the standard window properties and adds a read-only `document` property.
@MainActor
final class TextEditorWindow: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "window",
            code: .classWindow,
            properties: [
                ScriptingPropertyDescription(
                    name: "name", code: .propertyName, type: .text, isReadOnly: true,
                    getter: { ($0 as! TextEditorWindow).name },
                    setter: nil
                ),
                ScriptingPropertyDescription(
                    name: "index", code: FourCharCode("pidx"), type: .integer,
                    getter: { ($0 as! TextEditorWindow).index },
                    setter: { ($0 as! TextEditorWindow).index = $1 as! Int }
                ),
                ScriptingPropertyDescription(
                    name: "visible", code: FourCharCode("pvis"), type: .boolean,
                    getter: { ($0 as! TextEditorWindow).visible },
                    setter: { ($0 as! TextEditorWindow).visible = $1 as! Bool }
                ),
                ScriptingPropertyDescription(
                    name: "miniaturized", code: FourCharCode("pmnd"), type: .boolean,
                    getter: { ($0 as! TextEditorWindow).miniaturized },
                    setter: { ($0 as! TextEditorWindow).miniaturized = $1 as! Bool }
                ),
                ScriptingPropertyDescription(
                    name: "zoomed", code: FourCharCode("pzum"), type: .boolean,
                    getter: { ($0 as! TextEditorWindow).zoomed },
                    setter: { ($0 as! TextEditorWindow).zoomed = $1 as! Bool }
                ),
                ScriptingPropertyDescription(
                    name: "document", code: FourCharCode("wdoc"), type: .objectSpecifier("document"), isReadOnly: true,
                    getter: { ($0 as! TextEditorWindow).document ?? ScriptingMissingValue() as any ScriptableValue },
                    setter: nil
                ),
            ],
            elements: []
        )
    }

    nonisolated let scriptableID: String
    var scriptableName: String? { name }

    var name: String
    var index: Int
    var visible: Bool = true
    var miniaturized: Bool = false
    var zoomed: Bool = false

    /// The associated document, if any.
    weak var document: TextDocument?

    init(name: String, index: Int = 1) {
        self.scriptableID = UUID().uuidString
        self.name = name
        self.index = index
    }
}
