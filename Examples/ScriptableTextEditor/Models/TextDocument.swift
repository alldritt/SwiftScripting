import Foundation
import SwiftScripting

/// A text document with paragraphs.
///
/// Conforms to both `ScriptableDocument` (for the built-in application model)
/// and uses `@Scriptable` macro for property/element generation.
@Scriptable("document", code: "docu")
@MainActor
final class TextDocument: ScriptableObject, ScriptableDocument, @unchecked Sendable {
    @ScriptableProperty("name", code: "pnam")
    var name: String = "Untitled"

    @ScriptableProperty("body text", code: "ctxt")
    var bodyText: String = ""

    @ScriptableElement
    var paragraphs: [TextParagraph] = []

    // ScriptableDocument requirements
    var modified: Bool = false
    var filePath: URL? = nil

    init(name: String = "Untitled", bodyText: String = "") {
        self.name = name
        self.bodyText = bodyText
    }

    /// Sync paragraphs from bodyText content.
    func syncParagraphsFromBody() {
        let lines = bodyText.components(separatedBy: .newlines)
        paragraphs = lines.map { TextParagraph(text: $0) }
    }

    /// Sync bodyText from paragraphs.
    func syncBodyFromParagraphs() {
        bodyText = paragraphs.map(\.text).joined(separator: "\n")
    }
}

extension TextDocument: Hashable {
    nonisolated static func == (lhs: TextDocument, rhs: TextDocument) -> Bool { lhs === rhs }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
