import Foundation
import SwiftScripting

typealias FCC = SwiftScripting.FourCharCode

/// A read-only word object computed from a paragraph's text.
///
/// Words are derived by splitting paragraph text on whitespace.
/// They cannot be inserted or removed directly — modifying the
/// paragraph's text content changes the words.
@MainActor
final class TextWord: ScriptableObject, @unchecked Sendable {
    static let classCode = FCC("cwor")

    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "word",
            code: classCode,
            properties: [
                ScriptingPropertyDescription(
                    name: "text", code: FCC("ctxt"), type: .text, isReadOnly: true,
                    getter: { ($0 as! TextWord).text },
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
