/// Resolves `ObjectSpecifier` chains against the live object graph.
///
/// Resolution works recursively: resolve the container first, then apply
/// the leaf specifier within that container's elements or properties.
@MainActor
public struct ObjectResolver: Sendable {
    public let registry: ScriptableObjectRegistry

    public init(registry: ScriptableObjectRegistry) {
        self.registry = registry
    }

    // MARK: - Public Resolution API

    /// Resolve a specifier to zero or more live objects.
    public func resolve(_ specifier: ObjectSpecifier) throws -> [any ScriptableObject] {
        switch specifier {
        case .application:
            guard let app = registry.application else {
                throw ScriptingError.objectNotFound("No application object registered")
            }
            return [app]

        case .index(let classCode, let index, let container):
            let containers = try resolveContainer(container)
            return try containers.flatMap { container in
                try resolveByIndex(classCode: classCode, index: index, in: container)
            }

        case .name(let classCode, let name, let container):
            let containers = try resolveContainer(container)
            return try containers.flatMap { container in
                try resolveByName(classCode: classCode, name: name, in: container)
            }

        case .id(let classCode, let id, let container):
            let containers = try resolveContainer(container)
            return try containers.flatMap { container in
                try resolveByID(classCode: classCode, id: id, in: container)
            }

        case .every(let classCode, let container):
            let containers = try resolveContainer(container)
            return containers.flatMap { container in
                resolveEvery(classCode: classCode, in: container)
            }

        case .range(let classCode, let from, let to, let container):
            let containers = try resolveContainer(container)
            return try containers.flatMap { container in
                try resolveRange(classCode: classCode, from: from, to: to, in: container)
            }

        case .property(let propertyCode, let container):
            let containers = try resolveContainer(container)
            guard let first = containers.first else {
                throw ScriptingError.objectNotFound("No container for property \(propertyCode)")
            }
            let value = first.scriptableValue(forProperty: propertyCode)
            if let obj = value as? any ScriptableObject {
                return [obj]
            }
            // For scalar properties, we return the container —
            // the caller should read the property from it.
            return containers

        case .whose(let classCode, let test, let container):
            let containers = try resolveContainer(container)
            return containers.flatMap { container in
                resolveWhose(classCode: classCode, test: test, in: container)
            }
        }
    }

    /// Resolve a specifier expected to yield exactly one object.
    public func resolveSingle(_ specifier: ObjectSpecifier) throws -> any ScriptableObject {
        let results = try resolve(specifier)
        guard let first = results.first else {
            throw ScriptingError.objectNotFound("Specifier resolved to zero objects")
        }
        return first
    }

    // MARK: - Container Resolution

    private func resolveContainer(_ container: ObjectSpecifier?) throws -> [any ScriptableObject] {
        guard let container else {
            // Default container is the application
            guard let app = registry.application else {
                throw ScriptingError.objectNotFound("No application object registered")
            }
            return [app]
        }
        return try resolve(container)
    }

    // MARK: - Index Resolution

    private func resolveByIndex(
        classCode: FourCharCode,
        index: Int,
        in container: any ScriptableObject
    ) throws -> [any ScriptableObject] {
        let elements = container.scriptableElements(forCode: classCode)
        // AppleScript uses 1-based indexing; negative means from end
        let resolvedIndex: Int
        if index > 0 {
            resolvedIndex = index - 1
        } else if index < 0 {
            resolvedIndex = elements.count + index
        } else {
            throw ScriptingError.invalidSpecifier("Index 0 is not valid (AppleScript uses 1-based indexing)")
        }

        guard resolvedIndex >= 0, resolvedIndex < elements.count else {
            throw ScriptingError.indexOutOfBounds(index: index, count: elements.count)
        }
        return [elements[resolvedIndex]]
    }

    // MARK: - Name Resolution

    private func resolveByName(
        classCode: FourCharCode,
        name: String,
        in container: any ScriptableObject
    ) throws -> [any ScriptableObject] {
        let elements = container.scriptableElements(forCode: classCode)
        let matches = elements.filter { $0.scriptableName == name }
        if matches.isEmpty {
            throw ScriptingError.objectNotFound("No \(classCode) named \"\(name)\"")
        }
        return matches
    }

