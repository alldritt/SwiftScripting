import Foundation
import SwiftScripting

/// Custom application root for the To-Do app.
///
/// Demonstrates a non-document-based app with a custom element type
/// (todo lists instead of documents). Uses closure-based property and
/// element descriptions so the default ScriptableObject dispatch handles
/// get/set/insert/remove automatically.
@Observable
@MainActor
final class TodoApplication: ScriptableObject, @unchecked Sendable {
    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "application",
            code: .classApplication,
            properties: [
                ScriptingPropertyDescription(
                    name: "name", code: .propertyName, type: .text, isReadOnly: true,
                    getter: { ($0 as! TodoApplication).scriptableName },
                    setter: nil
                ),
                ScriptingPropertyDescription(
                    name: "selection", code: .propertySelection, type: .objectSpecifier(TodoList.self),
                    getter: { ($0 as! TodoApplication).selectedList ?? ScriptingMissingValue() as any ScriptableValue },
                    setter: { ($0 as! TodoApplication).selectedList = $1 as? TodoList }
                ),
            ],
            elements: [
                ScriptingElementDescription(
                    type: TodoList.self,
                    getter: { ($0 as! TodoApplication).todoLists.map { $0 as any ScriptableObject } },
                    inserter: { guard let list = $1 as? TodoList else { throw ScriptingError.typeMismatch(expected: TodoList.self) }; ($0 as! TodoApplication).todoLists.insert(list, at: $2) },
                    remover: { ($0 as! TodoApplication).todoLists.remove(at: $1) }
                ),
            ]
        )
    }

    nonisolated let scriptableID = "application"
    var scriptableName: String? { "ScriptableTodos" }

    var todoLists: [TodoList] = []
    var selectedList: TodoList?
}
