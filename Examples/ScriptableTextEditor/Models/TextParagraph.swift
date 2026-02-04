import Foundation
import SwiftScripting

/// A paragraph in a text document.
///
/// Uses manual `ScriptableObject` conformance (instead of `@Scriptable` macro)
/// because it has computed word elements derived from its text content.
@MainActor
final class TextParagraph: ScriptableObject, @unchecked Sendable {
    static let classCode = FCC("cpar")

    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "paragraph",
            code: classCode,
            properties: [
                ScriptingPropertyDescription(name: "text", code: FCC("ctxt"), type: .text),
            ],
            elements: [
                ScriptingElementDescription(name: "word", code: TextWord.classCode, objectType: "TextWord"),
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

    // MARK: - Property Access

    func scriptableValue(forProperty code: FCC) -> any ScriptableValue {
        switch code {
        case FCC("ctxt"): return text
        default: return "" as any ScriptableValue
        }
    }

    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FCC) throws {
        switch code {
        case FCC("ctxt"):
            guard let s = value as? String else { throw ScriptingError.typeMismatch(expected: "String") }
            text = s
        default:
            throw ScriptingError.propertyNotFound(code)
        }
    }

    // MARK: - Element Access (computed words)

    func scriptableElements(forCode code: FCC) -> [any ScriptableObject] {
        switch code {
        case TextWord.classCode:
            return text.split(separator: " ").map { TextWord(text: String($0)) }
        default:
            return []
        }
    }

    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FCC, at index: Int) throws {
        throw ScriptingError.commandFailed("Words are computed from paragraph text and cannot be inserted directly")
    }

    func removeScriptableElement(at index: Int, forCode code: FCC) throws {
        throw ScriptingError.commandFailed("Words are computed from paragraph text and cannot be removed directly")
    }
}