    // MARK: - ID Resolution

    private func resolveByID(
        classCode: FourCharCode,
        id: String,
        in container: any ScriptableObject
    ) throws -> [any ScriptableObject] {
        let elements = container.scriptableElements(forCode: classCode)
        let matches = elements.filter { $0.scriptableID == id }
        if matches.isEmpty {
            throw ScriptingError.objectNotFound("No \(classCode) with id \"\(id)\"")
        }
        return matches
    }

    // MARK: - Every

    private func resolveEvery(
        classCode: FourCharCode,
        in container: any ScriptableObject
    ) -> [any ScriptableObject] {
        container.scriptableElements(forCode: classCode)
    }

    // MARK: - Range Resolution

    private func resolveRange(
        classCode: FourCharCode,
        from: RangeBound,
        to: RangeBound,
        in container: any ScriptableObject
    ) throws -> [any ScriptableObject] {
        let elements = container.scriptableElements(forCode: classCode)

        let fromIndex = try resolveBound(from, in: elements)
        let toIndex = try resolveBound(to, in: elements)

        let lower = min(fromIndex, toIndex)
        let upper = max(fromIndex, toIndex)

        guard lower >= 0, upper < elements.count else {
            throw ScriptingError.indexOutOfBounds(index: upper + 1, count: elements.count)
        }

        return Array(elements[lower...upper])
    }

    private func resolveBound(_ bound: RangeBound, in elements: [any ScriptableObject]) throws -> Int {
        switch bound {
        case .index(let i):
            return i - 1  // Convert from 1-based to 0-based
        case .name(let name):
            guard let idx = elements.firstIndex(where: { $0.scriptableName == name }) else {
                throw ScriptingError.objectNotFound("No element named \"\(name)\"")
            }
            return idx
        }
    }

    // MARK: - Whose Resolution

    private func resolveWhose(
        classCode: FourCharCode,
        test: WhoseClause,
        in container: any ScriptableObject
    ) -> [any ScriptableObject] {
        let elements = container.scriptableElements(forCode: classCode)
        return elements.filter { evaluateWhose(test, on: $0) }
    }

    private func evaluateWhose(_ clause: WhoseClause, on object: any ScriptableObject) -> Bool {
        switch clause {
        case .comparison(let property, let op, let value):
            let propValue = object.scriptableValue(forProperty: property)
            return compare(propValue, op: op, to: value)

        case .and(let lhs, let rhs):
            return evaluateWhose(lhs, on: object) && evaluateWhose(rhs, on: object)

        case .or(let lhs, let rhs):
            return evaluateWhose(lhs, on: object) || evaluateWhose(rhs, on: object)

        case .not(let inner):
            return !evaluateWhose(inner, on: object)
        }
    }

    private func compare(_ propValue: any ScriptableValue, op: ComparisonOp, to whoseValue: WhoseValue) -> Bool {
        switch (propValue, whoseValue) {
        case (let s as String, .string(let target)):
            return compareStrings(s, op: op, target: target)
        case (let i as Int, .integer(let target)):
            return compareComparable(i, op: op, target: target)
        case (let d as Double, .real(let target)):
            return compareComparable(d, op: op, target: target)
        case (let b as Bool, .boolean(let target)):
            switch op {
            case .equal: return b == target
            case .notEqual: return b != target
            default: return false
            }
        default:
            return false
        }
    }

    private func compareStrings(_ value: String, op: ComparisonOp, target: String) -> Bool {
        switch op {
        case .equal: return value == target
        case .notEqual: return value != target
        case .lessThan: return value < target
        case .lessOrEqual: return value <= target
        case .greaterThan: return value > target
        case .greaterOrEqual: return value >= target
        case .beginsWith: return value.hasPrefix(target)
        case .endsWith: return value.hasSuffix(target)
        case .contains: return value.contains(target)
        }
    }

    private func compareComparable<T: Comparable>(_ value: T, op: ComparisonOp, target: T) -> Bool {
        switch op {
        case .equal: return value == target
        case .notEqual: return value != target
        case .lessThan: return value < target
        case .lessOrEqual: return value <= target
        case .greaterThan: return value > target
        case .greaterOrEqual: return value >= target
        default: return false
        }
    }
}
