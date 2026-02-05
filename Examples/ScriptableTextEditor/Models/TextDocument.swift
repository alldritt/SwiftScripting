import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SwiftScripting

/// A text document that integrates with both SwiftUI's document infrastructure
/// and the SwiftScripting object model.
///
/// Uses `ObservableObject` + `@Published` (not `@Observable`) because
/// `ReferenceFileDocument` requires `objectWillChange` for auto-save triggers.
@MainActor
final class TextDocument: ScriptableObject, ReferenceFileDocument, ObservableObject, @unchecked Sendable {
    nonisolated static var readableContentTypes: [UTType] { [.plainText] }
    nonisolated static var writableContentTypes: [UTType] { [.plainText] }

    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "document",
            code: .classDocument,
            properties: [
                ScriptingPropertyDescription(
                    name: "id", code: .propertyID, type: .text, isReadOnly: true,
                    getter: { ($0 as! TextDocument).scriptableID },
                    setter: nil
                ),
                ScriptingPropertyDescription(
                    name: "name", code: .propertyName, type: .text,
                    getter: { ($0 as! TextDocument).name },
                    setter: { ($0 as! TextDocument).name = $1 as! String }
                ),
                ScriptingPropertyDescription(
                    name: "body text", code: FourCharCode("ctxt"), type: .text,
                    getter: { ($0 as! TextDocument).bodyText },
                    setter: { ($0 as! TextDocument).bodyText = $1 as! String }
                ),
                ScriptingPropertyDescription(
                    name: "window", code: FourCharCode("dwin"), type: .objectSpecifier("window"), isReadOnly: true,
                    getter: { ($0 as! TextDocument).window ?? ScriptingMissingValue() as any ScriptableValue },
                    setter: nil
                ),
            ],
            elements: [
                ScriptingElementDescription(
                    type: TextParagraph.self,
                    getter: { ($0 as! TextDocument).paragraphs.map { $0 as any ScriptableObject } },
                    inserter: { parent, obj, index in
                        guard let para = obj as? TextParagraph else {
                            throw ScriptingError.typeMismatch(expected: TextParagraph.self)
                        }
                        (parent as! TextDocument).paragraphs.insert(para, at: index)
                        (parent as! TextDocument).syncBodyFromParagraphs()
                    },
                    remover: { parent, index in
                        (parent as! TextDocument).paragraphs.remove(at: index)
                        (parent as! TextDocument).syncBodyFromParagraphs()
                    }
                ),
                ScriptingElementDescription(
                    type: TextWord.self,
                    getter: { doc in
                        (doc as! TextDocument).bodyText
                            .split(separator: /\s+/)
                            .map { TextWord(text: String($0)) }
                    },
                    inserter: { _, _, _ in throw ScriptingError.commandFailed("Words are computed and cannot be inserted directly") },
                    remover: { _, _ in throw ScriptingError.commandFailed("Words are computed and cannot be removed directly") }
                ),
                ScriptingElementDescription(
                    type: TextCharacter.self,
                    getter: { doc in
                        Array((doc as! TextDocument).bodyText).map { TextCharacter(text: String($0)) }
                    },
                    inserter: { _, _, _ in throw ScriptingError.commandFailed("Characters are computed and cannot be inserted directly") },
                    remover: { _, _ in throw ScriptingError.commandFailed("Characters are computed and cannot be removed directly") }
                ),
                ScriptingElementDescription(
                    type: TextInsertionPoint.self,
                    getter: { obj in
                        let doc = obj as! TextDocument
                        let text = doc.bodyText
                        return (0...text.count).map { offset in
                            TextInsertionPoint(offset: offset) { [weak doc] (inserted: String) in
                                guard let doc else { return }
                                let current = doc.bodyText
                                guard offset <= current.count else { return }
                                let idx = current.index(current.startIndex, offsetBy: offset)
                                doc.bodyText.insert(contentsOf: inserted, at: idx)
                                doc.syncParagraphsFromBody()
                            }
                        }
                    },
                    inserter: { _, _, _ in throw ScriptingError.commandFailed("Insertion points cannot be inserted") },
                    remover: { _, _ in throw ScriptingError.commandFailed("Insertion points cannot be removed") }
                ),
            ]
        )
    }

    nonisolated let scriptableID: String
    var scriptableName: String? { name }

    @Published var name: String = "Untitled"
    @Published var bodyText: String = ""
    @Published var paragraphs: [TextParagraph] = []

    /// The associated window, set by the app when the document is registered.
    weak var window: TextEditorWindow?

    /// Pending file content set from `nonisolated init(configuration:)`.
    /// Applied on first access from the main actor.
    nonisolated(unsafe) private var _pendingText: String?
    nonisolated(unsafe) private var _pendingName: String?

    /// Create a new empty document.
    nonisolated init() {
        self.scriptableID = UUID().uuidString
    }

    /// Create a document with initial content (for scripting / programmatic use).
    init(name: String, bodyText: String = "") {
        self.scriptableID = UUID().uuidString
        self.name = name
        self.bodyText = bodyText
    }

    // MARK: - ReferenceFileDocument

    nonisolated required init(configuration: ReadConfiguration) throws {
        self.scriptableID = UUID().uuidString
        if let data = configuration.file.regularFileContents,
           let text = String(data: data, encoding: .utf8) {
            self._pendingText = text
            self._pendingName = configuration.file.filename ?? "Untitled"
        }
    }

    /// Apply any pending file content. Called from the view's onAppear.
    func applyPendingContent() {
        if let text = _pendingText {
            self.bodyText = text
            self.name = _pendingName ?? "Untitled"
            self._pendingText = nil
            self._pendingName = nil
            syncParagraphsFromBody()
        }
    }

    typealias Snapshot = Data

    nonisolated func snapshot(contentType: UTType) throws -> Data {
        MainActor.assumeIsolated {
            bodyText.data(using: .utf8) ?? Data()
        }
    }

    nonisolated func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: snapshot)
    }

    // MARK: - Sync Helpers

    /// Rebuild paragraphs array from bodyText.
    func syncParagraphsFromBody() {
        let lines = bodyText.components(separatedBy: .newlines)
        paragraphs = lines.map { TextParagraph(text: $0) }
    }

    /// Rebuild bodyText from paragraphs (for scripting insert/remove).
    func syncBodyFromParagraphs() {
        bodyText = paragraphs.map(\.text).joined(separator: "\n")
    }
}

// MARK: - ScriptableDocument (lightweight conformance for window back-reference)

extension TextDocument: ScriptableDocument {
    var modified: Bool { false }
    var filePath: URL? { nil }
}
