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
                    name: "name", code: .propertyName, type: .text,
                    getter: { ($0 as! TextDocument).name },
                    setter: { ($0 as! TextDocument).name = $1 as! String }
                ),
                ScriptingPropertyDescription(
                    name: "body text", code: FourCharCode("ctxt"), type: .text,
                    getter: { ($0 as! TextDocument).bodyText },
                    setter: { ($0 as! TextDocument).bodyText = $1 as! String }
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
            ]
        )
    }

    nonisolated let scriptableID: String
    var scriptableName: String? { name }

    @Published var name: String = "Untitled"
    @Published var bodyText: String = ""
    @Published var paragraphs: [TextParagraph] = []

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
