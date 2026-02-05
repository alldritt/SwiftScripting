import Foundation
import SwiftScripting

/// A single character of text, computed from a parent's text content.
///
/// Characters are read-only derived elements — modifying the parent's
/// text content changes the characters.
@MainActor
final class TextCharacter: ScriptableObject, @unchecked Sendable {
    static let classCode = FCC("cha ")

    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "character",
            code: classCode,
            properties: [
                ScriptingPropertyDescription(
                    name: "text", code: FCC("ctxt"), type: .text, isReadOnly: true,
                    getter: { ($0 as! TextCharacter).text },
                    setter: nil
                ),
            ]
        )
    }

    nonisolated let scriptableID: String
    var scriptableName: String? { text }
    let text: String

    init(text: String) {
        self.scriptableID = text
        self.text = text
    }
}
