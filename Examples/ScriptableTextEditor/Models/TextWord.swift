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
                ScriptingPropertyDescription(name: "text", code: FCC("ctxt"), type: .text, isReadOnly: true),
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

    func scriptableValue(forProperty code: FCC) -> any ScriptableValue {
        switch code {
        case FCC("ctxt"): return text
        default: return "" as any ScriptableValue
        }
    }

    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FCC) throws {
        throw ScriptingError.readOnlyProperty(code)
    }

    func scriptableElements(forCode code: FCC) -> [any ScriptableObject] { [] }

    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FCC, at index: Int) throws {
        throw ScriptingError.elementNotFound(code)
    }

    func removeScriptableElement(at index: Int, forCode code: FCC) throws {
        throw ScriptingError.elementNotFound(code)
    }
}
