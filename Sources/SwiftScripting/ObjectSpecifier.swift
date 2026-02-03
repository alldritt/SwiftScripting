/// Represents a parsed Apple Event object specifier chain.
///
/// Object specifiers identify objects in the scriptable object model
/// by describing a path from a container (typically the application)
/// to the target object(s).
///
/// Examples:
/// - `document 1` → `.index(classCode: "docu", index: 1, container: .application)`
/// - `document "Untitled"` → `.name(classCode: "docu", name: "Untitled", container: .application)`
/// - `paragraph 3 of document 1` → `.index(classCode: "cpar", index: 3, container: .index(...))`
/// - `every document` → `.every(classCode: "docu", container: .application)`
public indirect enum ObjectSpecifier: Sendable, Equatable {
    /// Reference by 1-based index: `document 1`
    case index(classCode: FourCharCode, index: Int, container: ObjectSpecifier?)

    /// Reference by name: `document "Untitled"`
    case name(classCode: FourCharCode, name: String, container: ObjectSpecifier?)

    /// Reference by unique ID: `document id "abc123"`
    case id(classCode: FourCharCode, id: String, container: ObjectSpecifier?)

    /// Reference to a range: `documents 1 thru 3`
    case range(classCode: FourCharCode, from: RangeBound, to: RangeBound, container: ObjectSpecifier?)

    /// Reference to all elements: `every document`
    case every(classCode: FourCharCode, container: ObjectSpecifier?)

    /// Reference to a property: `name of document 1`
    case property(propertyCode: FourCharCode, container: ObjectSpecifier?)

    /// Reference by test/filter: `documents whose name starts with "A"`
    case whose(classCode: FourCharCode, test: WhoseClause, container: ObjectSpecifier?)

    /// The root application object.
    case application

    /// The class code of the target object (if applicable).
    public var classCode: FourCharCode? {
        switch self {
        case .index(let code, _, _): return code
        case .name(let code, _, _): return code
        case .id(let code, _, _): return code
        case .range(let code, _, _, _): return code
        case .every(let code, _): return code
        case .whose(let code, _, _): return code
        case .property: return nil
        case .application: return .classApplication
        }
    }

    /// The container specifier, if any.
    public var container: ObjectSpecifier? {
        switch self {
        case .index(_, _, let c): return c
        case .name(_, _, let c): return c
        case .id(_, _, let c): return c
        case .range(_, _, _, let c): return c
        case .every(_, let c): return c
        case .property(_, let c): return c
        case .whose(_, _, let c): return c
        case .application: return nil
        }
    }
}

/// Bound for a range specifier.
public enum RangeBound: Sendable, Equatable {
    case index(Int)
    case name(String)
}

/// A test clause for "whose" filtering.
public indirect enum WhoseClause: Sendable, Equatable {
    /// Property comparison: `whose name = "Untitled"`
    case comparison(property: FourCharCode, op: ComparisonOp, value: WhoseValue)

    /// Logical AND of two clauses
    case and(WhoseClause, WhoseClause)

    /// Logical OR of two clauses
    case or(WhoseClause, WhoseClause)

    /// Logical NOT
    case not(WhoseClause)
}

/// Comparison operators for whose clauses.
public enum ComparisonOp: Sendable, Equatable {
    case equal
    case notEqual
    case lessThan
    case lessOrEqual
    case greaterThan
    case greaterOrEqual
    case beginsWith
    case endsWith
    case contains
}

/// Values that can appear in a whose clause comparison.
public enum WhoseValue: Sendable, Equatable {
    case string(String)
    case integer(Int)
    case real(Double)
    case boolean(Bool)
}
