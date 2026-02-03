#if canImport(Carbon)
import Foundation
import Carbon
import SwiftScripting

/// Parses `NSAppleEventDescriptor` object specifier records into `ObjectSpecifier` enums.
@MainActor
public enum ObjectSpecifierParsing {

    public static func parse(_ descriptor: NSAppleEventDescriptor) throws -> ObjectSpecifier {
        if descriptor.descriptorType == typeNull {
            return .application
        }

        guard descriptor.descriptorType == typeObjectSpecifier else {
            if descriptor.descriptorType == typeType || descriptor.descriptorType == typeProperty {
                let code = ScriptFourCharCode(rawValue: descriptor.typeCodeValue)
                return .property(propertyCode: code, container: .application)
            }
            throw ScriptingError.invalidSpecifier(
                "Expected typeObjectSpecifier, got \(fourCharString(descriptor.descriptorType))"
            )
        }

        guard let desiredClassDesc = descriptor.forKeyword(AEKeyword(keyAEDesiredClass)),
              let keyFormDesc = descriptor.forKeyword(AEKeyword(keyAEKeyForm)),
              let keyDataDesc = descriptor.forKeyword(AEKeyword(keyAEKeyData)),
              let containerDesc = descriptor.forKeyword(AEKeyword(keyAEContainer)) else {
            throw ScriptingError.invalidSpecifier("Malformed object specifier record")
        }

        let desiredClass = ScriptFourCharCode(rawValue: desiredClassDesc.typeCodeValue)
        let keyForm = keyFormDesc.enumCodeValue

        let container = try parse(containerDesc)

        switch Int(keyForm) {
        case formAbsolutePosition:
            return try parseAbsolutePosition(classCode: desiredClass, keyData: keyDataDesc, container: container)
        case formName:
            return try parseName(classCode: desiredClass, keyData: keyDataDesc, container: container)
        case formUniqueID:
            return try parseUniqueID(classCode: desiredClass, keyData: keyDataDesc, container: container)
        case formRange:
            return try parseRange(classCode: desiredClass, keyData: keyDataDesc, container: container)
        case formPropertyID:
            let propertyCode = ScriptFourCharCode(rawValue: keyDataDesc.typeCodeValue)
            return .property(propertyCode: propertyCode, container: container)
        case formTest:
            return try parseWhose(classCode: desiredClass, keyData: keyDataDesc, container: container)
        default:
            throw ScriptingError.invalidSpecifier(
                "Unknown key form: \(fourCharString(keyForm))"
            )
        }
    }

    // MARK: - Form Parsers

    private static func parseAbsolutePosition(
        classCode: ScriptFourCharCode,
        keyData: NSAppleEventDescriptor,
        container: ObjectSpecifier
    ) throws -> ObjectSpecifier {
        if keyData.descriptorType == typeAbsoluteOrdinal {
            let ordinal = keyData.typeCodeValue
            switch ordinal {
            case OSType(kAEAll):
                return .every(classCode: classCode, container: container)
            case OSType(kAEFirst):
                return .index(classCode: classCode, index: 1, container: container)
            case OSType(kAELast):
                return .index(classCode: classCode, index: -1, container: container)
            case OSType(kAEMiddle):
                return .index(classCode: classCode, index: 0, container: container)
            default:
                break
            }
        }

        let index = Int(keyData.int32Value)
        return .index(classCode: classCode, index: index, container: container)
    }

    private static func parseName(
        classCode: ScriptFourCharCode,
        keyData: NSAppleEventDescriptor,
        container: ObjectSpecifier
    ) throws -> ObjectSpecifier {
        guard let name = keyData.stringValue else {
            throw ScriptingError.invalidSpecifier("Name specifier has no string value")
        }
        return .name(classCode: classCode, name: name, container: container)
    }

    private static func parseUniqueID(
        classCode: ScriptFourCharCode,
        keyData: NSAppleEventDescriptor,
        container: ObjectSpecifier
    ) throws -> ObjectSpecifier {
        let id: String
        if let str = keyData.stringValue {
            id = str
        } else {
            id = String(keyData.int32Value)
        }
        return .id(classCode: classCode, id: id, container: container)
    }

    private static func parseRange(
        classCode: ScriptFourCharCode,
        keyData: NSAppleEventDescriptor,
        container: ObjectSpecifier
    ) throws -> ObjectSpecifier {
        guard let startDesc = keyData.forKeyword(AEKeyword(keyAERangeStart)),
              let stopDesc = keyData.forKeyword(AEKeyword(keyAERangeStop)) else {
            throw ScriptingError.invalidSpecifier("Malformed range descriptor")
        }

        let from = try parseBound(startDesc)
        let to = try parseBound(stopDesc)

        return .range(classCode: classCode, from: from, to: to, container: container)
    }

