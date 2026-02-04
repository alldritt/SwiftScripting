import Foundation
import SwiftScripting

typealias FCC = SwiftScripting.FourCharCode

/// Custom application root for the To-Do app.
///
/// Demonstrates a non-document-based app with a custom element type
/// (todo lists instead of documents).
@Observable
@MainActor
final class TodoApplication: ScriptableObject, @unchecked Sendable {
    static let todoListCode = TodoList.scriptingClassDescription.code

    static var scriptingClassDescription: ScriptingClassDescription {
        ScriptingClassDescription(
            name: "application",
            code: .classApplication,
            properties: [
                ScriptingPropertyDescription(name: "name", code: .propertyName, type: .text, isReadOnly: true),
                ScriptingPropertyDescription(name: "selection", code: .propertySelection, type: .objectSpecifier(TodoList.self)),
            ],
            elements: [
                ScriptingElementDescription(type: TodoList.self),
            ]
        )
    }

    nonisolated let scriptableID = "application"
    var scriptableName: String? { "ScriptableTodos" }

    var todoLists: [TodoList] = []
    var selectedList: TodoList?

    func scriptableValue(forProperty code: FCC) -> any ScriptableValue {
        switch code {
        case .propertyName: return scriptableName
        case .propertySelection: return selectedList ?? ScriptingMissingValue() as any ScriptableValue
        default: return "" as any ScriptableValue
        }
    }

    func setScriptableValue(_ value: any ScriptableValue, forProperty code: FCC) throws {
        switch code {
        case .propertySelection:
            selectedList = value as? TodoList
        default:
            throw ScriptingError.readOnlyProperty(code)
        }
    }

    func scriptableElements(forCode code: FCC) -> [any ScriptableObject] {
        switch code {
        case Self.todoListCode: return todoLists
        default: return []
        }
    }

    func insertScriptableElement(_ object: any ScriptableObject, forCode code: FCC, at index: Int) throws {
        guard code == Self.todoListCode, let list = object as? TodoList else {
            throw ScriptingError.typeMismatch(expected: TodoList.self)
        }
        todoLists.insert(list, at: index)
    }

    func removeScriptableElement(at index: Int, forCode code: FCC) throws {
        guard code == Self.todoListCode else {
            throw ScriptingError.elementNotFound(code)
        }
        todoLists.remove(at: index)
    }
}
