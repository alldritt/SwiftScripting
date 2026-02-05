import Foundation
import SwiftScripting

/// An insertion point between two characters in a text container.
///
/// There are N+1 insertion points for N characters of text.
/// Setting the `contents` property inserts text at this position.
@MainActor
final class TextInsertionPoint: ScriptableObject, @unchecked Sendable {
    static let classCode = FCC("cins")

    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "insertion point",
            code: classCode,
            properties: [
                ScriptingPropertyDescription(
                    name: "contents", code: FCC("pcnt"), type: .text,
                    getter: { ($0 as! TextInsertionPoint).contents },
                    setter: {
                        guard let s = $1 as? String else {
                            throw ScriptingError.typeMismatch(expected: String.self)
                        }
                        ($0 as! TextInsertionPoint).setContents(s)
                    }
                ),
            ]
        )
    }

    nonisolated let scriptableID: String
    var scriptableName: String? { nil }

    let offset: Int
    private(set) var contents: String = ""

    /// Action invoked when `contents` is set, typically inserting text into the parent.
    private let insertAction: (@MainActor (String) -> Void)?

    func setContents(_ text: String) {
        contents = text
        insertAction?(text)
    }

    init(offset: Int, insertAction: (@MainActor (String) -> Void)? = nil) {
        self.scriptableID = "insertionPoint-\(offset)"
        self.offset = offset
        self.insertAction = insertAction
    }
}
