import SwiftUI

struct DocumentEditorView: View {
    @ObservedObject var document: TextDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextEditor(text: $document.bodyText)
                .font(.body)
                .onChange(of: document.bodyText) {
                    document.syncParagraphsFromBody()
                }

            Divider()

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
        .onAppear { document.applyPendingContent() }
    }

    private var wordCount: Int {
        document.paragraphs.reduce(0) { count, para in
            count + para.text.split(separator: " ").count
        }
    }
}
