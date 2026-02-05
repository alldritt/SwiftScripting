import Foundation
import SwiftScripting

/// A paragraph in a text document.
///
/// Uses closure-based dispatch in its scripting class description.
/// Word elements are computed by splitting the paragraph text on whitespace.
@MainActor
final class TextParagraph: ScriptableObject, @unchecked Sendable {
    static let classCode = FCC("cpar")

    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "paragraph",
            code: classCode,
            properties: [
                ScriptingPropertyDescription(
                    name: "text", code: FCC("ctxt"), type: .text,
                    getter: { ($0 as! TextParagraph).text },
                    setter: {
                        guard let s = $1 as? String else {
                            throw ScriptingError.typeMismatch(expected: String.self)
                        }
                        ($0 as! TextParagraph).text = s
                    }
                ),
            ],
            elements: [
                ScriptingElementDescription(
                    type: TextWord.self,
                    getter: { ($0 as! TextParagraph).text.split(separator: " ").map { TextWord(text: String($0)) } },
                    inserter: { _, _, _ in throw ScriptingError.commandFailed("Words are computed from paragraph text and cannot be inserted directly") },
                    remover: { _, _ in throw ScriptingError.commandFailed("Words are computed from paragraph text and cannot be removed directly") }
                ),
                ScriptingElementDescription(
                    type: TextCharacter.self,
                    getter: { Array(($0 as! TextParagraph).text).map { TextCharacter(text: String($0)) } },
                    inserter: { _, _, _ in throw ScriptingError.commandFailed("Characters are computed from paragraph text and cannot be inserted directly") },
                    remover: { _, _ in throw ScriptingError.commandFailed("Characters are computed from paragraph text and cannot be removed directly") }
                ),
            ]
        )
    }

    nonisolated let scriptableID: String
    var scriptableName: String? { text }
    var text: String

    init(text: String) {
        self.scriptableID = UUID().uuidString
        self.text = text
    }
}