    private static func parseBound(_ descriptor: NSAppleEventDescriptor) throws -> RangeBound {
        if let str = descriptor.stringValue, descriptor.descriptorType == typeUnicodeText {
            return .name(str)
        }
        return .index(Int(descriptor.int32Value))
    }

    private static func parseWhose(
        classCode: ScriptFourCharCode,
        keyData: NSAppleEventDescriptor,
        container: ObjectSpecifier
    ) throws -> ObjectSpecifier {
        let clause = try parseWhoseClause(keyData)
        return .whose(classCode: classCode, test: clause, container: container)
    }

    private static func parseWhoseClause(_ descriptor: NSAppleEventDescriptor) throws -> WhoseClause {
        let descType = descriptor.descriptorType

        if descType == typeLogicalDescriptor {
            return try parseLogicalClause(descriptor)
        }

        if descType == typeCompDescriptor {
            return try parseComparisonClause(descriptor)
        }

        throw ScriptingError.invalidSpecifier("Unknown whose clause type: \(fourCharString(descType))")
    }

    private static func parseLogicalClause(_ descriptor: NSAppleEventDescriptor) throws -> WhoseClause {
        guard let logicalOp = descriptor.forKeyword(AEKeyword(keyAELogicalOperator)),
              let terms = descriptor.forKeyword(AEKeyword(keyAELogicalTerms)) else {
            throw ScriptingError.invalidSpecifier("Malformed logical descriptor")
        }

        let op = logicalOp.enumCodeValue

        if op == OSType(kAENOT) {
            let inner = try parseWhoseClause(terms.atIndex(1)!)
            return .not(inner)
        }

        guard terms.numberOfItems >= 2,
              let first = terms.atIndex(1),
              let second = terms.atIndex(2) else {
            throw ScriptingError.invalidSpecifier("Logical clause requires at least 2 terms")
        }

        let lhs = try parseWhoseClause(first)
        let rhs = try parseWhoseClause(second)

        switch op {
        case OSType(kAEAND):
            return .and(lhs, rhs)
        case OSType(kAEOR):
            return .or(lhs, rhs)
        default:
            throw ScriptingError.invalidSpecifier("Unknown logical operator")
        }
    }

    private static func parseComparisonClause(_ descriptor: NSAppleEventDescriptor) throws -> WhoseClause {
        guard let obj1Desc = descriptor.forKeyword(AEKeyword(keyAEObject1)),
              let compOpDesc = descriptor.forKeyword(AEKeyword(keyAECompOperator)),
              let obj2Desc = descriptor.forKeyword(AEKeyword(keyAEObject2)) else {
            throw ScriptingError.invalidSpecifier("Malformed comparison descriptor")
        }

        let propSpecifier = try parse(obj1Desc)
        guard case .property(let propertyCode, _) = propSpecifier else {
            throw ScriptingError.invalidSpecifier("Comparison LHS must be a property")
        }

        let op = parseComparisonOp(compOpDesc.enumCodeValue)
        let value = parseWhoseValue(obj2Desc)

        return .comparison(property: propertyCode, op: op, value: value)
    }

    private static func parseComparisonOp(_ code: OSType) -> ComparisonOp {
        switch code {
        case OSType(kAEEquals): return .equal
        case OSType(kAEGreaterThan): return .greaterThan
        case OSType(kAEGreaterThanEquals): return .greaterOrEqual
        case OSType(kAELessThan): return .lessThan
        case OSType(kAELessThanEquals): return .lessOrEqual
        case OSType(kAEBeginsWith): return .beginsWith
        case OSType(kAEEndsWith): return .endsWith
        case OSType(kAEContains): return .contains
        default: return .equal
        }
    }

    private static func parseWhoseValue(_ descriptor: NSAppleEventDescriptor) -> WhoseValue {
        switch descriptor.descriptorType {
        case typeUnicodeText, typeUTF8Text:
            return .string(descriptor.stringValue ?? "")
        case typeSInt32, typeSInt16:
            return .integer(Int(descriptor.int32Value))
        case typeBoolean, typeTrue, typeFalse:
            return .boolean(descriptor.booleanValue)
        case typeIEEE64BitFloatingPoint:
            if let d = DescriptorPacking.unpack(descriptor, as: .real) as? Double {
                return .real(d)
            }
            return .real(0)
        default:
            return .string(descriptor.stringValue ?? "")
        }
    }

    // MARK: - Utility

    private static func fourCharString(_ code: DescType) -> String {
        ScriptFourCharCode(rawValue: code).stringValue
    }
}
#endif
