import SwiftUI

struct DocumentEditorView: View {
    @Bindable var document: TextDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextEditor(text: $document.bodyText)
                .font(.body)
                .onChange(of: document.bodyText) {
                    document.modified = true
                    document.syncParagraphsFromBody()
                }

            Divider()

            // Status bar showing paragraph/word counts
            HStack {
                Text("\(document.paragraphs.count) paragraphs")
                Text("\(wordCount) words")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .navigationTitle(document.name)
    }

    private var wordCount: Int {
        document.paragraphs.reduce(0) { count, para in
            count + para.text.split(separator: " ").count
        }
    }
}
