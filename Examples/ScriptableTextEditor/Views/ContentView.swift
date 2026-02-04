import SwiftUI
import SwiftScripting

struct ContentView: View {
    @Bindable var app: ScriptableApplication
    @State private var selectedDocument: TextDocument?

    var body: some View {
        NavigationSplitView {
            List(documents, selection: $selectedDocument) { doc in
                NavigationLink(value: doc) {
                    HStack {
                        Text(doc.name)
                        if doc.modified {
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                Button("New", systemImage: "plus") {
                    let doc = TextDocument(name: "Untitled \(documents.count + 1)")
                    app.documents.append(doc)
                    selectedDocument = doc
                }
            }
        } detail: {
            if let doc = selectedDocument {
                DocumentEditorView(document: doc)
            } else {
                ContentUnavailableView("Select a Document", systemImage: "doc.text")
            }
        }
    }

    private var documents: [TextDocument] {
        app.documents.compactMap { $0 as? TextDocument }
    }
}
